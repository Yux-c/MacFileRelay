import Cocoa
import QuickLookThumbnailing

/// Caches QuickLook thumbnails per file and size; falls back to the file icon when none exists.
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    
    private let cache = NSCache<NSString, NSImage>()
    
    /// Calls `completion` on the main thread, only when a real thumbnail is available.
    func thumbnail(for url: URL, size: CGFloat, completion: @escaping (NSImage) -> Void) {
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        let key = "\(url.path)|\(modified?.timeIntervalSince1970 ?? 0)|\(Int(size))" as NSString
        if let image = cache.object(forKey: key) {
            completion(image)
            return
        }
        
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: size, height: size),
                                                   scale: scale, representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            guard let image = representation?.nsImage else { return }
            DispatchQueue.main.async {
                self?.cache.setObject(image, forKey: key)
                completion(image)
            }
        }
    }
}

/// Floating panel next to the shelf showing a large image thumbnail and the file name.
final class HoverPreviewPanel: NSPanel {
    static let size = NSSize(width: 240, height: 270)
    
    private let imageView = NSImageView()
    private let nameLabel = NSTextField(wrappingLabelWithString: "")
    private(set) var currentURL: URL?
    
    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        // Purely informational: never takes the pointer, so the shelf keeps its hover state.
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: Self.size))
        background.autoresizingMask = [.width, .height]
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 14
        background.layer?.cornerCurve = .continuous
        background.layer?.masksToBounds = true
        background.layer?.borderWidth = 1
        background.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        contentView = background
        
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.frame = NSRect(x: 16, y: 58, width: Self.size.width - 32, height: Self.size.height - 74)
        background.addSubview(imageView)
        
        nameLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        nameLabel.textColor = .labelColor
        nameLabel.alignment = .center
        nameLabel.maximumNumberOfLines = 2
        nameLabel.lineBreakMode = .byCharWrapping
        nameLabel.cell?.truncatesLastVisibleLine = true
        nameLabel.frame = NSRect(x: 12, y: 14, width: Self.size.width - 24, height: 34)
        background.addSubview(nameLabel)
    }
    
    func configure(with item: ShelvedItem) {
        guard currentURL != item.url else { return }
        currentURL = item.url
        nameLabel.stringValue = item.originalName
        
        let icon = item.icon
        icon.size = imageView.bounds.size
        imageView.image = icon
        ThumbnailCache.shared.thumbnail(for: item.url, size: imageView.bounds.width) { [weak self] image in
            guard self?.currentURL == item.url else { return }
            self?.imageView.image = image
        }
    }
    
    func clear() {
        currentURL = nil
    }
}

/// Shows an image preview after the pointer rests on an image row, and switches instantly between rows once visible.
final class HoverPreviewController {
    static let shared = HoverPreviewController()
    
    static let showDelay: TimeInterval = 1.0
    /// Grace period on leaving a row, so moving to the neighbouring row switches instead of flickering.
    private static let hideDelay: TimeInterval = 0.15
    
    private let enabledKey = "MacFileRelay_HoverPreview"
    private lazy var panel = HoverPreviewPanel()
    private var showTimer: Timer?
    private var hideTimer: Timer?
    private weak var currentRow: ShelfItemRowView?
    
    // Default: Enabled (true)
    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            if !newValue { hide() }
        }
    }
    
    var isVisible: Bool { panel.isVisible }
    
    func pointerEntered(row: ShelfItemRowView) {
        hideTimer?.invalidate()
        currentRow = row
        // Only images get a preview; other files are fully described by their row.
        guard row.kind == .image else {
            hide()
            return
        }
        // No preview while a mouse button is down: that is a drag in or out of the shelf.
        guard isEnabled, NSEvent.pressedMouseButtons == 0 else { return }
        
        if panel.isVisible {
            show(for: row)
            return
        }
        showTimer?.invalidate()
        showTimer = Timer.scheduledTimer(withTimeInterval: Self.showDelay, repeats: false) { [weak self] _ in
            guard let self = self, let row = self.currentRow, NSEvent.pressedMouseButtons == 0 else { return }
            self.show(for: row)
        }
    }
    
    func pointerExited() {
        showTimer?.invalidate()
        currentRow = nil
        guard panel.isVisible else { return }
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: Self.hideDelay, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }
    
    func hide() {
        showTimer?.invalidate()
        hideTimer?.invalidate()
        currentRow = nil
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        panel.clear()
    }
    
    private func show(for row: ShelfItemRowView) {
        guard let shelf = row.window, shelf.isVisible, shelf.alphaValue > 0.5 else { return }
        panel.configure(with: row.item)
        panel.setFrameOrigin(Self.origin(for: Self.screenRect(of: row), shelfFrame: shelf.frame,
                                         visibleFrame: (shelf.screen ?? NSScreen.main)?.visibleFrame ?? shelf.frame))
        panel.orderFront(nil)
    }
    
    private static func screenRect(of view: NSView) -> NSRect {
        guard let window = view.window else { return .zero }
        return window.convertToScreen(view.convert(view.bounds, to: nil))
    }
    
    /// Beside the shelf on the side with more room, aligned with the row; above or below if neither side fits.
    static func origin(for rowRect: NSRect, shelfFrame: NSRect, visibleFrame: NSRect) -> NSPoint {
        let size = HoverPreviewPanel.size
        let gap: CGFloat = 8
        let margin: CGFloat = 8
        func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat { min(max(value, low), max(low, high)) }
        
        let rightRoom = visibleFrame.maxX - shelfFrame.maxX
        let leftRoom = shelfFrame.minX - visibleFrame.minX
        let alignedY = clamp(rowRect.midY - size.height / 2, visibleFrame.minY + margin, visibleFrame.maxY - size.height - margin)
        
        if rightRoom >= size.width + gap && rightRoom >= leftRoom {
            return NSPoint(x: shelfFrame.maxX + gap, y: alignedY)
        }
        if leftRoom >= size.width + gap {
            return NSPoint(x: shelfFrame.minX - gap - size.width, y: alignedY)
        }
        
        let x = clamp(shelfFrame.midX - size.width / 2, visibleFrame.minX + margin, visibleFrame.maxX - size.width - margin)
        if visibleFrame.maxY - shelfFrame.maxY >= size.height + gap {
            return NSPoint(x: x, y: shelfFrame.maxY + gap)
        }
        return NSPoint(x: x, y: max(visibleFrame.minY + margin, shelfFrame.minY - gap - size.height))
    }
}
