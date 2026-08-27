import Cocoa
import QuickLookUI
import QuickLookThumbnailing

final class ShelfItemCardView: NSView, NSDraggingSource {
    let item: ShelvedItem
    var onDelete: (() -> Void)?
    var onCardClicked: ((ShelfItemCardView, NSEvent.ModifierFlags) -> Void)?
    var onBeginDrag: ((ShelfItemCardView, NSEvent) -> Void)?
    var onFileDropped: (([URL]) -> Void)?
    var onHoverStateChanged: ((Bool) -> Void)?
    
    private let iconImageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let sizeLabel = NSTextField(labelWithString: "")
    private let deleteButton = NSButton()
    private let quickLookButton = NSButton()
    
    var isSelected = false {
        didSet {
            needsDisplay = true
        }
    }
    
    private var isHovered = false {
        didSet {
            needsDisplay = true
            deleteButton.isHidden = !isHovered
            quickLookButton.isHidden = !isHovered
            onHoverStateChanged?(isHovered)
        }
    }
    
    init(item: ShelvedItem) {
        self.item = item
        super.init(frame: NSRect(x: 0, y: 0, width: 96, height: 116))
        setupUI()
        loadThumbnail()
        registerForDraggedTypes([.fileURL, .URL, .png, .tiff])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 12
        
        // Icon / Thumbnail
        iconImageView.image = item.icon
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconImageView.frame = NSRect(x: 24, y: 48, width: 48, height: 48)
        iconImageView.wantsLayer = true
        iconImageView.layer?.cornerRadius = 6
        iconImageView.layer?.masksToBounds = true
        addSubview(iconImageView)
        
        // Title
        titleLabel.stringValue = item.originalName
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.frame = NSRect(x: 4, y: 24, width: 88, height: 16)
        addSubview(titleLabel)
        
        // Size
        sizeLabel.stringValue = item.formattedSize
        sizeLabel.font = NSFont.systemFont(ofSize: 9, weight: .regular)
        sizeLabel.textColor = .secondaryLabelColor
        sizeLabel.alignment = .center
        sizeLabel.frame = NSRect(x: 4, y: 8, width: 88, height: 14)
        addSubview(sizeLabel)
        
        // QuickLook preview button
        quickLookButton.bezelStyle = .circular
        quickLookButton.isBordered = false
        quickLookButton.wantsLayer = true
        quickLookButton.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        quickLookButton.layer?.cornerRadius = 9
        quickLookButton.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "QuickLook")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 9, weight: .semibold))
        quickLookButton.contentTintColor = .white
        quickLookButton.frame = NSRect(x: 6, y: 90, width: 18, height: 18)
        quickLookButton.target = self
        quickLookButton.action = #selector(quickLookClicked)
        quickLookButton.isHidden = true
        addSubview(quickLookButton)
        
        // Delete button
        deleteButton.bezelStyle = .circular
        deleteButton.isBordered = false
        deleteButton.wantsLayer = true
        deleteButton.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        deleteButton.layer?.cornerRadius = 9
        deleteButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Delete")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 8, weight: .bold))
        deleteButton.contentTintColor = .white
        deleteButton.frame = NSRect(x: 72, y: 90, width: 18, height: 18)
        deleteButton.target = self
        deleteButton.action = #selector(deleteClicked)
        deleteButton.isHidden = true
        addSubview(deleteButton)
        
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
    }
    
    private func loadThumbnail() {
        let size = CGSize(width: 96, height: 96)
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let request = QLThumbnailGenerator.Request(fileAt: item.url, size: size, scale: scale, representationTypes: .thumbnail)
        
        QLThumbnailGenerator.shared.generateRepresentations(for: request) { [weak self] representation, type, error in
            if let thumbnail = representation?.nsImage {
                DispatchQueue.main.async {
                    self?.iconImageView.image = thumbnail
                }
            }
        }
    }
    
    @objc private func deleteClicked() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        onDelete?()
    }
    
    @objc private func quickLookClicked() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        QuickLookCoordinator.shared.preview(url: item.url)
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if isSelected {
            // Selected highlight - 2px inset so stroke is fully visible with complete rounded corners
            NSColor.controlAccentColor.withAlphaComponent(0.22).setFill()
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 10, yRadius: 10)
            path.fill()
            
            NSColor.controlAccentColor.setStroke()
            path.lineWidth = 1.8
            path.stroke()
        } else if isHovered {
            // Hover highlight
            NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 10, yRadius: 10)
            path.fill()
            
            NSColor.controlAccentColor.withAlphaComponent(0.35).setStroke()
            path.lineWidth = 1.0
            path.stroke()
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            NSWorkspace.shared.open(item.url)
        } else {
            onCardClicked?(self, event.modifierFlags)
        }
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let pasteboard = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }
        onFileDropped?(pasteboard)
        return true
    }
    
    override func mouseDragged(with event: NSEvent) {
        onBeginDrag?(self, event)
    }
    
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return context == .outsideApplication ? .copy : .generic
    }
}

final class ShelfGridView: NSView {
    private var itemViews: [ShelfItemCardView] = []
    private let emptyContainer = NSView()
    private let emptyIcon = NSImageView()
    private let emptyTitle = NSTextField(labelWithString: "")
    
    var hoveredItem: ShelvedItem?
    private(set) var selectedItemIDs: Set<UUID> = []
    private var lastSelectedItemID: UUID?
    
    var currentFocusedItemURL: URL? {
        if let hovered = hoveredItem {
            return hovered.url
        }
        if let firstSelectedID = selectedItemIDs.first,
           let item = StorageManager.shared.items.first(where: { $0.id == firstSelectedID }) {
            return item.url
        }
        return StorageManager.shared.items.first?.url
    }
    
    var onItemsUpdated: (() -> Void)?
    var onSelectionChanged: (([ShelvedItem]) -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        registerForDraggedTypes([.fileURL, .URL, .png, .tiff])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        wantsLayer = true
        
        emptyContainer.wantsLayer = true
        emptyContainer.layer?.cornerRadius = 14
        emptyContainer.layer?.borderWidth = 1.2
        emptyContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
        addSubview(emptyContainer)
        
        emptyIcon.image = NSImage(systemSymbolName: "arrow.down.doc.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 28, weight: .medium))
        emptyIcon.contentTintColor = .controlAccentColor
        emptyContainer.addSubview(emptyIcon)
        
        emptyTitle.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        emptyTitle.textColor = .labelColor
        emptyTitle.alignment = .center
        emptyContainer.addSubview(emptyTitle)
        
        updateEmptyStateText()
        reload()
    }
    
    func updateEmptyStateText() {
        emptyTitle.stringValue = L("empty_title")
    }
    
    func reload() {
        itemViews.forEach { $0.removeFromSuperview() }
        itemViews.removeAll()
        
        let items = StorageManager.shared.items
        let isEmpty = items.isEmpty
        
        // Clean up stale selection IDs
        let currentIDs = Set(items.map { $0.id })
        selectedItemIDs = selectedItemIDs.intersection(currentIDs)
        
        emptyContainer.isHidden = !isEmpty
        
        let parentHeight = superview?.bounds.height ?? 136
        
        if isEmpty {
            let containerW = superview?.bounds.width ?? 440
            frame = NSRect(x: 0, y: 0, width: max(containerW, 440), height: parentHeight)
            layoutEmptyState()
            return
        }
        
        let itemWidth: CGFloat = 96
        let itemHeight: CGFloat = 116
        let spacing: CGFloat = 8
        var currentX: CGFloat = 12
        
        for item in items {
            let card = ShelfItemCardView(item: item)
            card.frame = NSRect(x: currentX, y: 8, width: itemWidth, height: itemHeight)
            card.isSelected = selectedItemIDs.contains(item.id)
            
            card.onDelete = { [weak self] in
                guard let self = self else { return }
                if self.selectedItemIDs.contains(item.id) && self.selectedItemIDs.count > 1 {
                    // Batch delete all selected items!
                    let toDelete = items.filter { self.selectedItemIDs.contains($0.id) }
                    for del in toDelete {
                        StorageManager.shared.removeFile(del)
                    }
                } else {
                    StorageManager.shared.removeFile(item)
                }
                self.selectedItemIDs.remove(item.id)
                self.reload()
                self.onItemsUpdated?()
            }
            
            card.onCardClicked = { [weak self] clickedCard, flags in
                self?.handleCardClicked(clickedCard, flags: flags)
            }
            
            card.onBeginDrag = { [weak self] draggedCard, event in
                self?.startDragging(from: draggedCard, event: event)
            }
            
            card.onHoverStateChanged = { [weak self] isHovered in
                if isHovered {
                    self?.hoveredItem = item
                } else if self?.hoveredItem == item {
                    self?.hoveredItem = nil
                }
            }
            
            card.onFileDropped = { [weak self] urls in
                self?.handleDrop(urls: urls)
            }
            
            addSubview(card)
            itemViews.append(card)
            currentX += itemWidth + spacing
        }
        
        let minWidth = superview?.bounds.width ?? 440
        let totalWidth = max(currentX + 12, minWidth)
        frame = NSRect(x: 0, y: 0, width: totalWidth, height: parentHeight)
    }
    
    private func handleCardClicked(_ card: ShelfItemCardView, flags: NSEvent.ModifierFlags) {
        let items = StorageManager.shared.items
        guard let clickedIndex = items.firstIndex(where: { $0.id == card.item.id }) else { return }
        
        if flags.contains(.shift) {
            // Shift + Click: Range selection
            if let lastID = lastSelectedItemID,
               let lastIndex = items.firstIndex(where: { $0.id == lastID }) {
                let start = min(lastIndex, clickedIndex)
                let end = max(lastIndex, clickedIndex)
                for idx in start...end {
                    selectedItemIDs.insert(items[idx].id)
                }
            } else {
                selectedItemIDs.insert(card.item.id)
            }
            lastSelectedItemID = card.item.id
        } else if flags.contains(.command) {
            // Command + Click: Toggle individual selection
            if selectedItemIDs.contains(card.item.id) {
                selectedItemIDs.remove(card.item.id)
            } else {
                selectedItemIDs.insert(card.item.id)
            }
            lastSelectedItemID = card.item.id
        } else {
            // Normal Click: Single select
            selectedItemIDs = [card.item.id]
            lastSelectedItemID = card.item.id
        }
        
        updateCardSelectionStates()
        notifySelectionChanged()
    }
    
    private func updateCardSelectionStates() {
        for card in itemViews {
            card.isSelected = selectedItemIDs.contains(card.item.id)
        }
    }
    
    private func notifySelectionChanged() {
        let items = StorageManager.shared.items
        let selected = items.filter { selectedItemIDs.contains($0.id) }
        onSelectionChanged?(selected)
    }
    
    private func startDragging(from card: ShelfItemCardView, event: NSEvent) {
        let items = StorageManager.shared.items
        
        // If the dragged card isn't part of the current selection, select it solely
        if !selectedItemIDs.contains(card.item.id) {
            selectedItemIDs = [card.item.id]
            lastSelectedItemID = card.item.id
            updateCardSelectionStates()
            notifySelectionChanged()
        }
        
        let itemsToDrag = items.filter { selectedItemIDs.contains($0.id) }
        guard !itemsToDrag.isEmpty else { return }
        
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        NSSound(named: "Pop")?.play()
        
        var draggingItems: [NSDraggingItem] = []
        for (index, item) in itemsToDrag.enumerated() {
            let dragItem = NSDraggingItem(pasteboardWriter: item.url as NSURL)
            let offset = CGFloat(min(index, 3) * 5)
            let dragBounds = NSRect(x: offset, y: offset, width: 64, height: 64)
            dragItem.setDraggingFrame(dragBounds, contents: item.icon)
            draggingItems.append(dragItem)
        }
        
        card.beginDraggingSession(with: draggingItems, event: event, source: card)
    }
    
    private func handleDrop(urls: [URL]) {
        var anyAdded = false
        for url in urls {
            if StorageManager.shared.addFile(from: url) {
                anyAdded = true
            }
        }
        if anyAdded {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            NSSound(named: "Pop")?.play()
            reload()
            onItemsUpdated?()
        }
    }
    
    private func layoutEmptyState() {
        let parentWidth = superview?.bounds.width ?? bounds.width
        let parentHeight = superview?.bounds.height ?? bounds.height
        
        let containerWidth = parentWidth - 20
        let containerHeight = parentHeight - 10
        emptyContainer.frame = NSRect(x: 10, y: 5, width: containerWidth, height: containerHeight)
        
        // Icon (32px) + Gap (10px) + Title (18px) = 60px total content height
        let totalContentHeight: CGFloat = 60
        let startY = (containerHeight - totalContentHeight) / 2
        
        emptyTitle.frame = NSRect(x: 0, y: startY, width: containerWidth, height: 18)
        emptyIcon.frame = NSRect(x: (containerWidth - 32) / 2, y: startY + 18 + 10, width: 32, height: 32)
    }
    
    override func layout() {
        super.layout()
        if StorageManager.shared.items.isEmpty {
            layoutEmptyState()
        }
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let pasteboard = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }
        handleDrop(urls: pasteboard)
        return true
    }
}
