import AppKit
import SwiftUI
import CoreGraphics
import Darwin
import Carbon
import ServiceManagement

struct Display: Codable {
    var uuid: String
    var id: UInt32
    var name: String
    var x: Int32
    var y: Int32
    var builtin: Bool
}
enum SwitchError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let s) = self { return s }; return nil }
}
final class DisplayEngine {
    typealias Enable = @convention(c) (CGDisplayConfigRef, UInt32, Bool) -> Int32
    let enable: Enable?
    let defaults = UserDefaults.standard
    var known: [Display] = []
    var disabled: Set<String> = []

    init() {
        let h = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_NOW)
        enable = h.flatMap { dlsym($0, "CGSConfigureDisplayEnabled") }.map { unsafeBitCast($0, to: Enable.self) }
        if let data = defaults.data(forKey: "displays"), let saved = try? JSONDecoder().decode([Display].self, from: data) { known = saved }
        disabled = Set(defaults.stringArray(forKey: "disabled") ?? [])
        var bytes = [CChar](repeating: 0, count: 128); var size = bytes.count
        sysctlbyname("kern.bootsessionuuid", &bytes, &size, nil, 0)
        let boot = String(cString: bytes)
        if let previous = defaults.string(forKey: "boot"), previous != boot { disabled = [] }
        defaults.set(boot, forKey: "boot")
        refresh()
    }
    func uuid(_ id: UInt32) -> String? {
        guard let u = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, u) as String
    }
    func onlineIDs() -> [UInt32] {
        var ids = [UInt32](repeating: 0, count: 64); var count: UInt32 = 0
        guard CGGetOnlineDisplayList(64, &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }
    func isActive(_ d: Display) -> Bool { valid(d) && CGDisplayIsActive(d.id) != 0 }
    func valid(_ d: Display) -> Bool {
        if let current = uuid(d.id) { return current == d.uuid }
        return disabled.contains(d.uuid)
    }
    func refresh() {
        let screens = NSScreen.screens
        for id in onlineIDs() {
            guard let key = uuid(id) else { continue }
            let screen = screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id }
            let previous = known.first { $0.uuid == key }
            let bounds = CGDisplayBounds(id)
            let d = Display(uuid: key, id: id, name: screen.flatMap { $0.localizedName.isEmpty ? nil : $0.localizedName } ?? previous?.name ?? "Display \(id)", x: Int32(bounds.origin.x), y: Int32(bounds.origin.y), builtin: CGDisplayIsBuiltin(id) != 0)
            if let i = known.firstIndex(where: { $0.uuid == key }) {
                // Preserve the last layout while a display is disabled.
                if CGDisplayIsActive(id) != 0 { known[i] = d } else { known[i].id = id }
            } else { known.append(d) }
        }
        known.sort { $0.x == $1.x ? $0.uuid < $1.uuid : $0.x < $1.x }
        persist()
    }
    func persist() {
        defaults.set(try? JSONEncoder().encode(known), forKey: "displays")
        defaults.set(Array(disabled), forKey: "disabled")
        defaults.synchronize()
    }
    func set(_ targets: [Display], enabled: Bool) throws {
        guard let enable else { throw SwitchError.message("This version of macOS does not expose the display control API.") }
        let validTargets = targets.filter { valid($0) }
        guard validTargets.count == targets.count else { throw SwitchError.message("A display connection changed. Refresh and try again.") }
        if !enabled {
            let remaining = known.filter { candidate in isActive(candidate) && !targets.contains(where: { $0.uuid == candidate.uuid }) }
            guard !remaining.isEmpty else { throw SwitchError.message("Keep at least one active display connected.") }
        }
        guard !targets.isEmpty else { return }
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else { throw SwitchError.message("Could not begin display configuration.") }
        for d in targets {
            let result = enable(config, d.id, enabled)
            guard result == 0 else { CGCancelDisplayConfiguration(config); throw SwitchError.message("macOS rejected \(d.name) (error \(result)).") }

        }

        let before = disabled
        if !enabled { for d in targets { disabled.insert(d.uuid) }; persist() }
        let result = CGCompleteDisplayConfiguration(config, .forSession)
        guard result == .success else { disabled = before; persist(); throw SwitchError.message("macOS could not apply this configuration (\(result.rawValue)).") }
        for d in targets {
            if enabled { disabled.remove(d.uuid) } else { disabled.insert(d.uuid) }
        }
        persist()
    }
    func focus(_ keeper: Display) throws {
        refresh()
        guard valid(keeper), isActive(keeper) else { throw SwitchError.message("Connect the preferred display before using focus mode.") }
        try set(known.filter { isActive($0) && $0.uuid != keeper.uuid }, enabled: false)
    }
    func restore() throws {
        refresh()
        let targets = known.filter { disabled.contains($0.uuid) && valid($0) }
        try set(targets, enabled: true)
    }
    func report() -> String {
        refresh()
        return "Display API: \(enable == nil ? "unavailable" : "available")\n" + known.map {
            "\($0.name) | \($0.uuid) | id=\($0.id) | active=\(isActive($0)) | managedOff=\(disabled.contains($0.uuid)) | origin=\($0.x),\($0.y)"
        }.joined(separator: "\n")
    }
}

// A command-line diagnostic path shares the exact same display engine as the app.
let arguments = CommandLine.arguments
if arguments.contains("--auto-brightness-status") {
    let hardware = BrightnessHardware(), engine = DisplayEngine()
    for display in engine.known where engine.isActive(display) {
        do { let value = try hardware.readAutoBrightness(display); print("\(display.uuid) | \(display.name) | auto=\(value.map { $0 ? "on" : "off" } ?? "unsupported")") }
        catch { print("\(display.uuid) | \(error.localizedDescription)") }
    }
    exit(0)
}
if let index = arguments.firstIndex(of: "--auto-brightness-set") {
    guard arguments.count > index + 2, ["on", "off"].contains(arguments[index + 2]),
          let display = DisplayEngine().known.first(where: { $0.uuid == arguments[index + 1] }) else {
        fputs("Usage: --auto-brightness-set UUID on|off\n", stderr); exit(1)
    }
    do { let actual = try BrightnessHardware().writeAutoBrightness(display, enabled: arguments[index + 2] == "on"); print(actual ? "on" : "off"); exit(0) }
    catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
}
if arguments.contains("--brightness-status") {
    let hardware = BrightnessHardware()
    let engine = DisplayEngine()
    for display in engine.known where engine.isActive(display) {
        do { let value = try hardware.read(display); print("\(display.uuid) | \(display.name) | \(value.percent)% | \(value.method)") }
        catch { print("\(display.uuid) | \(error.localizedDescription)") }
    }
    exit(0)
}
if let index = arguments.firstIndex(of: "--brightness-set") {
    guard arguments.count > index + 2, let percent = Double(arguments[index + 2]), let display = DisplayEngine().known.first(where: { $0.uuid == arguments[index + 1] }) else { fputs("Usage: --brightness-set UUID PERCENT\n", stderr); exit(1) }
    do { let value = try BrightnessHardware().write(display, percent: percent); print("\(value.percent)% | \(value.method)"); exit(0) }
    catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
}
if arguments.contains("--diagnose") {
    print(DisplayEngine().report()); exit(0)
}
if arguments.contains("--restore") {
    do { try DisplayEngine().restore(); print("Restore requested") } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }; exit(0)
}
if arguments.contains("--check-safety") {
    let engine = DisplayEngine()
    do { try engine.set(engine.known.filter { engine.isActive($0) }, enabled: false); exit(1) }
    catch { print("Last-display guard: \(error.localizedDescription)"); exit(0) }
}


final class GlobalShortcuts {
    private var handler: EventHandlerRef?
    private var registrations: [EventHotKeyRef] = []
    private var actions: [UInt32: () -> Void] = [:]
    private let signature: OSType = 0x44535754 // DSWT
    var errors: [String] = []

    init(toggle: @escaping () -> Void, restore: @escaping () -> Void) {
        actions = [1: toggle, 2: restore]
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let result = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var hotkey = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkey)
            guard result == noErr else { return result }
            let owner = Unmanaged<GlobalShortcuts>.fromOpaque(context).takeUnretainedValue()
            guard hotkey.signature == owner.signature, let action = owner.actions[hotkey.id] else { return OSStatus(eventNotHandledErr) }
            // Always act on the app's main queue; no key event monitoring permission is needed.
            DispatchQueue.main.async(execute: action)
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard result == noErr else { errors.append("Keyboard handler unavailable (\(result))."); return }
        for (id, code, title) in [(UInt32(1), UInt32(kVK_ANSI_1), "⌃⌥⌘1"), (UInt32(2), UInt32(kVK_ANSI_0), "⌃⌥⌘0")] {
            var reference: EventHotKeyRef?
            let result = RegisterEventHotKey(code, UInt32(controlKey | optionKey | cmdKey), EventHotKeyID(signature: signature, id: id), GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &reference)
            if result == noErr, let reference { registrations.append(reference) }
            else { errors.append("\(title) unavailable or already in use (\(result)).") }
        }
    }
    deinit {
        registrations.forEach { UnregisterEventHotKey($0) }
        if let handler { RemoveEventHandler(handler) }
    }
}

func loginStatusText() -> String {
    switch SMAppService.mainApp.status {
    case .enabled: return "On"
    case .notRegistered: return "Off"
    case .requiresApproval: return "Needs approval in System Settings"
    case .notFound: return "Unavailable. Run the installed app"
    @unknown default: return "Unknown"
    }
}
final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = DisplayEngine()
    var status: NSStatusItem!
    var window: NSWindow!
    let popover = NSPopover()
    var contextMenu: NSMenu?
    let windowModel = DisplayWindowModel()
    let brightness = BrightnessController()
    var message = "Choose the displays you want to use."
    var timer: Timer?
    var shortcuts: GlobalShortcuts?
    var operationVersion = 0
    var queuedToggle: DispatchWorkItem?
    var fingerprint = ""
    var switchingUntil = Date.distantPast
    var displayOrder: [String] = []
    var displayNames: [String: String] = [:]
    var preferred: Display? {
        let key = engine.defaults.string(forKey: "preferred")
        return engine.known.first { $0.uuid == key } ?? engine.known.first { $0.name.localizedCaseInsensitiveContains("PG32UCDM") } ?? engine.known.first { engine.isActive($0) && !$0.builtin }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        displayOrder = engine.defaults.stringArray(forKey: "displayOrder") ?? engine.known.map(\.uuid)
        displayNames = engine.defaults.dictionary(forKey: "displayNames") as? [String: String] ?? [:]
        for d in engine.known where !displayOrder.contains(d.uuid) { displayOrder.append(d.uuid) }
        let studios = engine.known.filter { $0.name.hasPrefix("Studio Display") }.sorted { $0.id < $1.id }
        for (i, d) in studios.enumerated() where displayNames[d.uuid] == nil { displayNames[d.uuid] = "Studio Display (\(i + 1))" }
        engine.defaults.set(displayOrder, forKey: "displayOrder")
        engine.defaults.set(displayNames, forKey: "displayNames")
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = BrandArtwork.symbol(size: 20, template: true)
        status.button?.target = self
        status.button?.action = #selector(statusClicked(_:))
        status.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        status.button?.toolTip = "re-sPLAY — Display controls"
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "re-sPLAY"; window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 860, height: 640)
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.backgroundColor = .windowBackgroundColor
        window.toolbarStyle = .unified
        window.toolbar = NSToolbar(identifier: "re-sPLAY.MainToolbar")
        // Preserve the outer frame when extending the content behind window chrome.
        window.styleMask.insert(.fullSizeContentView)
        window.setFrameAutosaveName("DisplaySwitchMainWindow")
        // Give the new controls room once; subsequent launches honor the saved size.
        if !engine.defaults.bool(forKey: "nativeLayoutExpanded") {
            window.setContentSize(NSSize(width: max(1120, window.contentLayoutRect.width), height: 760))
            engine.defaults.set(true, forKey: "nativeLayoutExpanded")
        }
        window.center()
        configureApplicationMenu()
        windowModel.restore = { [weak self] in self?.restoreAction() }
        windowModel.useOnly = { [weak self] id in self?.useOnlyDisplay(id) }
        windowModel.toggle = { [weak self] id in
            guard let self, Date() >= self.switchingUntil, let d = self.engine.known.first(where: { $0.uuid == id }) else { return }
            self.perform { try self.engine.set([d], enabled: !self.engine.isActive(d)) }
        }
        windowModel.prefer = { [weak self] id in self?.engine.defaults.set(id, forKey: "preferred"); self?.refreshUI() }
        windowModel.toggleLogin = { [weak self] in self?.loginAction() }
        brightness.autoChanged = { [weak self] states in self?.windowModel.autoBrightness = states }
        windowModel.setAutoBrightness = { [weak self] id, enabled in
            guard let self, Date() >= self.switchingUntil else { return }
            self.brightness.setAuto(id, enabled: enabled)
        }
        windowModel.retryAutoBrightness = { [weak self] id in self?.brightness.refreshAuto(id) }
        brightness.changed = { [weak self] states in self?.windowModel.brightness = states }
        windowModel.setBrightness = { [weak self] id, value in
            guard let self, Date() >= self.switchingUntil else { return }
            self.brightness.set(id, percent: value)
        }
        windowModel.retryBrightness = { [weak self] id in self?.brightness.refresh(id) }
        window.contentView = NSHostingView(rootView: DisplayWindow(model: windowModel))
        let sidebarAccessory = NSTitlebarAccessoryViewController()
        sidebarAccessory.layoutAttribute = .left
        let sidebarControl = NSHostingView(rootView: WindowSidebarToggle(model: windowModel).ignoresSafeArea())
        sidebarControl.sizingOptions = []
        sidebarAccessory.view = sidebarControl
        sidebarAccessory.view.frame.size = NSSize(width: 48, height: 20)
        window.addTitlebarAccessoryViewController(sidebarAccessory)
        popover.behavior = .transient
        popover.animates = true
        let popoverController = NSHostingController(rootView: MenuPopover(model: windowModel,
            openWindow: { [weak self] in self?.showWindow() },
            quit: { [weak self] in self?.quitAction() }))
        popoverController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = popoverController
        if arguments.contains("--appearance-light") { window.appearance = NSAppearance(named: .aqua); popover.appearance = window.appearance }
        if arguments.contains("--appearance-dark") { window.appearance = NSAppearance(named: .darkAqua); popover.appearance = window.appearance }
        shortcuts = GlobalShortcuts(toggle: { [weak self] in self?.toggleShortcut() }, restore: { [weak self] in self?.restoreShortcut() })
        if arguments.contains("--enable-login") {
            do { if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() } }
            catch { message = "Launch at login: \(error.localizedDescription)" }
        }
        refreshUI()
        if arguments.contains("--show-window") { showWindow() }
        if arguments.contains("--show-popover") { showPopover() }
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.engine.onlineIDs().allSatisfy({ CGDisplayIsActive($0) == 0 }) { try? self.engine.restore() }
            self.refreshUI()
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !popover.isShown else { return false }
        showWindow()
        return true
    }
    @objc func loginAction() {
        do {
            switch SMAppService.mainApp.status {
            case .enabled: try SMAppService.mainApp.unregister()
            case .requiresApproval: SMAppService.openSystemSettingsLoginItems()
            default: try SMAppService.mainApp.register()
            }
            message = "Launch at login: \(loginStatusText())."
        } catch { message = "Couldn’t update launch at login: \(error.localizedDescription)" }
        refreshUI()
    }
    func configureApplicationMenu() {
        let main = NSMenu()
        let appItem = main.addItem(withTitle: "re-sPLAY", action: nil, keyEquivalent: "")
        let appMenu = NSMenu(title: "re-sPLAY")
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Open re-sPLAY", action: #selector(showWindow), keyEquivalent: "o").target = self
        appMenu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        let quick = appMenu.addItem(withTitle: "Quick Controls", action: #selector(showQuickControls), keyEquivalent: "d")
        quick.target = self
        quick.keyEquivalentModifierMask = [.command, .shift]
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Restore displays and quit", action: #selector(quitAction), keyEquivalent: "q").target = self
        NSApp.mainMenu = main
    }
    @objc func showSettings() { windowModel.section = .settings; showWindow() }
    @objc func showQuickControls() { showPopover() }
    @objc func showWindow() { popover.performClose(nil); NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil) }
    @objc func statusClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp, let contextMenu {
            popover.performClose(nil)
            status.menu = contextMenu
            sender.performClick(nil)
            status.menu = nil
        } else if popover.isShown { popover.performClose(nil) }
        else { showPopover() }
    }
    func showPopover() {
        guard let button = status.button else { return }
        refreshUI()
        // Resolve SwiftUI's current height before AppKit anchors the popover.
        // A stale height followed by a shrink can leave a gap below the menu bar.
        if let view = popover.contentViewController?.view {
            view.layoutSubtreeIfNeeded()
            popover.contentSize = view.fittingSize
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // Make only the popover key; activating the application raises its main window.
        popover.contentViewController?.view.window?.makeKey()
    }
    func refreshUI() {
        engine.refresh()
        brightness.update(engine.known.filter { engine.isActive($0) })
        let signature = engine.report() + message + (preferred?.uuid ?? "") + String(Date() < switchingUntil) + loginStatusText()
        guard signature != fingerprint else { return }; fingerprint = signature
        let menu = NSMenu(); menu.autoenablesItems = false
        let focus = menu.addItem(withTitle: "Toggle \(preferred?.name ?? "preferred display") only", action: #selector(focusAction), keyEquivalent: "")
        focus.target = self; focus.isEnabled = Date() >= switchingUntil && (preferred.map { engine.isActive($0) } ?? false)
        focus.title += "  ⌃⌥⌘1"
        menu.addItem(withTitle: "Restore all displays  ⌃⌥⌘0", action: #selector(restoreAction), keyEquivalent: "").target = self
        menu.addItem(.separator())
        for (i, d) in engine.known.enumerated() {
            let state = engine.isActive(d) ? "Disconnect" : "Reconnect"
            let item = menu.addItem(withTitle: "\(state) \(d.name) · \(d.uuid.suffix(4))", action: #selector(toggleAction(_:)), keyEquivalent: "")
            item.target = self; item.tag = i; item.isEnabled = Date() >= switchingUntil && engine.valid(d)
        }
        menu.addItem(.separator())
        let login = menu.addItem(withTitle: "Launch at login: \(loginStatusText())", action: #selector(loginAction), keyEquivalent: "")
        login.target = self; login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(withTitle: "Open re-sPLAY…", action: #selector(showWindow), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Restore displays and quit", action: #selector(quitAction), keyEquivalent: "q").target = self
        contextMenu = menu
        for d in engine.known where !displayOrder.contains(d.uuid) { displayOrder.append(d.uuid) }
        engine.defaults.set(displayOrder, forKey: "displayOrder")
        windowModel.displays = engine.known.sorted { (displayOrder.firstIndex(of: $0.uuid) ?? 0) < (displayOrder.firstIndex(of: $1.uuid) ?? 0) }.map { d in
            let isASUS = d.name.contains("PG32UCDM")
            let name = isASUS ? "ASUS PG32UCDM" : displayNames[d.uuid] ?? d.name
            let subtitle = "Shortcut target"
            return DisplayItem(id: d.uuid, name: name,
                               subtitle: d.uuid == preferred?.uuid ? subtitle : engine.isActive(d) ? "Connected to your Mac" : "Ready to reconnect",
                               active: engine.isActive(d), available: engine.valid(d),
                               preferred: d.uuid == preferred?.uuid, builtin: d.builtin)
        }
        windowModel.preferredID = preferred?.uuid ?? ""
        windowModel.busy = Date() < switchingUntil
        windowModel.message = message
        windowModel.loginEnabled = SMAppService.mainApp.status == .enabled
        windowModel.loginStatus = loginStatusText()
        windowModel.shortcutErrors = shortcuts?.errors ?? []
    }

    // Connect the requested display before taking the others offline.
    func useOnlyDisplay(_ id: String) {
        guard Date() >= switchingUntil else { return }
        queuedToggle?.cancel(); queuedToggle = nil
        engine.refresh()
        guard let target = engine.known.first(where: { $0.uuid == id }) else { return }
        engine.defaults.set(id, forKey: "preferred")
        if engine.isActive(target) { perform { try engine.focus(target) }; return }
        operationVersion += 1
        let version = operationVersion
        do {
            try engine.set([target], enabled: true)
            switchingUntil = Date().addingTimeInterval(15)
            message = "Connecting \(displayNames[target.uuid] ?? target.name)…"
            refreshUI()
            waitForDisplay(id, version: version, attempts: 24)
        } catch { message = "Couldn’t connect display: \(error.localizedDescription)"; refreshUI() }
    }
    func waitForDisplay(_ id: String, version: Int, attempts: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, self.operationVersion == version else { return }
            self.engine.refresh()
            if let target = self.engine.known.first(where: { $0.uuid == id }), self.engine.isActive(target) {
                self.perform { try self.engine.focus(target) }
            } else if attempts > 0 { self.waitForDisplay(id, version: version, attempts: attempts - 1) }
            else {
                self.switchingUntil = .distantPast
                self.message = "Couldn’t connect the selected display. Try Restore all."
                self.refreshUI()
            }
        }
    }
    func perform(_ action: () throws -> Void) {
        operationVersion += 1
        let version = operationVersion
        do { try action(); switchingUntil = Date().addingTimeInterval(10); message = "Switching displays… This can take a few seconds."
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                guard version == self.operationVersion else { return }
                self.engine.refresh()
                let pending = self.engine.known.contains { self.engine.disabled.contains($0.uuid) && self.engine.isActive($0) }
                self.message = pending ? "A display is still active. Try Restore all, then switch again." : "Ready. Choose the displays you want to use."
                self.refreshUI()
            }
        }
        catch { message = error.localizedDescription; let alert = NSAlert(); alert.messageText = "Couldn’t change displays"; alert.informativeText = message; alert.runModal() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.refreshUI() }
    }
    func toggleShortcut() {
        engine.defaults.set("Toggle received at \(Date())", forKey: "lastShortcut")
        queuedToggle?.cancel()
        let delay = max(0, switchingUntil.timeIntervalSinceNow)
        if delay > 0 {
            message = "Display toggle queued. Waiting for the displays to settle."
            refreshUI()
            let work = DispatchWorkItem { [weak self] in self?.queuedToggle = nil; self?.focusAction() }
            queuedToggle = work
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.2, execute: work)
        } else { focusAction() }
    }
    func restoreShortcut() {
        engine.defaults.set("Restore received at \(Date())", forKey: "lastShortcut")
        restoreAction()
    }
    @objc func focusAction() {
        guard Date() >= switchingUntil else { return }
        engine.refresh()
        guard let d = preferred else { return }
        let active = engine.known.filter { engine.isActive($0) }
        if active.count == 1, active.first?.uuid == d.uuid { restoreAction() }
        else { useOnlyDisplay(d.uuid) }
    }
    @objc func restoreAction() { queuedToggle?.cancel(); queuedToggle = nil; perform { try engine.restore() } }
    @objc func toggleAction(_ sender: AnyObject) {
        guard Date() >= switchingUntil else { return }
        let index = (sender as? NSControl)?.tag ?? (sender as? NSMenuItem)?.tag ?? -1
        guard engine.known.indices.contains(index) else { return }
        let d = engine.known[index]; perform { try engine.set([d], enabled: !engine.isActive(d)) }
    }
    @objc func preferAction(_ sender: NSButton) { engine.defaults.set(engine.known[sender.tag].uuid, forKey: "preferred"); refreshUI() }
    @objc func quitAction() { perform { try engine.restore() }; if engine.disabled.isEmpty { NSApp.terminate(nil) } }
    func applicationWillTerminate(_ notification: Notification) { try? engine.restore() }
}
if arguments.contains("--shortcut-status") { print(UserDefaults.standard.string(forKey: "lastShortcut") ?? "No shortcut received"); exit(0) }
if arguments.contains("--login-status") { print(loginStatusText()); exit(0) }
// One instance owns the global shortcuts and the saved display state.
if let existing = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "local.DisplaySwitch" && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
    existing.activate(); exit(0)
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
