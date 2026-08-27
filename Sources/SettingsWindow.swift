import Cocoa

final class HotkeyRecorderView: NSButton {
    private var isRecording = false
    private var localMonitor: Any?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        bezelStyle = .rounded
        wantsLayer = true
        layer?.cornerRadius = 6
        updateTitle()
        target = self
        action = #selector(clickedRecorder)
    }
    
    func updateTitle() {
        let isZh = LocalizationManager.shared.currentLanguage == .chinese
        if isRecording {
            title = isZh ? "⌨️ 按新键或按退格清除..." : "⌨️ Press key or Delete..."
            layer?.borderColor = NSColor.controlAccentColor.cgColor
            layer?.borderWidth = 1.5
        } else {
            let str = HotkeyManager.shared.displayString
            title = "  " + str + "  "
            layer?.borderColor = NSColor.separatorColor.cgColor
            layer?.borderWidth = 1.0
        }
    }
    
    @objc private func clickedRecorder() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func startRecording() {
        isRecording = true
        updateTitle()
        window?.makeFirstResponder(self)
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isRecording else { return event }
            
            // Allow ESC to cancel recording
            if event.keyCode == 53 {
                self.stopRecording()
                return nil
            }
            
            // Allow Delete / Backspace to clear shortcut (unbind)
            if event.keyCode == 51 || event.keyCode == 117 {
                HotkeyManager.shared.currentShortcut = nil
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                self.stopRecording()
                return nil
            }
            
            let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
            // Require at least one modifier or standard function keys
            if flags.rawValue != 0 || event.keyCode >= 96 {
                let newShortcut = SavedShortcut(keyCode: event.keyCode, modifierFlags: flags.rawValue)
                HotkeyManager.shared.currentShortcut = newShortcut
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                self.stopRecording()
                return nil
            }
            return nil
        }
    }
    
    func stopRecording() {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        updateTitle()
    }
    
    override func resignFirstResponder() -> Bool {
        if isRecording {
            stopRecording()
        }
        return super.resignFirstResponder()
    }
}

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()
    
    private let visualEffect = NSVisualEffectView()
    private let titleLabel = NSTextField(labelWithString: "")
    
    // Language Section
    private let langTitle = NSTextField(labelWithString: "")
    private let langPopup = NSPopUpButton()
    
    // Hotkey Section
    private let hotkeyTitle = NSTextField(labelWithString: "")
    private let hotkeyRecorder = HotkeyRecorderView(frame: NSRect(x: 0, y: 0, width: 120, height: 28))
    private let hotkeyClearBtn = NSButton()
    private let hotkeyResetBtn = NSButton()
    private let hotkeyHint = NSTextField(labelWithString: "")
    
    // AutoClean Section
    private let autoCleanTitle = NSTextField(labelWithString: "")
    private let autoCleanPopup = NSPopUpButton()
    
    // Shake Section
    private let shakeCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let shakeDesc = NSTextField(labelWithString: "")
    
    init() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 350),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.center()
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        
        super.init(window: window)
        setupUI()
        
        NotificationCenter.default.addObserver(self, selector: #selector(refreshText), name: .languageDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshShortcut), name: .shortcutDidChange, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        guard let window = window, let contentView = window.contentView else { return }
        
        visualEffect.frame = contentView.bounds
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        contentView.addSubview(visualEffect)
        
        // Window Title
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.frame = NSRect(x: 24, y: contentView.bounds.height - 48, width: 390, height: 24)
        visualEffect.addSubview(titleLabel)
        
        var currentY = contentView.bounds.height - 90
        
        // 1. Language Section
        langTitle.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        langTitle.frame = NSRect(x: 24, y: currentY, width: 140, height: 22)
        visualEffect.addSubview(langTitle)
        
        langPopup.frame = NSRect(x: 170, y: currentY - 2, width: 240, height: 26)
        for lang in AppLanguage.allCases {
            langPopup.addItem(withTitle: lang.displayName)
        }
        langPopup.target = self
        langPopup.action = #selector(languageChanged)
        visualEffect.addSubview(langPopup)
        
        currentY -= 50
        
        // 2. Hotkey Section
        hotkeyTitle.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        hotkeyTitle.frame = NSRect(x: 24, y: currentY, width: 140, height: 22)
        visualEffect.addSubview(hotkeyTitle)
        
        hotkeyRecorder.frame = NSRect(x: 170, y: currentY - 3, width: 120, height: 28)
        visualEffect.addSubview(hotkeyRecorder)
        
        // Clear Hotkey (X button)
        hotkeyClearBtn.bezelStyle = .texturedRounded
        hotkeyClearBtn.isBordered = false
        hotkeyClearBtn.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Clear Shortcut")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 14, weight: .medium))
        hotkeyClearBtn.contentTintColor = NSColor.secondaryLabelColor
        hotkeyClearBtn.frame = NSRect(x: 296, y: currentY - 1, width: 24, height: 24)
        hotkeyClearBtn.target = self
        hotkeyClearBtn.action = #selector(clearHotkey)
        visualEffect.addSubview(hotkeyClearBtn)
        
        // Reset Hotkey Button
        hotkeyResetBtn.bezelStyle = .rounded
        hotkeyResetBtn.title = "恢复默认"
        hotkeyResetBtn.frame = NSRect(x: 326, y: currentY - 3, width: 85, height: 28)
        hotkeyResetBtn.target = self
        hotkeyResetBtn.action = #selector(resetHotkey)
        visualEffect.addSubview(hotkeyResetBtn)
        
        hotkeyHint.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        hotkeyHint.textColor = .secondaryLabelColor
        hotkeyHint.frame = NSRect(x: 170, y: currentY - 22, width: 250, height: 16)
        visualEffect.addSubview(hotkeyHint)
        
        currentY -= 60
        
        // 3. AutoClean Section
        autoCleanTitle.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        autoCleanTitle.frame = NSRect(x: 24, y: currentY, width: 140, height: 22)
        visualEffect.addSubview(autoCleanTitle)
        
        autoCleanPopup.frame = NSRect(x: 170, y: currentY - 2, width: 240, height: 26)
        autoCleanPopup.target = self
        autoCleanPopup.action = #selector(autoCleanChanged)
        visualEffect.addSubview(autoCleanPopup)
        
        currentY -= 50
        
        // 4. Shake Section
        shakeCheckbox.frame = NSRect(x: 24, y: currentY, width: 390, height: 20)
        shakeCheckbox.target = self
        shakeCheckbox.action = #selector(shakeToggled)
        visualEffect.addSubview(shakeCheckbox)
        
        shakeDesc.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        shakeDesc.textColor = .secondaryLabelColor
        shakeDesc.frame = NSRect(x: 44, y: currentY - 18, width: 370, height: 16)
        visualEffect.addSubview(shakeDesc)
        
        refreshText()
    }
    
    @objc func refreshText() {
        let isZh = LocalizationManager.shared.currentLanguage == .chinese
        
        titleLabel.stringValue = L("settings_title")
        langTitle.stringValue = L("settings_language")
        langPopup.selectItem(withTitle: LocalizationManager.shared.currentLanguage.displayName)
        
        hotkeyTitle.stringValue = L("settings_hotkey")
        hotkeyClearBtn.toolTip = L("btn_clear_hotkey")
        hotkeyResetBtn.title = isZh ? "恢复默认" : "Reset"
        hotkeyHint.stringValue = L("settings_hotkey_hint")
        hotkeyRecorder.updateTitle()
        
        autoCleanTitle.stringValue = L("menu_autoclean") + "："
        
        autoCleanPopup.removeAllItems()
        let options: [(String, Int)] = [
            (L("autoclean_1h"), 1),
            (L("autoclean_12h"), 12),
            (L("autoclean_24h"), 24),
            (L("autoclean_3d"), 72),
            (L("autoclean_7d"), 168),
            (L("autoclean_never"), 0)
        ]
        let currentHours = AutoCleanManager.shared.retentionHours
        for (idx, opt) in options.enumerated() {
            autoCleanPopup.addItem(withTitle: opt.0)
            autoCleanPopup.item(at: idx)?.tag = opt.1
            if opt.1 == currentHours {
                autoCleanPopup.selectItem(at: idx)
            }
        }
        
        shakeCheckbox.title = L("settings_shake")
        shakeCheckbox.state = UserDefaults.standard.bool(forKey: "MacFileRelay_DisableShake") ? .off : .on
        shakeDesc.stringValue = L("settings_shake_desc")
    }
    
    @objc func refreshShortcut() {
        hotkeyRecorder.updateTitle()
    }
    
    @objc private func languageChanged() {
        if let selectedTitle = langPopup.titleOfSelectedItem,
           let lang = AppLanguage.allCases.first(where: { $0.displayName == selectedTitle }) {
            LocalizationManager.shared.currentLanguage = lang
        }
    }
    
    @objc private func clearHotkey() {
        HotkeyManager.shared.currentShortcut = nil
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        hotkeyRecorder.updateTitle()
    }
    
    @objc private func resetHotkey() {
        HotkeyManager.shared.currentShortcut = .default
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        hotkeyRecorder.updateTitle()
    }
    
    @objc private func autoCleanChanged() {
        if let selectedItem = autoCleanPopup.selectedItem {
            AutoCleanManager.shared.retentionHours = selectedItem.tag
        }
    }
    
    @objc private func shakeToggled() {
        let isEnabled = shakeCheckbox.state == .on
        UserDefaults.standard.set(!isEnabled, forKey: "MacFileRelay_DisableShake")
    }
    
    func showSettings() {
        refreshText()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
