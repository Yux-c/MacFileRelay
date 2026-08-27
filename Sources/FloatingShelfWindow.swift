import Cocoa
import QuartzCore
import QuickLookUI

final class HorizontalScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        // Convert vertical mouse scroll wheel (deltaY) into horizontal scrolling
        if event.deltaX == 0 && event.deltaY != 0 {
            let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : (event.deltaY * 20.0)
            let currentOrigin = documentVisibleRect.origin
            var newX = currentOrigin.x - delta
            
            if let docView = documentView {
                let maxX = max(0, docView.bounds.width - bounds.width)
                newX = max(0, min(newX, maxX))
            }
            
            contentView.scroll(to: NSPoint(x: newX, y: currentOrigin.y))
            reflectScrolledClipView(contentView)
            return
        }
        super.scrollWheel(with: event)
    }
}

final class DraggableHeaderView: NSView {
    override var mouseDownCanMoveWindow: Bool {
        return true
    }
    
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let hit = hitTest(location)
        if hit is NSButton || hit?.superview is NSButton {
            super.mouseDown(with: event)
            return
        }
        window?.performDrag(with: event)
    }
}

final class FloatingShelfView: NSView {
    weak var windowController: FloatingShelfWindow?
    
    let backgroundEffect = NSVisualEffectView()
    let headerView = DraggableHeaderView()
    let titleLabel = NSTextField(labelWithString: "")
    let countLabel = NSTextField(labelWithString: "")
    let autoCleanBadge = NSTextField(labelWithString: "")
    
    let openFolderButton = NSButton()
    let clearAllButton = NSButton()
    let settingsButton = NSButton()
    let closeButton = NSButton()
    
    let scrollView = HorizontalScrollView()
    let shelfGridView = ShelfGridView()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupViews()
        registerForDraggedTypes([.fileURL, .URL, .png, .tiff])
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateLocalizedTexts), name: .languageDidChange, object: nil)
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
        
        // Header - Draggable Area
        headerView.frame = NSRect(x: 0, y: bounds.height - 38, width: bounds.width, height: 38)
        headerView.autoresizingMask = [.width, .minYMargin]
        backgroundEffect.addSubview(headerView)
        
        // Left text items with perfect font baseline alignment
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.isBordered = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .labelColor
        headerView.addSubview(titleLabel)
        
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.isBordered = false
        countLabel.drawsBackground = false
        countLabel.isEditable = false
        countLabel.isSelectable = false
        countLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        countLabel.textColor = .secondaryLabelColor
        headerView.addSubview(countLabel)
        
        autoCleanBadge.translatesAutoresizingMaskIntoConstraints = false
        autoCleanBadge.isBordered = false
        autoCleanBadge.drawsBackground = false
        autoCleanBadge.isEditable = false
        autoCleanBadge.isSelectable = false
        autoCleanBadge.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        autoCleanBadge.textColor = .tertiaryLabelColor
        headerView.addSubview(autoCleanBadge)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            countLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            countLabel.firstBaselineAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor),
            
            autoCleanBadge.leadingAnchor.constraint(equalTo: countLabel.trailingAnchor, constant: 6),
            autoCleanBadge.firstBaselineAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor)
        ])
        
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
        settingsButton.action = #selector(showSettingsClicked)
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
        
        // Clear All Button
        clearAllButton.bezelStyle = .texturedRounded
        clearAllButton.isBordered = false
        clearAllButton.image = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: "Clear All")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 11, weight: .medium))
        clearAllButton.contentTintColor = NSColor.secondaryLabelColor
        clearAllButton.frame = NSRect(x: bounds.width - 106, y: 8, width: 22, height: 22)
        clearAllButton.autoresizingMask = [.minXMargin]
        clearAllButton.target = self
        clearAllButton.action = #selector(clearAllClicked)
        headerView.addSubview(clearAllButton)
        
        // ScrollView - Extended height with ample top/bottom margin & mouse wheel support
        scrollView.frame = NSRect(x: 6, y: 6, width: bounds.width - 12, height: bounds.height - 46)
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
        
        updateLocalizedTexts()
        
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
    }
    
    @objc func updateLocalizedTexts() {
        titleLabel.stringValue = L("shelf_title")
        
        closeButton.toolTip = L("btn_close")
        settingsButton.toolTip = L("btn_settings")
        openFolderButton.toolTip = L("btn_open_folder")
        clearAllButton.toolTip = L("btn_clear")
        
        updateItemCount()
        shelfGridView.updateEmptyStateText()
    }
    
    func updateItemCount() {
        let count = StorageManager.shared.items.count
        
        if count > 0 {
            let size = StorageManager.shared.totalFormattedSize
            countLabel.stringValue = String(format: L("items_count"), count, size)
        } else {
            countLabel.stringValue = L("empty_state")
        }
        
        let hours = AutoCleanManager.shared.retentionHours
        if hours > 0 {
            autoCleanBadge.stringValue = String(format: L("auto_clean_badge"), hours)
        } else {
            autoCleanBadge.stringValue = L("manual_clean_badge")
        }
        
        clearAllButton.isHidden = count == 0
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
    
    @objc private func openFolderClicked() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: StorageManager.shared.storageDirectory.path)
    }
    
    @objc private func showSettingsClicked() {
        SettingsWindowController.shared.showSettings()
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
        let height: CGFloat = 185
        
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
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        shelfView.autoresizingMask = [.width, .height]
        shelfView.windowController = self
        contentView?.addSubview(shelfView)
        
        // Listen to Hotkey Trigger
        HotkeyManager.shared.onShortcutTriggered = { [weak self] in
            self?.toggleShelf()
        }
        
        // Spacebar & ESC Key monitor
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isShelfVisible else { return event }
            let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
            
            if flags.isEmpty {
                if event.keyCode == 49 { // Spacebar
                    if let targetURL = self.shelfView.shelfGridView.currentFocusedItemURL {
                        QuickLookCoordinator.shared.preview(url: targetURL)
                        return nil
                    }
                } else if event.keyCode == 53 { // ESC
                    self.hideShelf()
                    return nil
                }
            }
            return event
        }
        
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isShelfVisible else { return }
            let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
            
            if flags.isEmpty {
                if event.keyCode == 49 { // Spacebar
                    if let targetURL = self.shelfView.shelfGridView.currentFocusedItemURL {
                        DispatchQueue.main.async {
                            QuickLookCoordinator.shared.preview(url: targetURL)
                        }
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
            context.duration = 0.18
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
