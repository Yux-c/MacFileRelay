import Cocoa

enum AppLanguage: String, CaseIterable {
    case chinese = "zh_CN"
    case english = "en_US"
    
    var displayName: String {
        switch self {
        case .chinese: return "简体中文"
        case .english: return "English"
        }
    }
}

final class LocalizationManager {
    static let shared = LocalizationManager()
    
    private let languageKey = "MacFileRelay_Language"
    
    var currentLanguage: AppLanguage {
        get {
            let val = UserDefaults.standard.string(forKey: languageKey) ?? "zh_CN"
            return AppLanguage(rawValue: val) ?? .chinese
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: languageKey)
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
        }
    }
    
    func localized(_ key: String) -> String {
        let isZh = currentLanguage == .chinese
        switch key {
        // Shelf Header
        case "shelf_title": return isZh ? "文件中转站" : "File Relay"
        case "items_count": return isZh ? "%d / %d 项 · %@" : "%d / %d items · %@"
        
        // Tooltips & Buttons
        case "btn_close": return isZh ? "关闭" : "Close"
        case "btn_settings": return isZh ? "偏好设置" : "Settings"
        case "btn_open_folder": return isZh ? "在访达中打开" : "Open in Finder"
        case "btn_clear": return isZh ? "清空全部" : "Clear All"
        case "btn_clear_hotkey": return isZh ? "清除快捷键 (不绑定)" : "Clear Shortcut (Unbind)"
        case "quicklook": return isZh ? "空格预览" : "Quick Look"
        case "btn_cancel": return isZh ? "取消" : "Cancel"
        
        // Clear-All Confirmation
        case "clear_confirm_title": return isZh ? "清空中转站？" : "Clear the shelf?"
        case "clear_confirm_message": return isZh ? "%d 个文件会被移到废纸篓，需要时可以从废纸篓恢复。" : "%d files will be moved to the Trash. You can restore them from there."
        case "clear_confirm_ok": return isZh ? "移到废纸篓" : "Move to Trash"
        
        // Empty State
        case "empty_title": return isZh ? "拖入任意文件暂存" : "Drop files here to relay"
        
        // Menu Bar
        case "menu_toggle": return isZh ? "展开/收起文件中转站 (%@)" : "Toggle File Relay (%@)"
        case "menu_toggle_no_key": return isZh ? "展开/收起文件中转站" : "Toggle File Relay"
        case "menu_settings": return isZh ? "偏好设置..." : "Preferences..."
        case "menu_clear": return isZh ? "清空中转站全部文件" : "Clear All Files"
        case "menu_open_folder": return isZh ? "在访达中打开中转目录" : "Open Storage in Finder"
        case "menu_quit": return isZh ? "退出 Mac 文件中转站" : "Quit MacFileRelay"
        
        // Settings Window
        case "settings_title": return isZh ? "偏好设置 - Mac 文件中转站" : "Preferences - MacFileRelay"
        case "settings_general": return isZh ? "通用" : "General"
        case "settings_language": return isZh ? "界面语言：" : "Language:"
        case "settings_hotkey": return isZh ? "全局呼出快捷键：" : "Global Shortcut:"
        case "settings_hotkey_hint": return isZh ? "点击录制新按键，点 ✖️ 可不绑定快捷键" : "Click to record, or click ✖️ to unbind shortcut"
        case "hotkey_none": return isZh ? "无" : "None"
        case "settings_max_items": return isZh ? "最多保留文件数：" : "Max Files Kept:"
        case "settings_max_items_hint": return isZh ? "范围 5–100，超出时最早存入的文件会移到废纸篓" : "5–100. Oldest files move to the Trash when exceeded."
        
        case "settings_hover_preview": return isZh ? "鼠标在图片上停留 1 秒时显示大图预览" : "Preview images after hovering for 1 second"
        
        // Shake Settings
        case "settings_shake": return isZh ? "启用光标摇晃手势 (拖拽摇晃即出)" : "Enable shake cursor gesture to summon"
        case "settings_shake_close": return isZh ? "展开状态下再次摇晃立即关闭" : "Shake again to close immediately"
        case "settings_shake_sensitivity": return isZh ? "摇晃灵敏度：" : "Shake Sensitivity:"
        case "slider_slow": return isZh ? "迟钝" : "Slow"
        case "slider_fast": return isZh ? "灵敏" : "Fast"
        case "sens_1": return isZh ? "极低灵敏度 (需大幅剧烈摇晃)" : "Very Low (Vigorous shakes)"
        case "sens_2": return isZh ? "偏低灵敏度 (需明显大幅晃动)" : "Low (Larger movements)"
        case "sens_3": return isZh ? "标准灵敏度 (默认推荐 · 适中)" : "Normal (Recommended · Default)"
        case "sens_4": return isZh ? "偏高灵敏度 (轻微晃动即出)" : "High (Gentle wiggles)"
        case "sens_5": return isZh ? "极高灵敏度 (极易触发 · 极速出)" : "Ultra High (Effortless triggers)"
        
        default: return key
        }
    }
}

extension Notification.Name {
    static let languageDidChange = Notification.Name("MacFileRelay_LanguageDidChange")
}

func L(_ key: String) -> String {
    LocalizationManager.shared.localized(key)
}
