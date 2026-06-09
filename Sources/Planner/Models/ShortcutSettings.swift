import AppKit
import Combine

/// 단축키 한 개(가상 keyCode + 보조키).
struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    /// NSEvent.ModifierFlags.rawValue (command/option/control/shift만).
    var modifiers: UInt

    var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    var display: String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        s += Shortcut.keyName(keyCode)
        return s
    }

    /// 보조키가 하나라도 있어야 전역 단축키로 유효.
    var hasModifier: Bool {
        flags.intersection([.command, .option, .control, .shift]).isEmpty == false
    }

    static func make(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Shortcut {
        let masked = flags.intersection([.command, .option, .control, .shift])
        return Shortcut(keyCode: UInt32(keyCode), modifiers: masked.rawValue)
    }

    static func keyName(_ code: UInt32) -> String {
        if let n = keyNames[code] { return n }
        return "key\(code)"
    }

    private static let keyNames: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 43: ",", 45: "N", 46: "M", 47: ".",
        48: "⇥", 49: "␣", 50: "`", 51: "⌫", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑"
    ]
}

/// 단축키 설정(UserDefaults 영속).
@MainActor
final class ShortcutSettings: ObservableObject {
    static let shared = ShortcutSettings()

    static let defaultDropdown = Shortcut(keyCode: 17,
        modifiers: NSEvent.ModifierFlags([.command, .option]).rawValue)   // ⌥⌘T
    static let defaultScheduler = Shortcut(keyCode: 1,
        modifiers: NSEvent.ModifierFlags([.command, .option]).rawValue)   // ⌥⌘S

    @Published var dropdown: Shortcut { didSet { persist(); onChange?() } }
    @Published var scheduler: Shortcut { didSet { persist(); onChange?() } }

    /// 설정 변경 시 호출(핫키 재등록용).
    var onChange: (() -> Void)?

    private init() {
        dropdown = Self.load("hk.dropdown") ?? Self.defaultDropdown
        scheduler = Self.load("hk.scheduler") ?? Self.defaultScheduler
    }

    func resetToDefaults() {
        dropdown = Self.defaultDropdown
        scheduler = Self.defaultScheduler
    }

    private func persist() {
        Self.store("hk.dropdown", dropdown)
        Self.store("hk.scheduler", scheduler)
    }

    private static func load(_ key: String) -> Shortcut? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Shortcut.self, from: data)
    }

    private static func store(_ key: String, _ s: Shortcut) {
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
