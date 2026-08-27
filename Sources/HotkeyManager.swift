import Cocoa
import Carbon

struct SavedShortcut: Codable, Equatable {
    var keyCode: UInt16
    var modifierFlags: UInt
    
    // Default: Option + D (keyCode: 2)
    static let `default` = SavedShortcut(keyCode: 2, modifierFlags: NSEvent.ModifierFlags.option.rawValue)
    
    var displayString: String {
        var str = ""
        let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)
        
        if flags.contains(.control) { str += "⌃ " }
        if flags.contains(.option) { str += "⌥ " }
        if flags.contains(.shift) { str += "⇧ " }
        if flags.contains(.command) { str += "⌘ " }
        
        str += keyString(for: keyCode)
        return str.trimmingCharacters(in: .whitespaces)
    }
    
    private func keyString(for code: UInt16) -> String {
        switch code {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "Return"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "Delete"
        case 53: return "Esc"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "Key \(code)"
        }
    }
}

final class HotkeyManager {
    static let shared = HotkeyManager()
    
    private let hotkeyKey = "MacFileRelay_Shortcut"
    var onShortcutTriggered: (() -> Void)?
    
    var currentShortcut: SavedShortcut {
        get {
            guard let data = UserDefaults.standard.data(forKey: hotkeyKey),
                  let shortcut = try? JSONDecoder().decode(SavedShortcut.self, from: data) else {
                return .default
            }
            return shortcut
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: hotkeyKey)
                NotificationCenter.default.post(name: .shortcutDidChange, object: nil)
            }
        }
    }
    
    private init() {
        setupGlobalMonitor()
    }
    
    private func setupGlobalMonitor() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.checkEvent(event)
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.checkEvent(event) == true {
                return nil
            }
            return event
        }
    }
    
    @discardableResult
    private func checkEvent(_ event: NSEvent) -> Bool {
        let shortcut = currentShortcut
        let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
        let expectedFlags = NSEvent.ModifierFlags(rawValue: shortcut.modifierFlags).intersection([.command, .option, .shift, .control])
        
        if event.keyCode == shortcut.keyCode && flags == expectedFlags {
            DispatchQueue.main.async { [weak self] in
                self?.onShortcutTriggered?()
            }
            return true
        }
        return false
    }
}

extension Notification.Name {
    static let shortcutDidChange = Notification.Name("MacFileRelay_ShortcutDidChange")
}
