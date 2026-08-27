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
    private let shakeCloseCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    
    // Shake Slider Section
    private let shakeSensitivityTitle = NSTextField(labelWithString: "")
    private let shakeSlider = NSSlider()
    private let sliderSlowLabel = NSTextField(labelWithString: "")
    private let sliderFastLabel = NSTextField(labelWithString: "")
    private let shakeLevelLabel = NSTextField(labelWithString: "")
    
    init() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 440),
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
        
        // Window Title - Shifted down with comfortable margin below traffic light buttons
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.frame = NSRect(x: 24, y: contentView.bounds.height - 66, width: 400, height: 24)
        visualEffect.addSubview(titleLabel)
        
        var currentY = contentView.bounds.height - 106
        
        // 1. Language Section
        langTitle.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        langTitle.frame = NSRect(x: 24, y: currentY, width: 140, height: 22)
        visualEffect.addSubview(langTitle)
        
        langPopup.frame = NSRect(x: 170, y: currentY - 2, width: 250, height: 26)
        for lang in AppLanguage.allCases {
            langPopup.addItem(withTitle: lang.displayName)
        }
        langPopup.target = self
        langPopup.action = #selector(languageChanged)
        visualEffect.addSubview(langPopup)
        
        currentY -= 48
        
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
        hotkeyClearBtn.frame = NSRect(x: 298, y: currentY - 1, width: 24, height: 24)
        hotkeyClearBtn.target = self
        hotkeyClearBtn.action = #selector(clearHotkey)
        visualEffect.addSubview(hotkeyClearBtn)
        
        // Reset Hotkey Button
        hotkeyResetBtn.bezelStyle = .rounded
        hotkeyResetBtn.title = "恢复默认"
        hotkeyResetBtn.frame = NSRect(x: 328, y: currentY - 3, width: 92, height: 28)
        hotkeyResetBtn.target = self
        hotkeyResetBtn.action = #selector(resetHotkey)
        visualEffect.addSubview(hotkeyResetBtn)
        
        hotkeyHint.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        hotkeyHint.textColor = .secondaryLabelColor
        hotkeyHint.frame = NSRect(x: 170, y: currentY - 20, width: 260, height: 16)
        visualEffect.addSubview(hotkeyHint)
        
        currentY -= 56
        
        // 3. AutoClean Section
        autoCleanTitle.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        autoCleanTitle.frame = NSRect(x: 24, y: currentY, width: 140, height: 22)
        visualEffect.addSubview(autoCleanTitle)
        
        autoCleanPopup.frame = NSRect(x: 170, y: currentY - 2, width: 250, height: 26)
        autoCleanPopup.target = self
        autoCleanPopup.action = #selector(autoCleanChanged)
        visualEffect.addSubview(autoCleanPopup)
        
        currentY -= 48
        
        // 4. Shake Section
        shakeCheckbox.frame = NSRect(x: 24, y: currentY, width: 400, height: 20)
        shakeCheckbox.target = self
        shakeCheckbox.action = #selector(shakeToggled)
        visualEffect.addSubview(shakeCheckbox)
        
        currentY -= 26
        
        shakeCloseCheckbox.frame = NSRect(x: 24, y: currentY, width: 400, height: 20)
        shakeCloseCheckbox.target = self
        shakeCloseCheckbox.action = #selector(shakeCloseToggled)
        visualEffect.addSubview(shakeCloseCheckbox)
        
        currentY -= 46
        
        // 5. Shake Slider
        shakeSensitivityTitle.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        shakeSensitivityTitle.frame = NSRect(x: 24, y: currentY - 2, width: 140, height: 22)
        visualEffect.addSubview(shakeSensitivityTitle)
        
        sliderSlowLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        sliderSlowLabel.textColor = .secondaryLabelColor
        sliderSlowLabel.alignment = .right
        sliderSlowLabel.frame = NSRect(x: 130, y: currentY - 4, width: 36, height: 18)
        visualEffect.addSubview(sliderSlowLabel)
        
        shakeSlider.minValue = 1
        shakeSlider.maxValue = 5
        shakeSlider.numberOfTickMarks = 5
        shakeSlider.allowsTickMarkValuesOnly = true
        shakeSlider.frame = NSRect(x: 172, y: currentY - 8, width: 200, height: 26)
        shakeSlider.target = self
        shakeSlider.action = #selector(sliderChanged)
        visualEffect.addSubview(shakeSlider)
        
        sliderFastLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        sliderFastLabel.textColor = .secondaryLabelColor
        sliderFastLabel.frame = NSRect(x: 378, y: currentY - 4, width: 36, height: 18)
        visualEffect.addSubview(sliderFastLabel)
        
        shakeLevelLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        shakeLevelLabel.textColor = .controlAccentColor
        shakeLevelLabel.frame = NSRect(x: 172, y: currentY - 28, width: 250, height: 18)
        visualEffect.addSubview(shakeLevelLabel)
        
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
        
        autoCleanTitle.stringValue = L("settings_autoclean")
        
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
        
        let isShakeEnabled = ShakeDetector.shared.isShakeEnabled
        shakeCheckbox.title = L("settings_shake")
        shakeCheckbox.state = isShakeEnabled ? .on : .off
        
        let isShakeCloseEnabled = ShakeDetector.shared.isShakeCloseEnabled
        shakeCloseCheckbox.title = L("settings_shake_close")
        shakeCloseCheckbox.state = isShakeCloseEnabled ? .on : .off
        shakeCloseCheckbox.isEnabled = isShakeEnabled
        shakeCloseCheckbox.alphaValue = isShakeEnabled ? 1.0 : 0.4
        
        shakeSensitivityTitle.stringValue = L("settings_shake_sensitivity")
        sliderSlowLabel.stringValue = L("slider_slow")
        sliderFastLabel.stringValue = L("slider_fast")
        
        let sens = ShakeDetector.shared.sensitivity
        shakeSlider.integerValue = sens.rawValue
        updateSliderLevelLabel(for: sens.rawValue)
        
        let alpha: CGFloat = isShakeEnabled ? 1.0 : 0.4
        shakeSensitivityTitle.alphaValue = alpha
        shakeSlider.isEnabled = isShakeEnabled
        shakeSlider.alphaValue = alpha
        sliderSlowLabel.alphaValue = alpha
        sliderFastLabel.alphaValue = alpha
        shakeLevelLabel.alphaValue = alpha
    }
    
    private func updateSliderLevelLabel(for value: Int) {
        switch value {
        case 1: shakeLevelLabel.stringValue = L("sens_1")
        case 2: shakeLevelLabel.stringValue = L("sens_2")
        case 3: shakeLevelLabel.stringValue = L("sens_3")
        case 4: shakeLevelLabel.stringValue = L("sens_4")
        case 5: shakeLevelLabel.stringValue = L("sens_5")
        default: shakeLevelLabel.stringValue = L("sens_3")
        }
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
        ShakeDetector.shared.isShakeEnabled = (shakeCheckbox.state == .on)
        refreshText()
    }
    
    @objc private func shakeCloseToggled() {
        ShakeDetector.shared.isShakeCloseEnabled = (shakeCloseCheckbox.state == .on)
    }
    
    @objc private func sliderChanged() {
        let val = shakeSlider.integerValue
        if let sens = ShakeSensitivity(rawValue: val) {
            ShakeDetector.shared.sensitivity = sens
            updateSliderLevelLabel(for: val)
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }
    
    func showSettings() {
        refreshText()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
