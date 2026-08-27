import Cocoa

final class AutoCleanManager {
    static let shared = AutoCleanManager()
    
    private let userDefaultsKey = "ShakeDrop_AutoCleanHours"
    private var timer: Timer?
    
    var retentionHours: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: userDefaultsKey)
            return val == 0 && !UserDefaults.standard.bool(forKey: "ShakeDrop_AutoCleanConfigured") ? 24 : val
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userDefaultsKey)
            UserDefaults.standard.set(true, forKey: "ShakeDrop_AutoCleanConfigured")
            performCleanup()
        }
    }
    
    private init() {
        startTimer()
        performCleanup()
    }
    
    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            self?.performCleanup()
        }
    }
    
    func performCleanup() {
        let hours = retentionHours
        guard hours > 0 else { return }
        
        let cutoffDate = Date().addingTimeInterval(-Double(hours * 3600))
        let items = StorageManager.shared.items
        
        var expiredURLs: [URL] = []
        for item in items {
            if item.addedDate < cutoffDate {
                expiredURLs.append(item.url)
            }
        }
        
        if !expiredURLs.isEmpty {
            for url in expiredURLs {
                NSWorkspace.shared.recycle([url], completionHandler: nil)
            }
            StorageManager.shared.reloadItems()
            print("ShakeDrop: Cleaned up \(expiredURLs.count) expired items (retention: \(hours)h).")
        }
    }
}
