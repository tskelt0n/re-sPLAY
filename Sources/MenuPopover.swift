import SwiftUI

struct MenuPopover: View {
    @ObservedObject var model: DisplayWindowModel
    let openWindow: () -> Void
    let quit: () -> Void
    @State private var section: AppSection = .displays
    @State private var expandedIDs: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 9) {
                Image(nsImage: BrandArtwork.symbol()).resizable().frame(width: 26, height: 26)
                Text("re-sPLAY").font(.system(size: 17, weight: .semibold))
                Spacer()
                Button { section = .settings } label: { Image(systemName: "gearshape").font(.system(size: 17)) }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .help("Show Settings").accessibilityLabel("Show Quick Controls Settings")
            }
            Picker("Section", selection: $section) {
                ForEach(AppSection.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).labelsHidden().accessibilityLabel("Quick controls tab")
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if section == .displays {
                        Text("Display setup").font(.system(size: 15, weight: .semibold))
                        DisplaySetupPicker(model: model)
                        if model.displays.isEmpty {
                            Text("Connect a display to get started.").foregroundStyle(.secondary).padding(.vertical, 16)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(model.displays) { display in
                                    PopoverDisplayRow(model: model, display: display, expanded: Binding(
                                        get: { expandedIDs.contains(display.id) },
                                        set: { if $0 { expandedIDs.insert(display.id) } else { expandedIDs.remove(display.id) } }))
                                    if display.id != model.displays.last?.id { Divider().padding(.horizontal, 14) }
                                }
                            }.background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
                        }
                        HStack(spacing: 10) {
                            Text(model.activeDescription).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(2)
                            Spacer()
                            Button("Restore all", action: model.restore).buttonStyle(.borderedProminent)
                                .help("Reconnect displays disabled by re-sPLAY (⌃⌥⌘0)")
                        }
                    } else {
                        SettingsControls(model: model, compact: true)
                        if !model.shortcutErrors.isEmpty {
                            Label(model.shortcutErrors.joined(separator: "\n"), systemImage: "exclamationmark.triangle")
                                .font(.system(size: 13)).foregroundStyle(.orange)
                        }
                    }
                    if let feedback = model.feedback {
                        HStack(spacing: 8) {
                            if model.busy { ProgressView().controlSize(.small) }
                            Text(feedback).font(.system(size: 13)).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(.vertical, 2)
            }.frame(maxHeight: 440)
            Divider()
            HStack {
                Button(action: openWindow) { Label("Open re-sPLAY", systemImage: "macwindow") }
                    .buttonStyle(.plain).font(.system(size: 13))
                Spacer()
                Button(action: quit) { Image(systemName: "power") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .accessibilityLabel("Restore displays and quit re-sPLAY")
                    .help("Restore displays and quit")
            }
        }.padding(20).frame(width: 530, height: section == .displays ? min(620, 490 + CGFloat(max(0, model.displays.count - 3)) * 66 + CGFloat(expandedIDs.count) * 132) : 510)
            .background(.regularMaterial).tint(brandAccent)
    }
}

private struct PopoverDisplayRow: View {
    @ObservedObject var model: DisplayWindowModel
    let display: DisplayItem
    @Binding var expanded: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 10) {
                Image(systemName: display.builtin ? "laptopcomputer" : "display")
                    .font(.system(size: 23, weight: .regular)).foregroundStyle(display.active ? Color.primary : Color.secondary)
                    .frame(width: 30).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(display.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    HStack(spacing: 5) {
                        Circle().fill(display.active ? Color.green : Color.secondary.opacity(0.5)).frame(width: 6, height: 6)
                        Text(display.active ? "Connected" : "Disconnected").font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                BrightnessControl(model: model, display: display, compact: true).frame(width: 174)
                Button { expanded.toggle() } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.system(size: 12, weight: .semibold))
                        .frame(width: 24, height: 28).contentShape(Rectangle())
                }.buttonStyle(.plain).foregroundStyle(.secondary)
                    .accessibilityLabel("\(expanded ? "Hide" : "Show") controls for \(display.name)")
            }
            if expanded {
                Divider()
                ConnectionToggle(model: model, display: display)
                if model.supportsAuto(display) { AutoBrightnessControl(model: model, display: display) }
                HStack {
                    Button("Use only this") { model.useOnly(display.id) }
                        .buttonStyle(.bordered).disabled(model.busy || !display.available || model.isOnlyActive(display))
                        .accessibilityLabel("Use only \(display.name)")
                    Spacer()
                    PreferenceButton(model: model, display: display)
                }
                if let error = model.brightness[display.id]?.error, display.active {
                    Text(error).font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }.padding(14)
    }
}
