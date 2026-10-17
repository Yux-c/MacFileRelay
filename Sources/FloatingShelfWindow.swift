import Cocoa
import QuartzCore
import QuickLookUI

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
    let importSpinner = NSProgressIndicator()
    
    let openFolderButton = NSButton()
    let clearAllButton = NSButton()
    let settingsButton = NSButton()
    let closeButton = NSButton()
    
    let scrollView = NSScrollView()
    let shelfListView = ShelfListView()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupViews()
        registerForDraggedTypes(DropReceiver.draggedTypes)
        
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
        
        importSpinner.translatesAutoresizingMaskIntoConstraints = false
        importSpinner.style = .spinning
        importSpinner.controlSize = .small
        importSpinner.isDisplayedWhenStopped = false
        headerView.addSubview(importSpinner)
        
        NSLayoutConstraint.activate([
            importSpinner.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            importSpinner.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            importSpinner.widthAnchor.constraint(equalToConstant: 12),
            importSpinner.heightAnchor.constraint(equalToConstant: 12),
            
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
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
        
        // Vertical file list below the header
        scrollView.frame = NSRect(x: 6, y: 6, width: bounds.width - 12, height: bounds.height - FloatingShelfWindow.chromeHeight)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        
        shelfListView.frame = NSRect(x: 0, y: 0, width: scrollView.bounds.width, height: scrollView.bounds.height)
        StorageManager.shared.onItemsChanged = { [weak self] _ in
            self?.windowController?.fitHeightToContent()
            self?.shelfListView.reload()
            self?.updateItemCount()
        }
        // Large copies run in the background; show a spinner while they are in flight.
        StorageManager.shared.onImportStateChanged = { [weak self] isImporting in
            if isImporting {
                self?.importSpinner.startAnimation(nil)
            } else {
                self?.importSpinner.stopAnimation(nil)
            }
        }
        scrollView.documentView = shelfListView
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
        shelfListView.updateEmptyStateText()
    }
    
    func updateItemCount() {
        let count = StorageManager.shared.items.count
        
        // The header stays clean; count and size are available on hover.
        if count > 0 {
            titleLabel.toolTip = String(format: L("items_count"), count, StorageManager.shared.maxItems,
                                        StorageManager.shared.totalFormattedSize)
        } else {
            titleLabel.toolTip = nil
        }
        
        clearAllButton.isHidden = count == 0
    }
    
    @objc private func closeClicked() {
        windowController?.hideShelf()
    }
    
    @objc private func clearAllClicked() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        if FloatingShelfView.confirmClearAll() {
            StorageManager.shared.clearAll()
        }
    }
    
    /// Asks before moving every shelved file to the Trash.
    static func confirmClearAll() -> Bool {
        let count = StorageManager.shared.items.count
        guard count > 0 else { return false }
        
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L("clear_confirm_title")
        alert.informativeText = String(format: L("clear_confirm_message"), count)
        alert.addButton(withTitle: L("clear_confirm_ok"))
        alert.addButton(withTitle: L("btn_cancel"))
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }
    
    @objc private func openFolderClicked() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: StorageManager.shared.storageDirectory.path)
    }
    
    @objc private func showSettingsClicked() {
        SettingsWindowController.shared.showSettings()
    }
    
    // MARK: - Drag & Drop Destination
    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        shelfListView.fitToVisibleArea()
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        windowController?.cancelRetractTimer()
        HoverPreviewController.shared.hide()
        return DropReceiver.operation(for: sender)
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return DropReceiver.operation(for: sender)
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return DropReceiver.receive(sender)
    }
    
    override func mouseEntered(with event: NSEvent) {
        windowController?.cancelRetractTimer()
    }
    
    override func mouseExited(with event: NSEvent) {
        windowController?.scheduleRetract()
    }
}

final class FloatingShelfWindow: NSPanel {
    static let width: CGFloat = 280
    /// Height of the empty shelf, which shows the drop hint.
    static let emptyHeight: CGFloat = 150
    static let minHeight: CGFloat = 110
    static let maxHeight: CGFloat = 400
    /// Header plus bottom inset around the list.
    static let chromeHeight: CGFloat = 44
    
    let shelfView: FloatingShelfView
    var isShelfVisible = false
    private var retractTimer: Timer?
    
    init() {
        let width = Self.width
        let height = Self.emptyHeight
        
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
                    if let targetURL = self.shelfView.shelfListView.currentFocusedItemURL {
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
        
        // Global events reach us while another app is frontmost (the panel never activates the app),
        // so only react while the pointer is over a row; otherwise typing a space elsewhere would
        // pop up QuickLook and steal focus.
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isShelfVisible else { return }
            let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
            
            if flags.isEmpty {
                if event.keyCode == 49 { // Spacebar
                    if let targetURL = self.shelfView.shelfListView.hoveredItem?.url {
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
        StorageManager.shared.reloadItems()
        
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
        
        // Flip the state before the fade-out so a show request during the animation is honoured.
        isShelfVisible = false
        shelfView.shelfListView.hoveredItem = nil
        HoverPreviewController.shared.hide()
        
        if QLPreviewPanel.shared()?.isVisible == true {
            QLPreviewPanel.shared()?.orderOut(nil)
        }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            // The shelf may have been shown again while fading out.
            guard !self.isShelfVisible else { return }
            self.orderOut(nil)
        })
    }
    
    /// Height that fits the current files: compact when empty, growing with the list up to `maxHeight`.
    var preferredHeight: CGFloat {
        let count = StorageManager.shared.items.count
        guard count > 0 else { return Self.emptyHeight }
        let listHeight = ShelfListView.contentHeight(forItemCount: count)
        return min(max(Self.chromeHeight + listHeight, Self.minHeight), Self.maxHeight)
    }
    
    /// Resizes to `preferredHeight`, keeping the header in place (or growing upwards at the bottom of the screen).
    func fitHeightToContent() {
        let newHeight = preferredHeight
        guard abs(frame.height - newHeight) > 0.5 else { return }
        
        var newFrame = frame
        newFrame.origin.y = frame.maxY - newHeight
        newFrame.size.height = newHeight
        if let visibleFrame = screen?.visibleFrame, newFrame.minY < visibleFrame.minY + 12 {
            newFrame.origin.y = visibleFrame.minY + 12
        }
        
        if isShelfVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.animator().setFrame(newFrame, display: true)
            }
        } else {
            setFrame(newFrame, display: false)
        }
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
