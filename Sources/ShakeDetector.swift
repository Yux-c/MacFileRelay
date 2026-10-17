import Cocoa

enum ShakeSensitivity: Int, CaseIterable {
    case veryLow = 1
    case low = 2
    case normal = 3  // Default middle!
    case high = 4
    case veryHigh = 5
    
    var threshold: CGFloat {
        switch self {
        case .veryLow: return 36.0
        case .low: return 24.0
        case .normal: return 16.0
        case .high: return 11.0
        case .veryHigh: return 7.0
        }
    }
    
    var requiredReversals: Int {
        switch self {
        case .veryLow: return 4
        case .low: return 3
        case .normal: return 3
        case .high: return 2
        case .veryHigh: return 2
        }
    }
    
    var timeWindow: TimeInterval {
        switch self {
        case .veryLow: return 0.55
        case .low: return 0.50
        case .normal: return 0.45
        case .high: return 0.40
        case .veryHigh: return 0.35
        }
    }
}

final class ShakeDetector {
    static let shared = ShakeDetector()
    var onShake: ((NSPoint) -> Void)?
    
    /// Whether a shake without a file drag may trigger (shake-to-close while the shelf is open).
    var allowsShakeWithoutDrag: () -> Bool = { false }
    
    private let sensitivityKey = "MacFileRelay_ShakeSensitivity"
    private let enableShakeKey = "MacFileRelay_EnableShake"
    private let enableShakeCloseKey = "MacFileRelay_EnableShakeClose"
    
    // Settings are cached: the mouse monitor runs on every pointer event.
    
    // Default: Enabled (true)
    var isShakeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isShakeEnabled, forKey: enableShakeKey)
            if isShakeEnabled {
                start()
            } else {
                stop()
            }
        }
    }
    
    // Default: Enabled (true)
    var isShakeCloseEnabled: Bool {
        didSet { UserDefaults.standard.set(isShakeCloseEnabled, forKey: enableShakeCloseKey) }
    }
    
    var sensitivity: ShakeSensitivity {
        didSet { UserDefaults.standard.set(sensitivity.rawValue, forKey: sensitivityKey) }
    }
    
    private var samplePoints: [(x: CGFloat, time: TimeInterval)] = []
    private var lastDirection: Int = 0
    private var directionReversals: Int = 0
    private var lastReversalTime: TimeInterval = 0
    private var lastTriggerTime: TimeInterval = 0
    
    /// Drag pasteboard change count at the last mouse-down. It changes once a real
    /// drag session (files, images, links) starts, unlike moving windows or selecting text.
    private var dragChangeCountAtMouseDown = NSPasteboard(name: .drag).changeCount
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    private init() {
        let defaults = UserDefaults.standard
        isShakeEnabled = defaults.object(forKey: enableShakeKey) as? Bool ?? true
        isShakeCloseEnabled = defaults.object(forKey: enableShakeCloseKey) as? Bool ?? true
        let val = defaults.integer(forKey: sensitivityKey)
        sensitivity = ShakeSensitivity(rawValue: val) ?? .normal
    }
    
    func start() {
        stop()
        guard isShakeEnabled else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .mouseMoved]
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
            return event
        }
    }
    
    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    private func handle(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            dragChangeCountAtMouseDown = NSPasteboard(name: .drag).changeCount
            resetTracking()
        case .leftMouseDragged:
            handleMovement(point: NSEvent.mouseLocation, isMouseDragging: true)
        default:
            // Plain pointer movement only matters for shake-to-close.
            guard allowsShakeWithoutDrag() else { return }
            handleMovement(point: NSEvent.mouseLocation, isMouseDragging: false)
        }
    }
    
    private func resetTracking() {
        samplePoints.removeAll()
        directionReversals = 0
        lastDirection = 0
    }
    
    private func handleMovement(point: NSPoint, isMouseDragging: Bool) {
        let now = Date().timeIntervalSinceReferenceDate
        // 0.35s snappy cooldown after triggering so shake-again immediately closes!
        if now - lastTriggerTime < 0.35 { return }
        
        let config = sensitivity
        
        samplePoints.append((x: point.x, time: now))
        samplePoints.removeAll { now - $0.time >= config.timeWindow }
        
        guard samplePoints.count >= 3 else { return }
        
        let p1 = samplePoints[samplePoints.count - 2]
        let p2 = samplePoints[samplePoints.count - 1]
        let deltaX = p2.x - p1.x
        
        if abs(deltaX) > config.threshold {
            let currentDir = deltaX > 0 ? 1 : -1
            if lastDirection != 0 && currentDir != lastDirection {
                directionReversals += 1
                lastReversalTime = now
                
                if directionReversals >= config.requiredReversals {
                    // Only a drag carrying content counts, unless shaking without a drag is allowed.
                    let isContentDrag = isMouseDragging && NSPasteboard(name: .drag).changeCount != dragChangeCountAtMouseDown
                    guard isContentDrag || allowsShakeWithoutDrag() else {
                        resetTracking()
                        return
                    }
                    
                    lastTriggerTime = now
                    resetTracking()
                    
                    DispatchQueue.main.async { [weak self] in
                        self?.onShake?(point)
                    }
                    return
                }
            }
            lastDirection = currentDir
        }
        
        if now - lastReversalTime > config.timeWindow {
            directionReversals = 0
        }
    }
}
