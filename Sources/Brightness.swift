import AppKit

import Foundation
import CoreGraphics
import IOKit
import Darwin

struct BrightnessReading {
    let percent: Double
    let method: String
}

// Private APIs are resolved at runtime so an unavailable symbol disables the control cleanly.
final class BrightnessHardware {
    typealias Get = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    typealias Set = @convention(c) (UInt32, Float) -> Int32
    typealias CanChange = @convention(c) (UInt32) -> Bool
    typealias HDRMode = @convention(c) (UInt32) -> UInt8
    typealias Info = @convention(c) (UInt32) -> Unmanaged<CFDictionary>?
    typealias Create = @convention(c) (CFAllocator?, UInt32) -> Unmanaged<CFTypeRef>?
    typealias I2C = @convention(c) (CFTypeRef, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> Int32
    private let displayServices = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
    private let coreDisplay = dlopen("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay", RTLD_NOW)
    private let ioKit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW)
    private func symbol<T>(_ handle: UnsafeMutableRawPointer?, _ name: String, _ type: T.Type) -> T? {
        handle.flatMap { dlsym($0, name) }.map { unsafeBitCast($0, to: type) }
    }
    private func validate(_ display: Display) throws {
        guard CGDisplayIsActive(display.id) != 0,
              let uuid = CGDisplayCreateUUIDFromDisplayID(display.id)?.takeRetainedValue(),
              (CFUUIDCreateString(nil, uuid) as String) == display.uuid else {
            throw SwitchError.message("Reconnect this display to adjust brightness.")
        }
    }
    private func hdrEnabled(_ display: Display) -> Bool {
        (symbol(coreDisplay, "CoreDisplay_Display_IsHDRModeEnabled", HDRMode.self)?(display.id) ?? 0) != 0
    }
    private func native(_ display: Display) throws -> Bool {
        // Native brightness also controls third-party HDR displays. Probe the current
        // capability on every operation: switching HDR can change the available route.
        guard let canChange = symbol(displayServices, "DisplayServicesCanChangeBrightness", CanChange.self) else {
            throw SwitchError.message("macOS brightness capabilities are unavailable on this macOS version.")
        }
        if canChange(display.id) { return true }
        // A monitor may acknowledge DDC luminance without changing its HDR picture.
        // Never silently substitute that register for the macOS HDR brightness control.
        guard !hdrEnabled(display) else {
            throw SwitchError.message("macOS HDR brightness is unavailable. Check this display in System Settings, then retry.")
        }
        return false
    }
    private func readNative(_ display: Display) throws -> BrightnessReading {
        guard let get = symbol(displayServices, "DisplayServicesGetBrightness", Get.self) else { throw SwitchError.message("Brightness control is unavailable on this macOS version.") }
        var value: Float = 0
        guard get(display.id, &value) == 0, value.isFinite, (0...1).contains(value) else { throw SwitchError.message("Couldn’t read this display’s macOS brightness.") }
        return BrightnessReading(percent: Double(value) * 100, method: hdrEnabled(display) ? "macOS · HDR brightness" : "macOS · Display brightness")
    }
    func read(_ display: Display) throws -> BrightnessReading {
        try validate(display)
        if try native(display) { return try readNative(display) }
        let transport = try ddcTransport(display)
        let value = try readDDC(transport)
        return BrightnessReading(percent: Double(value.current) / Double(value.max) * 100, method: "DDC · Hardware brightness")
    }
    func write(_ display: Display, percent: Double) throws -> BrightnessReading {
        try validate(display)
        guard percent.isFinite, (0...100).contains(percent) else { throw SwitchError.message("Brightness must be between 0 and 100%.") }
        if try native(display) {
            guard let set = symbol(displayServices, "DisplayServicesSetBrightness", Set.self), set(display.id, Float(percent / 100)) == 0 else { throw SwitchError.message("macOS couldn’t change brightness.") }
            Thread.sleep(forTimeInterval: 0.08)
            try validate(display)
            guard try native(display) else { throw SwitchError.message("The display mode changed. Try brightness again.") }
            let actual = try readNative(display)
            guard abs(actual.percent - percent) <= 1 else { throw SwitchError.message("macOS did not retain the requested brightness. Check auto-brightness or retry.") }
            return actual
        } else {
            let transport = try ddcTransport(display)
            let previous = try readDDC(transport)
            let value = UInt16((percent / 100 * Double(previous.max)).rounded())
            var bytes: [UInt8] = [0x84, 0x03, 0x10, UInt8(value >> 8), UInt8(value & 255), 0]
            bytes[5] = bytes.prefix(5).reduce(UInt8(0x6e ^ 0x51), ^)
            try send(transport, &bytes)
            Thread.sleep(forTimeInterval: 0.10)
            let actual = try readDDC(transport)
            guard abs(Int(actual.current) - Int(value)) <= 1 else { throw SwitchError.message("The monitor didn’t apply brightness. Check its HDR or picture-mode settings.") }
            return BrightnessReading(percent: Double(actual.current) / Double(actual.max) * 100, method: "DDC · Hardware brightness")
        }
    }

    typealias HasAuto = @convention(c) (UInt32) -> Bool
    typealias GetAuto = @convention(c) (UInt32, UnsafeMutablePointer<Bool>) -> Int32
    typealias SetAuto = @convention(c) (UInt32, Bool) -> Int32

    func readAutoBrightness(_ display: Display) throws -> Bool? {
        try validate(display)
        guard let has = symbol(displayServices, "DisplayServicesHasAmbientLightCompensation", HasAuto.self),
              let get = symbol(displayServices, "DisplayServicesAmbientLightCompensationEnabled", GetAuto.self) else {
            throw SwitchError.message("Auto-brightness control is unavailable on this macOS version.")
        }
        guard has(display.id) else { return nil }
        var enabled = false
        guard get(display.id, &enabled) == 0 else { throw SwitchError.message("Couldn’t read auto-brightness. Try again.") }
        return enabled
    }
    func writeAutoBrightness(_ display: Display, enabled: Bool) throws -> Bool {
        guard try readAutoBrightness(display) != nil else { throw SwitchError.message("This display does not support macOS auto-brightness.") }
        guard let set = symbol(displayServices, "DisplayServicesEnableAmbientLightCompensation", SetAuto.self),
              set(display.id, enabled) == 0 else { throw SwitchError.message("macOS couldn’t change auto-brightness.") }
        guard let actual = try readAutoBrightness(display), actual == enabled else {
            throw SwitchError.message("macOS did not apply auto-brightness. Try again.")
        }
        return actual
    }

    private struct Transport { let service: CFTypeRef; let chip: UInt32 }
    private func property(_ entry: io_registry_entry_t, _ key: String) -> String? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
    }
    private func name(_ entry: io_registry_entry_t) -> String {
        var buffer = [CChar](repeating: 0, count: 128)
        guard IORegistryEntryGetName(entry, &buffer) == KERN_SUCCESS else { return "" }
        return String(cString: buffer)
    }
    private func ddcTransport(_ display: Display) throws -> Transport {
        guard let info = symbol(coreDisplay, "CoreDisplay_DisplayCreateInfoDictionary", Info.self),
              let dictionary = info(display.id)?.takeRetainedValue() as? [String: Any],
              let location = dictionary["IODisplayLocation"] as? String,
              let create = symbol(ioKit, "IOAVServiceCreateWithService", Create.self) else {
            throw SwitchError.message("Hardware brightness isn’t available over this connection.")
        }
        let framebuffer = IORegistryEntryCopyFromPath(kIOMainPortDefault, location as CFString)
        guard framebuffer != 0 else { throw SwitchError.message("The display connection changed. Try again.") }
        defer { IOObjectRelease(framebuffer) }
        var parent: io_registry_entry_t = 0
        guard IORegistryEntryGetParentEntry(framebuffer, kIOServicePlane, &parent) == KERN_SUCCESS else { throw SwitchError.message("Couldn’t identify the display connection.") }
        let portName = name(parent).components(separatedBy: "@")[0]
        IOObjectRelease(parent)
        guard !portName.isEmpty else { throw SwitchError.message("Couldn’t identify the display connection.") }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("DCPAVServiceProxy"), &iterator) == KERN_SUCCESS else { throw SwitchError.message("Display brightness service unavailable.") }
        defer { IOObjectRelease(iterator) }
        var matches: [Transport] = []
        while true {
            let proxy = IOIteratorNext(iterator)
            if proxy == 0 { break }
            defer { IOObjectRelease(proxy) }
            guard property(proxy, "Location") == "External" else { continue }
            var endpoint: io_registry_entry_t = 0
            guard IORegistryEntryGetParentEntry(proxy, kIOServicePlane, &endpoint) == KERN_SUCCESS else { continue }
            defer { IOObjectRelease(endpoint) }
            // Match the exact framebuffer port, never enumeration order or identical monitor names.
            guard name(endpoint).hasPrefix(portName + ":"), let service = create(kCFAllocatorDefault, proxy)?.takeRetainedValue() else { continue }
            let chip: UInt32 = property(endpoint, "EPICProviderClass") == "AppleDCPMCDP29XX" ? 0xb7 : 0x37
            matches.append(Transport(service: service, chip: chip))
        }
        guard matches.count == 1 else { throw SwitchError.message("Hardware brightness isn’t available over this connection.") }
        return matches[0]
    }
    private func send(_ transport: Transport, _ bytes: inout [UInt8]) throws {
        guard let write = symbol(ioKit, "IOAVServiceWriteI2C", I2C.self) else { throw SwitchError.message("DDC brightness is unavailable.") }
        Thread.sleep(forTimeInterval: 0.01)
        let result = bytes.withUnsafeMutableBytes { write(transport.service, transport.chip, 0x51, $0.baseAddress!, UInt32($0.count)) }
        guard result == 0 else { throw SwitchError.message("No response from the monitor. Check that DDC/CI is enabled.") }
    }
    private func readDDC(_ transport: Transport) throws -> (current: UInt16, max: UInt16) {
        guard let read = symbol(ioKit, "IOAVServiceReadI2C", I2C.self) else { throw SwitchError.message("DDC brightness is unavailable.") }
        // DDC/CI Get VCP 0x10 (luminance). No power, input or contrast commands are sent.
        var request: [UInt8] = [0x82, 0x01, 0x10, 0x6e ^ 0x82 ^ 0x01 ^ 0x10]
        for _ in 0..<3 {
            try send(transport, &request)
            Thread.sleep(forTimeInterval: 0.06)
            var reply = [UInt8](repeating: 0, count: 12)
            let result = reply.withUnsafeMutableBytes { read(transport.service, transport.chip, 0x51, $0.baseAddress!, UInt32($0.count)) }
            if result == 0, reply[0] == 0x6e, reply[1] == 0x88, reply[2] == 0x02, reply[3] == 0, reply[4] == 0x10,
               reply.prefix(11).reduce(UInt8(0x50), ^) == 0 {
                let max = UInt16(reply[6]) << 8 | UInt16(reply[7])
                let current = UInt16(reply[8]) << 8 | UInt16(reply[9])
                if max > 0 && current <= max { return (current, max) }
            }
        }
        throw SwitchError.message("Brightness didn’t respond. Enable DDC/CI in the monitor’s settings, then retry.")
    }
}

struct BrightnessState {
    var percent: Double?
    var detail = "Reading brightness…"
    var error: String?
    var updating = false
}

// All device I/O is serial and off the main thread. Request revisions prevent a
// delayed read from overwriting a newer slider value or a reconnected display.
struct AutoBrightnessState {
    var enabled: Bool?
    var error: String?
    var updating = false
}

final class BrightnessController {
    private let hardware = BrightnessHardware()
    private let queue = DispatchQueue(label: "local.DisplaySwitch.brightness", qos: .userInitiated)
    private var displays: [String: Display] = [:]
    private var revisions: [String: Int] = [:]
    private var pending: [String: DispatchWorkItem] = [:]
    private var reading: Set<String> = []
    private var lastRead: [String: Date] = [:]
    private(set) var states: [String: BrightnessState] = [:]
    var changed: ([String: BrightnessState]) -> Void = { _ in }

    private var autoRevisions: [String: Int] = [:]
    private var autoReading: Set<String> = []
    private var autoLastRead: [String: Date] = [:]
    private(set) var autoStates: [String: AutoBrightnessState] = [:]
    var autoChanged: ([String: AutoBrightnessState]) -> Void = { _ in }

    func refreshAuto(_ id: String) {
        guard let display = displays[id], !autoReading.contains(id), autoStates[id]?.updating != true else { return }
        let revision = autoRevisions[id, default: 0]
        autoReading.insert(id)
        autoLastRead[id] = Date()
        queue.async {
            let result = Result { try self.hardware.readAutoBrightness(display) }
            DispatchQueue.main.async {
                self.autoReading.remove(id)
                guard self.autoRevisions[id, default: 0] == revision, self.displays[id]?.id == display.id else { return }
                switch result {
                case .success(let enabled): self.autoStates[id] = AutoBrightnessState(enabled: enabled)
                case .failure(let error): self.autoStates[id] = AutoBrightnessState(error: error.localizedDescription)
                }
                self.autoChanged(self.autoStates)
            }
        }
    }
    func setAuto(_ id: String, enabled: Bool) {
        guard let display = displays[id], autoStates[id]?.enabled != nil, autoStates[id]?.updating != true else { return }
        autoRevisions[id, default: 0] += 1
        let revision = autoRevisions[id]!
        // Keep the last confirmed switch position until macOS acknowledges the change.
        autoStates[id]?.updating = true
        autoStates[id]?.error = nil
        autoChanged(autoStates)
        queue.async {
            let current = DispatchQueue.main.sync { self.autoRevisions[id] == revision && self.displays[id]?.id == display.id }
            guard current else { return }
            let result = Result { try self.hardware.writeAutoBrightness(display, enabled: enabled) }
            DispatchQueue.main.async {
                guard self.autoRevisions[id] == revision, self.displays[id]?.id == display.id else { return }
                self.autoLastRead[id] = Date()
                switch result {
                case .success(let actual): self.autoStates[id] = AutoBrightnessState(enabled: actual)
                case .failure(let error): self.autoStates[id] = AutoBrightnessState(error: error.localizedDescription)
                }
                self.autoChanged(self.autoStates)
                self.refresh(id)
            }
        }
    }

    func update(_ active: [Display]) {
        let next = Dictionary(uniqueKeysWithValues: active.map { ($0.uuid, $0) })
        for id in displays.keys where next[id]?.id != displays[id]?.id {
            revisions[id, default: 0] += 1
            autoRevisions[id, default: 0] += 1
            autoStates.removeValue(forKey: id)
            autoLastRead.removeValue(forKey: id)
            pending.removeValue(forKey: id)?.cancel()
            states.removeValue(forKey: id)
            lastRead.removeValue(forKey: id)
        }
        displays = next
        changed(states)
        autoChanged(autoStates)
        for display in active where Date().timeIntervalSince(autoLastRead[display.uuid] ?? .distantPast) > 15 { refreshAuto(display.uuid) }
        for display in active where Date().timeIntervalSince(lastRead[display.uuid] ?? .distantPast) > 15 { refresh(display.uuid) }
    }
    func refresh(_ id: String) {
        guard let display = displays[id], !reading.contains(id), pending[id] == nil, states[id]?.updating != true else { return }
        let revision = revisions[id, default: 0]
        reading.insert(id)
        lastRead[id] = Date()
        queue.async {
            let result = Result { try self.hardware.read(display) }
            DispatchQueue.main.async {
                self.reading.remove(id)
                guard self.revisions[id, default: 0] == revision, self.displays[id]?.id == display.id else { return }
                self.apply(result, id: id)
            }
        }
    }
    func set(_ id: String, percent: Double) {
        guard let display = displays[id], percent.isFinite else { return }
        let value = min(100, max(0, percent))
        revisions[id, default: 0] += 1
        let revision = revisions[id]!
        pending.removeValue(forKey: id)?.cancel()
        states[id] = BrightnessState(percent: value, detail: states[id]?.detail ?? "Brightness", updating: true)
        changed(states)
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pending.removeValue(forKey: id)
            self.queue.async {
                let current = DispatchQueue.main.sync { self.revisions[id] == revision && self.displays[id]?.id == display.id }
                guard current else { return }
                let result = Result { try self.hardware.write(display, percent: value) }
                DispatchQueue.main.async {
                    guard self.revisions[id] == revision, self.displays[id]?.id == display.id else { return }
                    self.lastRead[id] = Date()
                    self.apply(result, id: id)
                }
            }
        }
        pending[id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }
    private func apply(_ result: Result<BrightnessReading, Error>, id: String) {
        switch result {
        case .success(let value): states[id] = BrightnessState(percent: value.percent, detail: value.method)
        case .failure(let error): states[id] = BrightnessState(detail: "Brightness unavailable", error: error.localizedDescription)
        }
        changed(states)
    }
}
