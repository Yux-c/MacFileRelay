import Cocoa

enum ShakeSensitivity: Int, CaseIterable {
    case high = 1
    case normal = 2
    case low = 3
    case veryLow = 4
    
    var threshold: CGFloat {
        switch self {
        case .high: return 10.0
        case .normal: return 16.0
        case .low: return 26.0
        case .veryLow: return 36.0
        }
    }
    
    var requiredReversals: Int {
        switch self {
        case .high: return 2
        case .normal: return 3
        case .low: return 3
        case .veryLow: return 4
        }
    }
    
    var timeWindow: TimeInterval {
        switch self {
        case .high: return 0.38
        case .normal: return 0.42
        case .low: return 0.50
        case .veryLow: return 0.55
        }
    }
}

final class ShakeDetector {
    static let shared = ShakeDetector()
    var onShake: ((NSPoint) -> Void)?
    
    private let sensitivityKey = "MacFileRelay_ShakeSensitivity"
    
    var sensitivity: ShakeSensitivity {
        get {
            let val = UserDefaults.standard.integer(forKey: sensitivityKey)
            return ShakeSensitivity(rawValue: val) ?? .normal
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
        if UserDefaults.standard.bool(forKey: "MacFileRelay_DisableShake") {
            return
        }
        
        let now = Date().timeIntervalSinceReferenceDate
        // 0.8s cooldown after triggering to prevent repeated popups
        if now - lastTriggerTime < 0.8 { return }
        
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
