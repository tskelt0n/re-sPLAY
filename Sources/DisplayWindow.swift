import SwiftUI
import AppKit

struct DisplayItem: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let active: Bool
    let available: Bool
    let preferred: Bool
    let builtin: Bool
}

final class DisplayWindowModel: ObservableObject {
    @Published var displays: [DisplayItem] = []
    @Published var autoBrightness: [String: AutoBrightnessState] = [:]
    var setAutoBrightness: (String, Bool) -> Void = { _, _ in }
    var retryAutoBrightness: (String) -> Void = { _ in }
    @Published var brightness: [String: BrightnessState] = [:]
    var setBrightness: (String, Double) -> Void = { _, _ in }
    var retryBrightness: (String) -> Void = { _ in }
    @Published var preferredID = ""
    @Published var busy = false
    @Published var message = ""
    @Published var loginEnabled = false
    @Published var loginStatus = "Off"
    @Published var shortcutErrors: [String] = []
    var restore: () -> Void = {}
    var useOnly: (String) -> Void = { _ in }
    var toggle: (String) -> Void = { _ in }
    var prefer: (String) -> Void = { _ in }
    var toggleLogin: () -> Void = {}
    var activeCount: Int { displays.filter(\.active).count }
    var activeDescription: String {
        if busy { return "Updating your workspace…" }
        if activeCount == displays.count && activeCount > 1 { return "All displays active" }
        if activeCount == 1 { return "\(displays.first(where: \.active)?.name ?? "One display") only" }
        return "\(activeCount) displays active"
    }
}

struct DisplayWindow: View {
    @ObservedObject var model: DisplayWindowModel
    @State private var showHelp = false
    private let columns = [GridItem(.adaptive(minimum: 280), spacing: 16)]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Your displays").font(.system(size: 17, weight: .semibold))
                            Spacer()
                            Text("\(model.activeCount) of \(model.displays.count) active")
                                .font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                        if model.displays.isEmpty {
                            ContentUnavailableView("No displays found", systemImage: "display", description: Text("Connect a display to get started."))
                        } else {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(model.displays) { display in
                                    DisplayCard(display: display, busy: model.busy, onlyActive: model.activeCount == 1 && display.active,
                                                useOnly: { model.useOnly(display.id) },
                                                toggle: { model.toggle(display.id) },
                                                prefer: { model.prefer(display.id) },
                                                brightness: model.brightness[display.id] ?? BrightnessState(),
                                                setBrightness: { model.setBrightness(display.id, $0) },
                                                retryBrightness: { model.retryBrightness(display.id) },
                                                autoBrightness: model.autoBrightness[display.id] ?? AutoBrightnessState(),
                                                setAutoBrightness: { model.setAutoBrightness(display.id, $0) },
                                                retryAutoBrightness: { model.retryAutoBrightness(display.id) })
                                }
                            }
                        }
                    }
                    preferences
                    if !model.shortcutErrors.isEmpty {
                        Label(model.shortcutErrors.joined(separator: "\n"), systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange).font(.system(size: 14)).textSelection(.enabled)
                    }
                }
                .padding(.horizontal, 32).padding(.top, 24).padding(.bottom, 16)
                .frame(maxWidth: 1120)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            Divider()
            HStack(spacing: 8) {
                Image(systemName: model.busy ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                    .foregroundStyle(model.busy ? Color.blue : Color.secondary)
                Text(footerText).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(2)
                Spacer(minLength: 8)
                Button { showHelp.toggle() } label: { Image(systemName: "questionmark.circle").font(.system(size: 14)) }
                    .buttonStyle(.plain).help("About display switching")
                    .accessibilityLabel("About display switching")
                    .popover(isPresented: $showHelp) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Display switching", systemImage: "display.2").font(.headline)
                            Text("Use only this display keeps one screen active and disconnects the others from your desktop. It also sets your shortcut target.")
                            Text("Restore all reconnects the displays turned off by re-sPLAY. Quitting the app restores them too.")
                            Text("Disconnection requests standby. It does not cut AC power to the monitors.").foregroundStyle(.secondary)
                        }.font(.system(size: 14)).padding(22).frame(width: 330)
                    }
            }.padding(.horizontal, 32).padding(.vertical, 13)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(.blue)
    }

    private var footerText: String {
        if model.busy { return model.message }
        if model.message.hasPrefix("Could") || model.message.contains("still active") || model.message.contains("failed") { return model.message }
        return "re-sPLAY is ready in your menu bar."
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text("re-sPLAY").font(.system(size: 30, weight: .semibold)).tracking(-0.7)
                HStack(spacing: 7) {
                    Circle().fill(model.busy ? Color.orange : Color.blue).frame(width: 6, height: 6)
                    Text(model.activeDescription).font(.system(size: 14)).foregroundStyle(.secondary)
                }.accessibilityElement(children: .combine)
            }
            Spacer()
            Button(action: model.restore) {
                Label("Restore all", systemImage: "display.2").padding(.horizontal, 4)
            }
            .buttonStyle(.glass).tint(.blue).controlSize(.large)
            .help("Reconnect displays disabled by re-sPLAY (⌃⌥⌘0)")
        }
    }

    private var preferences: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shortcuts & startup").font(.system(size: 17, weight: .semibold))
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    settingIcon("keyboard")
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Toggle a single display").font(.system(size: 14, weight: .medium))
                        Text("Press again to restore your workspace.").font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    Picker("Shortcut display", selection: Binding(get: { model.preferredID }, set: model.prefer)) {
                        ForEach(model.displays) { Text($0.name).tag($0.id) }
                    }.labelsHidden().frame(width: 196).disabled(model.busy)
                        .accessibilityLabel("Display used by toggle shortcut")
                    KeyCaps(key: "1")
                }.padding(18)
                Divider().padding(.leading, 50)
                HStack(spacing: 14) {
                    settingIcon("display.2")
                    Text("Restore all displays").font(.system(size: 14, weight: .medium))
                    Spacer()
                    KeyCaps(key: "0")
                }.padding(.horizontal, 16).padding(.vertical, 13)
                Divider().padding(.leading, 50)
                HStack(spacing: 14) {
                    settingIcon("power")
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Launch at login").font(.system(size: 14, weight: .medium))
                        Text(model.loginStatus == "On" || model.loginStatus == "Off" ? "Ready in the menu bar when you sign in." : model.loginStatus)
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("Launch at login", isOn: Binding(get: { model.loginEnabled }, set: { _ in model.toggleLogin() }))
                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                }.padding(18)
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.07), lineWidth: 1))
        }
    }
    private func settingIcon(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 15)).foregroundStyle(.secondary).frame(width: 20)
            .accessibilityHidden(true)
    }
}

private struct KeyCaps: View {
    let key: String
    var body: some View {
        HStack(spacing: 3) {
            ForEach(["⌃", "⌥", "⌘", key], id: \.self) { value in
                Text(value).font(.system(size: 13, weight: .medium, design: .monospaced))
                    .frame(width: 25, height: 27)
                    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
            }
        }.foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Control Option Command \(key)")
    }
}

private struct DisplayCard: View {
    let display: DisplayItem
    let busy: Bool
    let onlyActive: Bool
    let useOnly: () -> Void
    let toggle: () -> Void
    let prefer: () -> Void
    let brightness: BrightnessState
    let setBrightness: (Double) -> Void
    let retryBrightness: () -> Void
    let autoBrightness: AutoBrightnessState
    let setAutoBrightness: (Bool) -> Void
    let retryAutoBrightness: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var showInfo = false

    private var connection: String { display.active ? "Active" : display.available ? "Disconnected" : "Unavailable" }
    private var hasAutoBrightness: Bool { display.name.hasPrefix("Studio Display") || display.builtin || autoBrightness.enabled != nil }

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                Image(systemName: display.active ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 15))
                    .foregroundStyle(display.active ? Color.blue : Color.secondary)
                    .help(connection).accessibilityLabel("\(display.name): \(connection)")
                Spacer()
                Button { showInfo.toggle() } label: {
                    Image(systemName: "info.circle").font(.system(size: 15))
                        .frame(width: 28, height: 28).contentShape(Rectangle())
                }.buttonStyle(.plain).foregroundStyle(.secondary)
                    .help("Display details").accessibilityLabel("About \(display.name)")
                    .popover(isPresented: $showInfo) { displayInfo }
                Button(action: prefer) {
                    Image(systemName: display.preferred ? "star.fill" : "star")
                        .font(.system(size: 15)).frame(width: 28, height: 28).contentShape(Rectangle())
                        .foregroundStyle(display.preferred ? Color.blue : Color.secondary)
                }.buttonStyle(.plain).disabled(busy)
                    .help(display.preferred ? "Used by ⌃⌥⌘1" : "Use with the toggle shortcut")
                    .accessibilityLabel("Use \(display.name) with the toggle shortcut")
                    .accessibilityValue(display.preferred ? "Selected" : "Not selected")
            }

            VStack(spacing: 12) {
                Image(systemName: display.builtin ? "laptopcomputer" : "display")
                    .font(.system(size: 64, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(display.active ? (display.preferred ? Color.blue : Color.secondary) : Color.secondary.opacity(0.45))
                    .scaleEffect(x: display.name.contains("ASUS") ? 1.13 : 1, y: 1)
                    .frame(height: 72).accessibilityHidden(true)
                Text(display.name).font(.system(size: 17, weight: .semibold))
                    .multilineTextAlignment(.center).lineLimit(2)
                    .frame(maxWidth: .infinity)
            }.padding(.bottom, 4)

            VStack(spacing: 16) {
                brightnessControl
                if hasAutoBrightness {
                    autoBrightnessControl
                } else {
                    // Keep shared controls aligned without repeating an implied manual mode.
                    Color.clear.frame(height: 28).accessibilityHidden(true)
                }
            }

            HStack(spacing: 8) {
                Button(action: useOnly) {
                    Text(onlyActive ? "Only display in use" : "Use only this")
                        .font(.system(size: 13, weight: .medium)).frame(maxWidth: .infinity)
                }.buttonStyle(WorkspaceButtonStyle())
                    .disabled(busy || !display.available || onlyActive)
                    .help("Use only \(display.name) and make it the shortcut target")
                    .accessibilityLabel("Use only \(display.name)")
                Button(action: toggle) {
                    Image(systemName: "power").font(.system(size: 15))
                }.buttonStyle(WorkspaceButtonStyle())
                    .disabled(busy || !display.available || onlyActive)
                    .help(display.active ? "Disconnect \(display.name)" : "Reconnect \(display.name)")
                    .accessibilityLabel("\(display.active ? "Disconnect" : "Reconnect") \(display.name)")
            }
        }
        .padding(20)
        .background(scheme == .dark ? Color(nsColor: NSColor(white: 0.15, alpha: 1)) : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(display.preferred ? Color.blue.opacity(scheme == .dark ? 0.5 : 0.35) : Color.primary.opacity(0.08), lineWidth: 1))
    }

    private var displayInfo: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(display.name).font(.system(size: 17, weight: .semibold))
            Label(connection, systemImage: display.active ? "checkmark.circle" : "circle.dashed")
            if display.preferred { Label("Selected for ⌃⌥⌘1", systemImage: "star.fill") }
            Divider()
            Text(display.active ? brightness.error ?? brightness.detail : "Reconnect this display to adjust brightness.").fixedSize(horizontal: false, vertical: true)
            if hasAutoBrightness {
                Text(autoBrightness.error ?? "Auto brightness lets macOS adjust this display to ambient light. Turn it off to keep your chosen level.").fixedSize(horizontal: false, vertical: true)
            } else {
                Text("This display uses manual brightness. macOS auto brightness isn’t available.").fixedSize(horizontal: false, vertical: true)
            }
            Text("Use only this keeps this display active and disconnects the others. The power button connects or disconnects just this display.")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.font(.system(size: 14)).frame(width: 296, alignment: .leading).fixedSize(horizontal: false, vertical: true).padding(22)
    }

    private var autoBrightnessControl: some View {
        HStack(spacing: 8) {
            Text("Auto brightness").font(.system(size: 14))
            Spacer(minLength: 8)
            if autoBrightness.updating {
                ProgressView().controlSize(.small).accessibilityLabel("Updating auto brightness")
            }
            if autoBrightness.error != nil && display.active {
                Button(action: retryAutoBrightness) { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain).frame(width: 28, height: 28)
                    .help(autoBrightness.error ?? "Retry")
                    .accessibilityLabel("Retry auto brightness for \(display.name)").disabled(busy)
            } else {
                Toggle("Auto brightness", isOn: Binding(get: { autoBrightness.enabled ?? false }, set: setAutoBrightness))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
                    .disabled(busy || !display.active || autoBrightness.enabled == nil || autoBrightness.updating || brightness.updating)
                    .accessibilityLabel("\(display.name) auto brightness")
                    .accessibilityValue(!display.active || autoBrightness.enabled == nil ? "Unavailable" : autoBrightness.enabled == true ? "On" : "Off")
                    .help("Adjust brightness with ambient light. Turn off to keep your chosen manual level.")
            }
        }.frame(height: 28)
    }

    private var brightnessControl: some View {
        HStack(spacing: 10) {
            Image(systemName: "sun.max").font(.system(size: 16)).foregroundStyle(.secondary)
                .help("Brightness").accessibilityHidden(true)
            // A stepped SwiftUI slider draws a dense row of tick marks on macOS.
            // Keep the native track continuous and round only the requested brightness.
            Slider(value: Binding(get: { brightness.percent ?? 0 }, set: { setBrightness($0.rounded()) }), in: 0...100)
                .controlSize(.regular)
                .disabled(busy || !display.active || brightness.percent == nil || autoBrightness.updating)
                .accessibilityAdjustableAction { direction in
                    guard !busy, display.active, !autoBrightness.updating, let value = brightness.percent else { return }
                    switch direction {
                    case .increment: setBrightness(min(100, value.rounded() + 1))
                    case .decrement: setBrightness(max(0, value.rounded() - 1))
                    @unknown default: break
                    }
                }
                .help(brightness.detail + ". Adjust this monitor independently.")
                .accessibilityLabel("\(display.name) brightness")
                .accessibilityValue(!display.active ? "Unavailable" : brightness.percent.map { "\(Int($0.rounded())) percent" } ?? "Unavailable")
            Group {
                if !display.active {
                    Image(systemName: "moon.zzz").foregroundStyle(.secondary)
                        .help("Reconnect to adjust brightness").accessibilityLabel("Reconnect to adjust brightness")
                } else if brightness.error != nil {
                    Button(action: retryBrightness) { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.plain).foregroundStyle(.orange)
                        .help(brightness.error ?? "Retry brightness")
                        .disabled(busy).accessibilityLabel("Retry brightness for \(display.name)")
                } else if let percent = brightness.percent {
                    Text("\(Int(percent.rounded()))%")
                        .font(.system(size: 17, weight: .medium)).monospacedDigit()
                } else {
                    ProgressView().controlSize(.small).accessibilityLabel("Reading brightness")
                }
            }.frame(width: 48, height: 28, alignment: .trailing)
        }.frame(height: 28)
    }
}

// Semantic colors keep secondary actions legible in both appearances.
private struct WorkspaceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        WorkspaceButtonSurface(configuration: configuration)
    }
}
private struct WorkspaceButtonSurface: View {
    let configuration: ButtonStyle.Configuration
    @Environment(\.isEnabled) private var enabled
    @State private var hovered = false
    var body: some View {
        configuration.label
            .foregroundStyle(enabled ? Color.primary : Color.secondary)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(Color.primary.opacity(enabled && configuration.isPressed ? 0.16 : enabled && hovered ? 0.11 : 0.065), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(enabled ? 0.15 : 0.07), lineWidth: 1))
            .contentShape(Capsule())
            .onHover { hovered = $0 }
    }
}
