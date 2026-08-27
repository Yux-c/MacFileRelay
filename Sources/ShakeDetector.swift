import Cocoa

final class ShakeDetector {
    static let shared = ShakeDetector()
    var onShake: ((NSPoint) -> Void)?
    
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
        
        samplePoints.append((x: point.x, time: now))
        samplePoints = samplePoints.filter { now - $0.time < 0.42 }
        
        guard samplePoints.count >= 3 else { return }
        
        let p1 = samplePoints[samplePoints.count - 2]
        let p2 = samplePoints[samplePoints.count - 1]
        let deltaX = p2.x - p1.x
        
        let threshold: CGFloat = 16.0
        if abs(deltaX) > threshold {
            let currentDir = deltaX > 0 ? 1 : -1
            if lastDirection != 0 && currentDir != lastDirection {
                directionReversals += 1
                lastReversalTime = now
                
                // 3 rapid left-right direction reversals trigger the shelf!
                if directionReversals >= 3 {
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
        
        if now - lastReversalTime > 0.42 {
            directionReversals = 0
        }
    }
}
