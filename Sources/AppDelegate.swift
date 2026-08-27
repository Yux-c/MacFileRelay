import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var shelfWindow: FloatingShelfWindow!
    private var menuBarController: MenuBarController!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        shelfWindow = FloatingShelfWindow()
        menuBarController = MenuBarController(shelfWindow: shelfWindow)
        
        // Shake detector: Shake once to open, shake again to close immediately!
        ShakeDetector.shared.onShake = { [weak self] mousePoint in
            guard let self = self else { return }
            if self.shelfWindow.isShelfVisible {
                self.shelfWindow.hideShelf()
            } else {
                self.shelfWindow.showNear(point: mousePoint)
            }
        }
        ShakeDetector.shared.start()
        
        // Initial auto-clean
        AutoCleanManager.shared.performCleanup()
        
        print("MacFileRelay (Mac 文件中转站) initialized successfully.")
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        ShakeDetector.shared.stop()
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
