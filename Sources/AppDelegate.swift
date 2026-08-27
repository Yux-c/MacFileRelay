import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var shelfWindow: FloatingShelfWindow!
    private var menuBarController: MenuBarController!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Initialize Floating Shelf Window
        shelfWindow = FloatingShelfWindow()
        menuBarController = MenuBarController(shelfWindow: shelfWindow)
        
        // Start mouse shake detector (Dropover-style: shake cursor to pop shelf right beside mouse!)
        ShakeDetector.shared.onShake = { [weak self] mousePoint in
            self?.shelfWindow.showNear(point: mousePoint)
        }
        ShakeDetector.shared.start()
        
        // Initial auto-clean
        AutoCleanManager.shared.performCleanup()
        
        print("NotchDrop (Shake to Drop) initialized successfully.")
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        ShakeDetector.shared.stop()
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
