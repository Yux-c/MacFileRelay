import Cocoa

final class MenuBarController {
    private var statusItem: NSStatusItem!
    weak var shelfWindow: FloatingShelfWindow?
    
    init(shelfWindow: FloatingShelfWindow) {
        self.shelfWindow = shelfWindow
        setupStatusItem()
        NotificationCenter.default.addObserver(self, selector: #selector(updateMenu), name: .languageDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateMenu), name: .shortcutDidChange, object: nil)
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: "MacFileRelay")?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .medium))
            button.target = self
            button.action = #selector(statusBarClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    @objc private func updateMenu() {
        // Updated on demand when clicked
    }
    
    @objc private func statusBarClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showMenu()
        } else {
            shelfWindow?.toggleShelf()
        }
    }
    
    private func showMenu() {
        let menu = NSMenu()
        let shortcutStr = HotkeyManager.shared.currentShortcut.displayString
        
        let toggleItem = NSMenuItem(title: String(format: L("menu_toggle"), shortcutStr), action: #selector(toggleShelf), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        let settingsItem = NSMenuItem(title: L("menu_settings"), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let hours = AutoCleanManager.shared.retentionHours
        let autoCleanSubmenu = NSMenu()
        let options: [(String, Int)] = [
            (L("autoclean_1h"), 1),
            (L("autoclean_12h"), 12),
            (L("autoclean_24h"), 24),
            (L("autoclean_3d"), 72),
            (L("autoclean_7d"), 168),
            (L("autoclean_never"), 0)
        ]
        for (title, h) in options {
            let item = NSMenuItem(title: title, action: #selector(changeAutoCleanHour(_:)), keyEquivalent: "")
            item.target = self
            item.tag = h
            item.state = (hours == h) ? .on : .off
            autoCleanSubmenu.addItem(item)
        }
        
        let autoCleanItem = NSMenuItem(title: L("menu_autoclean"), action: nil, keyEquivalent: "")
        autoCleanItem.submenu = autoCleanSubmenu
        menu.addItem(autoCleanItem)
        
        let clearItem = NSMenuItem(title: L("menu_clear"), action: #selector(clearAll), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)
        
        let openFolderItem = NSMenuItem(title: L("menu_open_folder"), action: #selector(openFolder), keyEquivalent: "")
        openFolderItem.target = self
        menu.addItem(openFolderItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: L("menu_quit"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
    
    @objc private func toggleShelf() {
        shelfWindow?.toggleShelf()
    }
    
    @objc private func openSettings() {
        SettingsWindowController.shared.showSettings()
    }
    
    @objc private func changeAutoCleanHour(_ sender: NSMenuItem) {
        AutoCleanManager.shared.retentionHours = sender.tag
        shelfWindow?.shelfView.updateItemCount()
    }
    
    @objc private func clearAll() {
        StorageManager.shared.clearAll()
        shelfWindow?.shelfView.shelfGridView.reload()
        shelfWindow?.shelfView.updateItemCount()
    }
    
    @objc private func openFolder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: StorageManager.shared.storageDirectory.path)
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
