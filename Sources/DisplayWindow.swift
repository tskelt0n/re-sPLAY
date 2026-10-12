import SwiftUI
import AppKit

let brandAccent = Color(nsColor: BrandArtwork.accent)

enum AppSection: String, CaseIterable, Identifiable {
    case displays = "Displays", settings = "Settings"
    var id: String { rawValue }
    var icon: String { self == .displays ? "display.2" : "gearshape" }
}

struct DisplayItem: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let active: Bool
    let available: Bool
    let preferred: Bool
    let builtin: Bool
    var shortName: String {
        if name.contains("ASUS") { return "ASUS" }
        if name.hasPrefix("Studio Display") { return name.replacingOccurrences(of: "Studio Display", with: "Studio") }
        if builtin { return "MacBook" }
        return name
    }
}

final class DisplayWindowModel: ObservableObject {
    @Published var section: AppSection = .displays
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
        if busy { return "Updating your displays…" }
        if activeCount == displays.count && activeCount > 1 { return "All displays active" }
        if activeCount == 1 { return "\(displays.first(where: \.active)?.name ?? "One display") only" }
        return "\(activeCount) displays active"
    }
    var feedback: String? {
        if busy { return message }
        if message.hasPrefix("Could") || message.contains("still active") || message.contains("failed") || message.hasPrefix("Keep at least") { return message }
        return nil
    }
    func isOnlyActive(_ display: DisplayItem) -> Bool { activeCount == 1 && display.active }
    func supportsAuto(_ display: DisplayItem) -> Bool {
        display.name.hasPrefix("Studio Display") || display.builtin || autoBrightness[display.id]?.enabled != nil
    }
}

struct DisplayWindow: View {
    @ObservedObject var model: DisplayWindowModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showHelp = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    private var sidebarAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.32, extraBounce: 0)
    }
    private var pageAnimation: Animation {
        .easeInOut(duration: reduceMotion ? 0.12 : 0.24)
    }
    private var pageTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 8)),
            removal: .opacity)
    }
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(nsImage: BrandArtwork.symbol(size: 40))
                        .resizable().frame(width: 36, height: 36)
                        .accessibilityHidden(true)
                    Text("re-sPLAY").font(.system(size: 21, weight: .semibold)).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 22).padding(.top, 24).padding(.bottom, 24)

                VStack(spacing: 4) {
                    ForEach(AppSection.allCases) { section in
                        Button { model.section = section } label: {
                            HStack(spacing: 14) {
                                Image(systemName: section.icon)
                                    .font(.system(size: 21, weight: .regular))
                                    .frame(width: 28).accessibilityHidden(true)
                                Text(section.rawValue).font(.system(size: 17, weight: .medium))
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(.primary)
                            .frame(minHeight: 60)
                            .padding(.leading, 14).padding(.trailing, 20)
                            .contentShape(Rectangle())
                            .background {
                                if model.section == section {
                                    UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 10)
                                        .fill(Color(nsColor: .windowBackgroundColor))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(section.rawValue)
                        .accessibilityAddTraits(model.section == section ? .isSelected : [])
                    }
                }
                .padding(.leading, 8)
                .onMoveCommand { direction in
                    if direction == .up { model.section = .displays }
                    else if direction == .down { model.section = .settings }
                }
                Spacer(minLength: 24)

                HStack(spacing: 10) {
                    Circle().fill(model.busy ? Color.orange : Color.green)
                        .frame(width: 7, height: 7).accessibilityHidden(true)
                    Text(model.activeDescription)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary).lineLimit(2)
                    Spacer(minLength: 0)
                }.padding(.horizontal, 24).padding(.vertical, 24)
            }.frame(minWidth: 220, idealWidth: 240, maxWidth: 280)
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if model.section == .displays {
                        displayPage.transition(pageTransition)
                    } else {
                        settingsPage.transition(pageTransition)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                // Animate navigation only, not brightness/status polling updates.
                .animation(pageAnimation, value: model.section)
                Divider()
                HStack(spacing: 10) {
                    if model.busy { ProgressView().controlSize(.small) }
                    else { Image(systemName: "menubar.rectangle").foregroundStyle(.secondary) }
                    Text(model.feedback ?? "Quick controls are always in your menu bar.")
                        .font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(2)
                    Spacer()
                    Button { showHelp.toggle() } label: { Image(systemName: "questionmark.circle") }
                        .buttonStyle(.plain).help("About display switching")
                        .accessibilityLabel("About display switching")
                        .popover(isPresented: $showHelp) { SwitchingHelp() }
                }.padding(.horizontal, 28).padding(.vertical, 15)
            }.background(Color(nsColor: .windowBackgroundColor))
        }
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(sidebarAnimation) {
                        columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help(columnVisibility == .detailOnly ? "Show sidebar" : "Hide sidebar")
                .accessibilityLabel(columnVisibility == .detailOnly ? "Show sidebar" : "Hide sidebar")
            }
        }
        .tint(brandAccent)
    }

    private var displayPage: some View {
        GeometryReader { geometry in
            let contentWidth = max(1, min(geometry.size.width, 1300) - 64)
            let columnSpacing = min(40, max(24, contentWidth * 0.03))
            // Cap capacity at the actual display count so extra width never creates an empty column.
            let capacity = max(1, Int((contentWidth + columnSpacing) / (220 + columnSpacing)))
            let columnCount = max(1, min(model.displays.count, capacity))
            let columnWidth = (contentWidth - columnSpacing * CGFloat(columnCount - 1)) / CGFloat(columnCount)
            let previewWidth = max(1, min(columnWidth, 420) - 8)
            let previewHeight = model.displays.map {
                previewWidth * ($0.builtin ? 0.61 : 0.56) + ($0.builtin ? 8 : 31)
            }.max() ?? 184
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Displays").font(.system(size: 32, weight: .bold))
                            Text("Choose the screens you want to use.").font(.system(size: 16)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(model.activeCount) of \(model.displays.count) active")
                            .font(.system(size: 13)).foregroundStyle(.secondary).padding(.top, 10)
                    }
                    DisplaySetupPicker(model: model)
                    if model.displays.isEmpty {
                        ContentUnavailableView("No displays found", systemImage: "display", description: Text("Connect a display to get started."))
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: columnSpacing), count: columnCount), alignment: .center, spacing: 32) {
                            ForEach(model.displays) { display in
                                DisplayPanel(model: model, display: display, previewHeight: previewHeight)
                            }
                        }.padding(.vertical, 12)
                    }
                    Divider()
                    HStack(spacing: 12) {
                        Image(systemName: "display.2").font(.system(size: 18)).foregroundStyle(.secondary)
                        Text(model.activeDescription).font(.system(size: 14)).foregroundStyle(.secondary)
                        Spacer()
                        Button("Restore all", action: model.restore)
                            .buttonStyle(.borderedProminent).controlSize(.large)
                            .help("Reconnect displays disabled by re-sPLAY (⌃⌥⌘0)")
                    }
                }.padding(32).frame(maxWidth: 1300).frame(maxWidth: .infinity)
            }
        }
    }

    private var settingsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text("Settings").font(.system(size: 32, weight: .bold))
                Text("Make re-sPLAY part of your everyday setup.").font(.system(size: 16)).foregroundStyle(.secondary)
                SettingsControls(model: model)
                if !model.shortcutErrors.isEmpty {
                    Label(model.shortcutErrors.joined(separator: "\n"), systemImage: "exclamationmark.triangle")
                        .font(.system(size: 13)).foregroundStyle(.orange).textSelection(.enabled)
                }
                GroupBox {
                    HStack(spacing: 16) {
                        Image(nsImage: BrandArtwork.symbol(size: 52)).resizable().frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("re-sPLAY").font(.system(size: 17, weight: .semibold))
                            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.8.0")")
                                .font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }.padding(12)
                }
            }.padding(32).frame(maxWidth: 820).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct DisplaySetupPicker: View {
    @ObservedObject var model: DisplayWindowModel
    private var selected: String {
        if model.activeCount == 1 { return model.displays.first(where: \.active)?.id ?? "" }
        return model.activeCount == model.displays.count ? "all" : "custom"
    }
    private var options: [SetupSegment] {
        var items = [SetupSegment(id: "all", label: "All displays")]
        items += model.displays.filter(\.available).map { SetupSegment(id: $0.id, label: $0.shortName) }
        if selected == "custom" { items.append(SetupSegment(id: "custom", label: "Custom")) }
        return items
    }
    var body: some View {
        FixedSetupSegments(options: options, selected: selected,
                           enabled: !model.busy && !model.displays.isEmpty) { value in
            if value == "all" { model.restore() }
            else if model.displays.contains(where: { $0.id == value && $0.available }) { model.useOnly(value) }
        }
        .frame(width: CGFloat(options.count) * 96 + 4, height: 28)
    }
}

private struct SetupSegment: Equatable {
    let id: String
    let label: String
}

// Own the native segment widths rather than relying on SwiftUI Picker's alternating
// intrinsic/fill layout. Brightness polling can update selection without rebuilding segments.
private struct FixedSetupSegments: NSViewRepresentable {
    let options: [SetupSegment]
    let selected: String
    let enabled: Bool
    let choose: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl()
        control.controlSize = .large
        control.segmentStyle = .automatic
        control.borderShape = .capsule
        control.segmentDistribution = .fit
        control.trackingMode = .selectOne
        control.font = .systemFont(ofSize: 13)
        control.selectedSegmentBezelColor = BrandArtwork.accent
        control.setAccessibilityLabel("Display setup")
        control.toolTip = "Use all displays or switch to a single display"
        control.target = context.coordinator
        control.action = #selector(Coordinator.selectSegment(_:))
        return control
    }
    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        let coordinator = context.coordinator
        coordinator.choose = choose
        if coordinator.options != options {
            coordinator.options = options
            control.segmentCount = options.count
            for (index, option) in options.enumerated() {
                control.setLabel(option.label, forSegment: index)
                control.setWidth(96, forSegment: index)
            }
        }
        let index = options.firstIndex(where: { $0.id == selected }) ?? -1
        if control.selectedSegment != index { control.selectedSegment = index }
        if control.isEnabled != enabled { control.isEnabled = enabled }
    }
    final class Coordinator: NSObject {
        var options: [SetupSegment] = []
        var choose: (String) -> Void = { _ in }
        @objc func selectSegment(_ sender: NSSegmentedControl) {
            guard sender.isEnabled, options.indices.contains(sender.selectedSegment) else { return }
            choose(options[sender.selectedSegment].id)
        }
    }
}

struct DisplayPanel: View {
    @ObservedObject var model: DisplayWindowModel
    let display: DisplayItem
    let previewHeight: CGFloat
    @State private var showInfo = false
    var body: some View {
        VStack(spacing: 14) {
            DisplayIllustration(display: display).frame(height: previewHeight)
            VStack(spacing: 14) {
                HStack(spacing: 5) {
                    Spacer(minLength: 0)
                    Text(display.name).font(.system(size: 16, weight: .semibold)).lineLimit(2).multilineTextAlignment(.center)
                    Button { showInfo.toggle() } label: { Image(systemName: "info.circle").foregroundStyle(.secondary) }
                        .buttonStyle(.plain).help("Display details").accessibilityLabel("About \(display.name)")
                        .popover(isPresented: $showInfo) { DisplayDetails(model: model, display: display) }
                    Spacer(minLength: 0)
                }.frame(minHeight: 28)
                ConnectionToggle(model: model, display: display)
                BrightnessControl(model: model, display: display)
                if model.supportsAuto(display) { AutoBrightnessControl(model: model, display: display) }
                else { Color.clear.frame(height: 24).accessibilityHidden(true) }
                HStack(spacing: 10) {
                    Button("Use only this") { model.useOnly(display.id) }
                        .buttonStyle(.bordered).frame(maxWidth: .infinity)
                        .disabled(model.busy || !display.available || model.isOnlyActive(display))
                        .accessibilityLabel("Use only \(display.name)")
                    PreferenceButton(model: model, display: display)
                }
            }.frame(maxWidth: 260).padding(.horizontal, 18)
        }.frame(maxWidth: 420).padding(.vertical, 6)
    }
}

// Device illustrations are SwiftUI views, with original bundled wallpaper artwork.
// They never capture the user's screen or imply live window previews.
struct DisplayIllustration: View {
    let display: DisplayItem
    private static let wallpaper = Bundle.main.url(forResource: "DisplayWallpaper", withExtension: "png").flatMap { NSImage(contentsOf: $0) }
    var body: some View {
        GeometryReader { geometry in
            let aspect = display.builtin ? 0.61 : 0.56
            let baseHeight = display.builtin ? 8.0 : 31.0
            let width = min(geometry.size.width - 8, (geometry.size.height - baseHeight) / aspect)
            let screenHeight = width * (display.builtin ? 0.61 : 0.56)
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.075))
                    if let wallpaper = Self.wallpaper {
                        Image(nsImage: wallpaper).resizable().scaledToFill()
                            .frame(width: width - 14, height: screenHeight - 14).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .padding(7).opacity(display.active ? 1 : 0.20)
                    }
                    if display.builtin {
                        UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4)
                            .fill(Color(white: 0.075)).frame(width: 28, height: 10).padding(.top, 6)
                    }
                    if !display.active {
                        Image(systemName: "moon.zzz.fill").font(.system(size: 23)).foregroundStyle(.white.opacity(0.8))
                            .frame(width: width, height: screenHeight)
                    }
                }.frame(width: width, height: screenHeight)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(display.active ? brandAccent.opacity(0.8) : Color.gray.opacity(0.4), lineWidth: display.active ? 2 : 1))
                if display.builtin {
                    RoundedRectangle(cornerRadius: 3).fill(LinearGradient(colors: [.gray, Color(white: 0.8), .gray], startPoint: .top, endPoint: .bottom))
                        .frame(width: width + 8, height: 8)
                } else {
                    Rectangle().fill(LinearGradient(colors: [Color(white: 0.35), Color(white: 0.7), Color(white: 0.5)], startPoint: .top, endPoint: .bottom))
                        .frame(width: width * 0.13, height: 26)
                    RoundedRectangle(cornerRadius: 2).fill(LinearGradient(colors: [Color(white: 0.8), Color(white: 0.4)], startPoint: .top, endPoint: .bottom))
                        .frame(width: width * 0.32, height: 5)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
        }.accessibilityHidden(true)
    }
}

struct ConnectionToggle: View {
    @ObservedObject var model: DisplayWindowModel
    let display: DisplayItem
    var body: some View {
        HStack {
            Circle().fill(display.active ? Color.green : Color.secondary.opacity(0.5)).frame(width: 6, height: 6)
            Text(display.active ? "Active" : display.available ? "Disconnected" : "Unavailable").font(.system(size: 13)).foregroundStyle(.secondary)
            Spacer()
            Toggle("Active", isOn: Binding(get: { display.active }, set: { _ in model.toggle(display.id) }))
                .labelsHidden().toggleStyle(.switch).controlSize(.small)
                .disabled(model.busy || !display.available || model.isOnlyActive(display))
                .accessibilityLabel("\(display.name) active")
                .help(model.isOnlyActive(display) ? "Keep at least one display active" : "Connect or disconnect \(display.name)")
        }.frame(height: 24)
    }
}

struct PreferenceButton: View {
    @ObservedObject var model: DisplayWindowModel
    let display: DisplayItem
    var body: some View {
        Button { model.prefer(display.id) } label: {
            Image(systemName: display.preferred ? "star.fill" : "star")
                .foregroundStyle(display.preferred ? brandAccent : Color.secondary).frame(width: 25, height: 25)
        }.buttonStyle(.plain).disabled(model.busy)
            .accessibilityLabel("Use \(display.name) with the toggle shortcut")
            .accessibilityValue(display.preferred ? "Selected" : "Not selected")
            .help(display.preferred ? "Selected for ⌃⌥⌘1" : "Use with the toggle shortcut")
    }
}

struct BrightnessControl: View {
    @ObservedObject var model: DisplayWindowModel
    let display: DisplayItem
    var compact = false
    private var state: BrightnessState { model.brightness[display.id] ?? BrightnessState() }
    private var disabled: Bool { model.busy || !display.active || state.percent == nil || model.autoBrightness[display.id]?.updating == true }
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.max").font(.system(size: compact ? 14 : 16)).foregroundStyle(.secondary).accessibilityHidden(true)
            Slider(value: Binding(get: { state.percent ?? 0 }, set: { model.setBrightness(display.id, $0.rounded()) }), in: 0...100)
                .disabled(disabled).controlSize(compact ? .small : .regular)
                .accessibilityLabel("\(display.name) brightness")
                .accessibilityValue(display.active ? state.percent.map { "\(Int($0.rounded())) percent" } ?? "Unavailable" : "Unavailable")
                .accessibilityAdjustableAction { direction in
                    guard !disabled, let value = state.percent else { return }
                    switch direction {
                    case .increment: model.setBrightness(display.id, min(100, value.rounded() + 1))
                    case .decrement: model.setBrightness(display.id, max(0, value.rounded() - 1))
                    @unknown default: break
                    }
                }.help(state.detail)
            Group {
                if !display.active {
                    Image(systemName: "moon.zzz").foregroundStyle(.secondary).help("Reconnect to adjust brightness")
                        .accessibilityLabel("Reconnect to adjust brightness")
                } else if let error = state.error {
                    Button { model.retryBrightness(display.id) } label: { Image(systemName: "arrow.clockwise").foregroundStyle(.orange) }
                        .buttonStyle(.plain).disabled(model.busy).help(error).accessibilityLabel("Retry brightness for \(display.name)")
                } else if let value = state.percent {
                    Text("\(Int(value.rounded()))%").font(.system(size: compact ? 13 : 14)).monospacedDigit()
                } else { ProgressView().controlSize(.small).accessibilityLabel("Reading brightness") }
            }.frame(width: compact ? 35 : 40, alignment: .trailing)
        }.frame(height: 26)
    }
}

struct AutoBrightnessControl: View {
    @ObservedObject var model: DisplayWindowModel
    let display: DisplayItem
    private var state: AutoBrightnessState { model.autoBrightness[display.id] ?? AutoBrightnessState() }
    var body: some View {
        HStack {
            Text("Auto brightness").font(.system(size: 13)).foregroundStyle(.secondary)
            Spacer()
            if state.updating { ProgressView().controlSize(.small) }
            if let error = state.error, display.active {
                Button { model.retryAutoBrightness(display.id) } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain).help(error).disabled(model.busy)
                    .accessibilityLabel("Retry auto brightness for \(display.name)")
            } else {
                Toggle("Auto brightness", isOn: Binding(get: { state.enabled ?? false }, set: { model.setAutoBrightness(display.id, $0) }))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
                    .disabled(model.busy || !display.active || state.enabled == nil || state.updating || model.brightness[display.id]?.updating == true)
                    .accessibilityLabel("\(display.name) auto brightness")
                    .accessibilityValue(!display.active || state.enabled == nil ? "Unavailable" : state.enabled == true ? "On" : "Off")
                    .help("Turn off to keep a manually chosen brightness level")
            }
        }.frame(height: 24)
    }
}

struct DisplayDetails: View {
    @ObservedObject var model: DisplayWindowModel
    let display: DisplayItem
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(display.name).font(.system(size: 16, weight: .semibold))
            Text(display.active ? model.brightness[display.id]?.error ?? model.brightness[display.id]?.detail ?? "Reading brightness…" : "Reconnect this display to adjust brightness.")
            if display.preferred { Label("Selected for ⌃⌥⌘1", systemImage: "star.fill") }
            Divider()
            Text("Use only this connects this display and disconnects the others. Active controls each display individually.").foregroundStyle(.secondary)
            if model.supportsAuto(display) {
                Text("Auto brightness lets macOS respond to ambient light. Turn it off to keep your chosen manual level.").foregroundStyle(.secondary)
            }
        }.font(.system(size: 13)).frame(width: 275, alignment: .leading).fixedSize(horizontal: false, vertical: true).padding(20)
    }
}

struct SettingsControls: View {
    @ObservedObject var model: DisplayWindowModel
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox("Keyboard shortcuts") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Single display").font(.system(size: 14, weight: .medium))
                        Spacer()
                        KeyCaps(key: "1")
                    }
                    Picker("Shortcut display", selection: Binding(get: { model.preferredID }, set: model.prefer)) {
                        ForEach(model.displays) { Text($0.name).tag($0.id) }
                    }.disabled(model.busy).font(.system(size: 13))
                    Text("Press again to restore your displays.").font(.system(size: 13)).foregroundStyle(.secondary)
                    Divider()
                    HStack {
                        Text("Restore all displays").font(.system(size: 14, weight: .medium))
                        Spacer()
                        KeyCaps(key: "0")
                    }
                }.padding(compact ? 10 : 16)
            }
            GroupBox("Startup") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Launch at login", isOn: Binding(get: { model.loginEnabled }, set: { _ in model.toggleLogin() }))
                        .toggleStyle(.switch).controlSize(.small).font(.system(size: 14))
                    Text(model.loginStatus == "On" || model.loginStatus == "Off" ? "Start quietly in the menu bar when you sign in." : model.loginStatus)
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }.padding(compact ? 10 : 16).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct KeyCaps: View {
    let key: String
    var body: some View {
        Text("⌃ ⌥ ⌘ \(key)").font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary).padding(.horizontal, 8).padding(.vertical, 4)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
            .accessibilityLabel("Control Option Command \(key)")
    }
}

struct SwitchingHelp: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Display switching", systemImage: "display.2").font(.system(size: 16, weight: .semibold))
            Text("Choose one display to focus on, or keep multiple displays active. At least one screen always stays connected.")
            Text("Restore all reconnects displays disabled by re-sPLAY. Quitting normally restores them too.")
            Text("Disconnection requests standby; it does not cut AC power. Monitor previews use illustrative wallpaper, not live screen captures.").foregroundStyle(.secondary)
        }.font(.system(size: 13)).frame(width: 300, alignment: .leading).fixedSize(horizontal: false, vertical: true).padding(22)
    }
}
