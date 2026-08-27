import Cocoa
import QuartzCore
import QuickLookUI

final class FloatingShelfView: NSView {
    weak var windowController: FloatingShelfWindow?
    
    let backgroundEffect = NSVisualEffectView()
    let headerView = NSView()
    let titleLabel = NSTextField(labelWithString: "📦 文件中转站")
    let countLabel = NSTextField(labelWithString: "")
    let autoCleanBadge = NSTextField(labelWithString: "")
    
    let zipButton = NSButton()
    let openFolderButton = NSButton()
    let clearAllButton = NSButton()
    let settingsButton = NSButton()
    let closeButton = NSButton()
    
    let scrollView = NSScrollView()
    let shelfGridView = ShelfGridView()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupViews()
        registerForDraggedTypes([.fileURL, .URL, .png, .tiff])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        // Frosted Glass Window Background
        backgroundEffect.frame = bounds
        backgroundEffect.autoresizingMask = [.width, .height]
        backgroundEffect.material = .hudWindow
        backgroundEffect.blendingMode = .behindWindow
        backgroundEffect.state = .active
        backgroundEffect.wantsLayer = true
        backgroundEffect.layer?.cornerRadius = 18
        backgroundEffect.layer?.cornerCurve = .continuous
        backgroundEffect.layer?.masksToBounds = true
        backgroundEffect.layer?.borderWidth = 1.2
        backgroundEffect.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        addSubview(backgroundEffect)
        
        // Header
        headerView.frame = NSRect(x: 0, y: bounds.height - 38, width: bounds.width, height: 38)
        headerView.autoresizingMask = [.width, .minYMargin]
        backgroundEffect.addSubview(headerView)
        
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.frame = NSRect(x: 16, y: 10, width: 78, height: 20)
        headerView.addSubview(titleLabel)
        
        countLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        countLabel.textColor = .secondaryLabelColor
        countLabel.frame = NSRect(x: 96, y: 10, width: 140, height: 20)
        headerView.addSubview(countLabel)
        
        autoCleanBadge.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        autoCleanBadge.textColor = .tertiaryLabelColor
        autoCleanBadge.frame = NSRect(x: 240, y: 11, width: 100, height: 18)
        headerView.addSubview(autoCleanBadge)
        
        // Close Button
        closeButton.bezelStyle = .texturedRounded
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .medium))
        closeButton.contentTintColor = NSColor.secondaryLabelColor
        closeButton.frame = NSRect(x: bounds.width - 32, y: 9, width: 22, height: 22)
        closeButton.autoresizingMask = [.minXMargin]
        closeButton.target = self
        closeButton.action = #selector(closeClicked)
        headerView.addSubview(closeButton)
        
        // Settings Button
        settingsButton.bezelStyle = .texturedRounded
        settingsButton.isBordered = false
        settingsButton.image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: "Settings")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 11, weight: .medium))
        settingsButton.contentTintColor = NSColor.secondaryLabelColor
        settingsButton.frame = NSRect(x: bounds.width - 58, y: 8, width: 22, height: 22)
        settingsButton.autoresizingMask = [.minXMargin]
        settingsButton.target = self
        settingsButton.action = #selector(showSettingsMenu)
        headerView.addSubview(settingsButton)
        
        // Open Folder Button
        openFolderButton.bezelStyle = .texturedRounded
        openFolderButton.isBordered = false
        openFolderButton.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: "Open Folder")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 11, weight: .medium))
        openFolderButton.contentTintColor = NSColor.secondaryLabelColor
        openFolderButton.frame = NSRect(x: bounds.width - 82, y: 8, width: 22, height: 22)
        openFolderButton.autoresizingMask = [.minXMargin]
        openFolderButton.target = self
        openFolderButton.action = #selector(openFolderClicked)
        headerView.addSubview(openFolderButton)
        
        // Zip Archive Button
        zipButton.bezelStyle = .texturedRounded
        zipButton.isBordered = false
        zipButton.image = NSImage(systemSymbolName: "doc.zipper", accessibilityDescription: "Zip All")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 11, weight: .medium))
        zipButton.contentTintColor = NSColor.secondaryLabelColor
        zipButton.frame = NSRect(x: bounds.width - 106, y: 8, width: 22, height: 22)
        zipButton.autoresizingMask = [.minXMargin]
        zipButton.target = self
        zipButton.action = #selector(zipAllClicked)
        headerView.addSubview(zipButton)
        
        // Clear All Button
        clearAllButton.bezelStyle = .texturedRounded
        clearAllButton.isBordered = false
        clearAllButton.image = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: "Clear All")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 11, weight: .medium))
        clearAllButton.contentTintColor = NSColor.secondaryLabelColor
        clearAllButton.frame = NSRect(x: bounds.width - 130, y: 8, width: 22, height: 22)
        clearAllButton.autoresizingMask = [.minXMargin]
        clearAllButton.target = self
        clearAllButton.action = #selector(clearAllClicked)
        headerView.addSubview(clearAllButton)
        
        // ScrollView
        scrollView.frame = NSRect(x: 6, y: 6, width: bounds.width - 12, height: bounds.height - 48)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        
        shelfGridView.frame = NSRect(x: 0, y: 0, width: scrollView.bounds.width, height: scrollView.bounds.height)
        shelfGridView.onItemsUpdated = { [weak self] in
            self?.updateItemCount()
        }
        scrollView.documentView = shelfGridView
        backgroundEffect.addSubview(scrollView)
        
        updateItemCount()
        
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
    }
    
    func updateItemCount() {
        let count = StorageManager.shared.items.count
        if count > 0 {
            let size = StorageManager.shared.totalFormattedSize
            countLabel.stringValue = "\(count) 项 · \(size)"
        } else {
            countLabel.stringValue = "空空如也"
        }
        countLabel.sizeToFit()
        countLabel.frame = NSRect(x: titleLabel.frame.maxX + 6, y: 10, width: countLabel.frame.width, height: 20)
        
        let hours = AutoCleanManager.shared.retentionHours
        if hours > 0 {
            autoCleanBadge.stringValue = "· \(hours)h 自动清理"
        } else {
            autoCleanBadge.stringValue = "· 手动清理"
        }
        autoCleanBadge.sizeToFit()
        autoCleanBadge.frame = NSRect(x: countLabel.frame.maxX + 6, y: 11, width: autoCleanBadge.frame.width, height: 18)
        
        clearAllButton.isHidden = count == 0
        zipButton.isHidden = count == 0
    }
    
    @objc private func closeClicked() {
        windowController?.hideShelf()
    }
    
    @objc private func clearAllClicked() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        StorageManager.shared.clearAll()
        shelfGridView.reload()
        updateItemCount()
    }
    
    @objc private func zipAllClicked() {
        let urls = StorageManager.shared.items.map { $0.url }
        guard !urls.isEmpty else { return }
        
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        let destination = StorageManager.shared.storageDirectory
        ZipHelper.createZip(of: urls, in: destination) { [weak self] zipURL in
            if zipURL != nil {
                StorageManager.shared.reloadItems()
                self?.shelfGridView.reload()
                self?.updateItemCount()
                NSSound(named: "Pop")?.play()
            }
        }
    }
    
    @objc private func openFolderClicked() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: StorageManager.shared.storageDirectory.path)
    }
    
    @objc private func showSettingsMenu() {
        let menu = NSMenu()
        let hours = AutoCleanManager.shared.retentionHours
        
        menu.addItem(NSMenuItem(title: "⏱️ 自动清理设置：", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        let options: [(String, Int)] = [
            ("1 小时后自动清理", 1),
            ("12 小时后自动清理", 12),
            ("24 小时后自动清理 (推荐)", 24),
            ("3 天后自动清理", 72),
            ("7 天后自动清理", 168),
            ("永不自动清理 (仅手动)", 0)
        ]
        
        for (title, h) in options {
            let item = NSMenuItem(title: title, action: #selector(changeAutoCleanHour(_:)), keyEquivalent: "")
            item.target = self
            item.tag = h
            item.state = (hours == h) ? .on : .off
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        let openItem = NSMenuItem(title: "📂 在访达中打开暂存目录", action: #selector(openFolderClicked), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        
        menu.popUp(positioning: nil, at: NSPoint(x: settingsButton.frame.minX, y: settingsButton.frame.minY), in: headerView)
    }
    
    @objc private func changeAutoCleanHour(_ sender: NSMenuItem) {
        AutoCleanManager.shared.retentionHours = sender.tag
        updateItemCount()
    }
    
    // MARK: - Drag & Drop Destination
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        windowController?.cancelRetractTimer()
        return .copy
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let pasteboard = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }
        
        var anyAdded = false
        for url in pasteboard {
            if StorageManager.shared.addFile(from: url) {
                anyAdded = true
            }
        }
        
        if anyAdded {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            NSSound(named: "Pop")?.play()
            shelfGridView.reload()
            updateItemCount()
        }
        return anyAdded
    }
    
    override func mouseEntered(with event: NSEvent) {
        windowController?.cancelRetractTimer()
    }
    
    override func mouseExited(with event: NSEvent) {
        windowController?.scheduleRetract()
    }
}

final class FloatingShelfWindow: NSPanel {
    let shelfView: FloatingShelfView
    var isShelfVisible = false
    private var retractTimer: Timer?
    
    init() {
        let width: CGFloat = 460
        let height: CGFloat = 175
        
        shelfView = FloatingShelfView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        shelfView.autoresizingMask = [.width, .height]
        shelfView.windowController = self
        contentView?.addSubview(shelfView)
        
        // Global Hotkey Option+D to toggle near cursor
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.option) && event.keyCode == 2 { // 'd'
                DispatchQueue.main.async {
                    self?.toggleShelf()
                }
            }
        }
        
        // Spacebar & ESC Key monitor
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isShelfVisible else { return event }
            if event.keyCode == 49 { // Spacebar
                if let targetURL = self.shelfView.shelfGridView.currentFocusedItemURL {
                    QuickLookCoordinator.shared.preview(url: targetURL)
                    return nil
                }
            } else if event.keyCode == 53 { // ESC
                self.hideShelf()
                return nil
            }
            return event
        }
        
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isShelfVisible else { return }
            if event.keyCode == 49 { // Spacebar
                if let targetURL = self.shelfView.shelfGridView.currentFocusedItemURL {
                    DispatchQueue.main.async {
                        QuickLookCoordinator.shared.preview(url: targetURL)
                    }
                }
            }
        }
    }
    
    func showNear(point: NSPoint) {
        cancelRetractTimer()
        AutoCleanManager.shared.performCleanup()
        shelfView.shelfGridView.reload()
        shelfView.updateItemCount()
        
        let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main!
        let visibleFrame = screen.visibleFrame
        
        let width = frame.width
        let height = frame.height
        
        var targetX = point.x + 18
        var targetY = point.y - (height / 2)
        
        // Ensure within screen bounds
        if targetX + width > visibleFrame.maxX {
            targetX = point.x - width - 18
        }
        if targetY < visibleFrame.minY {
            targetY = visibleFrame.minY + 12
        }
        if targetY + height > visibleFrame.maxY {
            targetY = visibleFrame.maxY - height - 12
        }
        
        setFrameOrigin(NSPoint(x: targetX, y: targetY))
        
        if !isShelfVisible {
            isShelfVisible = true
            alphaValue = 0.0
            orderFront(nil)
            
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            NSSound(named: "Pop")?.play()
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
                self.animator().alphaValue = 1.0
            }
        }
    }
    
    func hideShelf() {
        cancelRetractTimer()
        guard isShelfVisible else { return }
        
        if QLPreviewPanel.shared()?.isVisible == true {
            QLPreviewPanel.shared()?.orderOut(nil)
        }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.orderOut(nil)
            self.isShelfVisible = false
        })
    }
    
    func toggleShelf() {
        if isShelfVisible {
            hideShelf()
        } else {
            showNear(point: NSEvent.mouseLocation)
        }
    }
    
    func cancelRetractTimer() {
        retractTimer?.invalidate()
        retractTimer = nil
    }
    
    func scheduleRetract(delay: TimeInterval = 0.8) {
        cancelRetractTimer()
        if QLPreviewPanel.shared()?.isVisible == true {
            return
        }
        retractTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            if QLPreviewPanel.shared()?.isVisible == true { return }
            self?.hideShelf()
        }
    }
}
