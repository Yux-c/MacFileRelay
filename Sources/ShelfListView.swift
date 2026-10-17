import Cocoa
import QuickLookUI

final class ShelfItemRowView: NSView, NSDraggingSource {
    static let height: CGFloat = 30
    
    let item: ShelvedItem
    let kind: FileKind
    var onDelete: (() -> Void)?
    var onHoverStateChanged: ((Bool) -> Void)?
    var onDragStarted: (() -> Void)?
    
    private let iconImageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let sizeLabel = NSTextField(labelWithString: "")
    private let deleteButton = NSButton()
    private let quickLookButton = NSButton()
    
    private var isHovered = false {
        didSet {
            needsDisplay = true
            // The action buttons take the place of the size while hovered.
            sizeLabel.isHidden = isHovered
            deleteButton.isHidden = !isHovered
            quickLookButton.isHidden = !isHovered
            onHoverStateChanged?(isHovered)
        }
    }
    
    override var isFlipped: Bool { true }
    
    init(item: ShelvedItem, width: CGFloat) {
        self.item = item
        self.kind = item.kind
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: Self.height))
        setupUI()
        registerForDraggedTypes(DropReceiver.draggedTypes)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        wantsLayer = true
        
        // File-type badge
        iconImageView.image = kind.badge(size: 20)
        iconImageView.frame = NSRect(x: 6, y: 5, width: 20, height: 20)
        addSubview(iconImageView)
        
        // Name; middle truncation keeps the extension visible.
        titleLabel.stringValue = item.originalName
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.frame = NSRect(x: 34, y: 7, width: bounds.width - 34 - 72, height: 16)
        addSubview(titleLabel)
        
        sizeLabel.stringValue = item.formattedSize
        sizeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        sizeLabel.textColor = .secondaryLabelColor
        sizeLabel.alignment = .right
        sizeLabel.frame = NSRect(x: bounds.width - 70, y: 7, width: 62, height: 16)
        addSubview(sizeLabel)
        
        // QuickLook preview button
        configureHoverButton(quickLookButton, symbol: "eye.fill", pointSize: 8, action: #selector(quickLookClicked))
        quickLookButton.frame = NSRect(x: bounds.width - 46, y: 7, width: 16, height: 16)
        
        // Delete button
        configureHoverButton(deleteButton, symbol: "xmark", pointSize: 7, action: #selector(deleteClicked))
        deleteButton.frame = NSRect(x: bounds.width - 25, y: 7, width: 16, height: 16)
        
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
    }
    
    private func configureHoverButton(_ button: NSButton, symbol: String, pointSize: CGFloat, action: Selector) {
        button.bezelStyle = .circular
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.45).cgColor
        button.layer?.cornerRadius = 8
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: pointSize, weight: .bold))
        button.contentTintColor = .white
        button.target = self
        button.action = action
        button.isHidden = true
        addSubview(button)
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
        if isHovered {
            NSColor.controlAccentColor.withAlphaComponent(0.15).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6).fill()
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            NSWorkspace.shared.open(item.url)
        }
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return DropReceiver.operation(for: sender)
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return DropReceiver.receive(sender)
    }
    
    override func mouseDragged(with event: NSEvent) {
        onDragStarted?()
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        NSSound(named: "Pop")?.play()
        
        // The drag image is the real file icon, which apps like Finder and WeChat expect.
        let dragItem = NSDraggingItem(pasteboardWriter: item.url as NSURL)
        dragItem.setDraggingFrame(NSRect(x: 0, y: 0, width: 32, height: 32), contents: item.icon)
        
        beginDraggingSession(with: [dragItem], event: event, source: self)
    }
    
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return context == .outsideApplication ? .copy : .generic
    }
}

final class ShelfListView: NSView {
    private var rowViews: [ShelfItemRowView] = []
    private let emptyContainer = NSView()
    private let emptyIcon = NSImageView()
    private let emptyTitle = NSTextField(labelWithString: "")
    
    static let verticalPadding: CGFloat = 4
    
    var hoveredItem: ShelvedItem?
    
    var currentFocusedItemURL: URL? {
        hoveredItem?.url ?? StorageManager.shared.items.first?.url
    }
    
    /// Height the list needs to show every row without scrolling.
    static func contentHeight(forItemCount count: Int) -> CGFloat {
        CGFloat(count) * ShelfItemRowView.height + verticalPadding * 2
    }
    
    override var isFlipped: Bool { true }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        registerForDraggedTypes(DropReceiver.draggedTypes)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        wantsLayer = true
        
        emptyContainer.wantsLayer = true
        emptyContainer.layer?.cornerRadius = 12
        emptyContainer.layer?.borderWidth = 1.2
        emptyContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
        addSubview(emptyContainer)
        
        emptyIcon.image = NSImage(systemSymbolName: "arrow.down.doc.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 22, weight: .medium))
        emptyIcon.contentTintColor = .controlAccentColor
        emptyContainer.addSubview(emptyIcon)
        
        emptyTitle.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
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
        rowViews.forEach { $0.removeFromSuperview() }
        rowViews.removeAll()
        
        let items = StorageManager.shared.items
        // Drop a hover reference to a file that no longer exists (deleted row, item limit, ...).
        if let hovered = hoveredItem, !items.contains(where: { $0.url == hovered.url }) {
            hoveredItem = nil
            HoverPreviewController.shared.hide()
        }
        
        let visibleSize = enclosingScrollView?.contentSize ?? bounds.size
        emptyContainer.isHidden = !items.isEmpty
        
        if items.isEmpty {
            frame = NSRect(origin: .zero, size: visibleSize)
            layoutEmptyState()
            return
        }
        
        let rowWidth = visibleSize.width - 4
        var currentY = Self.verticalPadding
        for item in items {
            let row = ShelfItemRowView(item: item, width: rowWidth)
            row.frame.origin = NSPoint(x: 2, y: currentY)
            
            row.onDelete = {
                StorageManager.shared.removeFile(item)
            }
            
            // Compare by URL: item IDs are regenerated on every reload.
            row.onHoverStateChanged = { [weak self, weak row] isHovered in
                guard let self = self, let row = row else { return }
                if isHovered {
                    self.hoveredItem = item
                    HoverPreviewController.shared.pointerEntered(row: row)
                } else if self.hoveredItem?.url == item.url {
                    self.hoveredItem = nil
                    HoverPreviewController.shared.pointerExited()
                }
            }
            
            row.onDragStarted = {
                HoverPreviewController.shared.hide()
            }
            
            addSubview(row)
            rowViews.append(row)
            currentY += ShelfItemRowView.height
        }
        
        frame = NSRect(x: 0, y: 0, width: visibleSize.width,
                       height: max(Self.contentHeight(forItemCount: items.count), visibleSize.height))
    }
    
    /// Keeps the list at least as tall as the visible area, e.g. while the window resizes.
    func fitToVisibleArea() {
        guard let visibleSize = enclosingScrollView?.contentSize else { return }
        let count = StorageManager.shared.items.count
        let height = count == 0 ? visibleSize.height : max(Self.contentHeight(forItemCount: count), visibleSize.height)
        setFrameSize(NSSize(width: visibleSize.width, height: height))
        if count == 0 {
            layoutEmptyState()
        }
    }
    
    private func layoutEmptyState() {
        let size = bounds.size
        let containerFrame = NSRect(x: 4, y: 4, width: size.width - 8, height: size.height - 8)
        emptyContainer.frame = containerFrame
        
        let contentHeight: CGFloat = 28 + 8 + 16
        let startY = (containerFrame.height - contentHeight) / 2
        // emptyContainer is not flipped: y grows upwards.
        emptyTitle.frame = NSRect(x: 0, y: startY, width: containerFrame.width, height: 16)
        emptyIcon.frame = NSRect(x: (containerFrame.width - 28) / 2, y: startY + 16 + 8, width: 28, height: 28)
    }
    
    override func layout() {
        super.layout()
        if StorageManager.shared.items.isEmpty {
            layoutEmptyState()
        }
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return DropReceiver.operation(for: sender)
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return DropReceiver.receive(sender)
    }
}
