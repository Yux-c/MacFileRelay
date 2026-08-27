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
    
    private let sensitivityKey = "MacFileRelay_ShakeSensitivity"
    private let enableShakeKey = "MacFileRelay_EnableShake"
    private let enableShakeCloseKey = "MacFileRelay_EnableShakeClose"
    
    // Default: Enabled (true)
    var isShakeEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: enableShakeKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: enableShakeKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: enableShakeKey)
        }
    }
    
    // Default: Enabled (true)
    var isShakeCloseEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: enableShakeCloseKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: enableShakeCloseKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: enableShakeCloseKey)
        }
    }
    
    var sensitivity: ShakeSensitivity {
        get {
            let val = UserDefaults.standard.integer(forKey: sensitivityKey)
            return (val >= 1 && val <= 5) ? (ShakeSensitivity(rawValue: val) ?? .normal) : .normal
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: sensitivityKey)
        }
    }
    
    private var samplePoints: [(x: CGFloat, time: TimeInterval)] = []
    private var lastDirection: Int = 0
    private var directionReversals: Int = 0
    private var lastReversalTime: TimeInterval = 0
    private var lastTriggerTime: TimeInterval = 0
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    func start() {
        stop()
        let mask: NSEvent.EventTypeMask = [.leftMouseDragged, .mouseMoved]
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            self?.handleMovement(point: NSEvent.mouseLocation)
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleMovement(point: NSEvent.mouseLocation)
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
    
    private func handleMovement(point: NSPoint) {
        guard isShakeEnabled else { return }
        
        let now = Date().timeIntervalSinceReferenceDate
        // 0.35s snappy cooldown after triggering so shake-again immediately closes!
        if now - lastTriggerTime < 0.35 { return }
        
        let config = sensitivity
        
        samplePoints.append((x: point.x, time: now))
        samplePoints = samplePoints.filter { now - $0.time < config.timeWindow }
        
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
                    lastTriggerTime = now
                    directionReversals = 0
                    samplePoints.removeAll()
                    lastDirection = 0
                    
                    DispatchQueue.main.async { [weak self] in
                        self?.onShake?(point)
                    }
                }
            }
            lastDirection = currentDir
        }
        
        if now - lastReversalTime > config.timeWindow {
            directionReversals = 0
        }
    }
}
