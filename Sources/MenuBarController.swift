import Cocoa

final class MenuBarController {
    private var statusItem: NSStatusItem!
    weak var shelfWindow: FloatingShelfWindow?
    
    init(shelfWindow: FloatingShelfWindow) {
        self.shelfWindow = shelfWindow
        setupStatusItem()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: "NotchDrop")?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .medium))
            button.target = self
            button.action = #selector(statusBarClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
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
        
        let toggleItem = NSMenuItem(title: "📦 展开/收起暂存托盘 (⌥D)", action: #selector(toggleShelf), keyEquivalent: "d")
        toggleItem.keyEquivalentModifierMask = .option
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let hours = AutoCleanManager.shared.retentionHours
        let autoCleanSubmenu = NSMenu()
        let options: [(String, Int)] = [
            ("1 小时后自动清理", 1),
            ("12 小时后自动清理", 12),
            ("24 小时后自动清理 (推荐)", 24),
            ("3 天后自动清理", 72),
            ("7 天后自动清理", 168),
            ("永不自动清理 (仅手动)", 0)
        ]
        for (title, h) in options {
            let item = NSMenuItem(title: title, action: #selector(changeAutoCleanHour(_:)), keyEquivalent: "")
            item.target = self
            item.tag = h
            item.state = (hours == h) ? .on : .off
            autoCleanSubmenu.addItem(item)
        }
        
        let autoCleanItem = NSMenuItem(title: "⏱️ 自动清理设置", action: nil, keyEquivalent: "")
        autoCleanItem.submenu = autoCleanSubmenu
        menu.addItem(autoCleanItem)
        
        let clearItem = NSMenuItem(title: "🗑️ 清空所有暂存文件", action: #selector(clearAll), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)
        
        let openFolderItem = NSMenuItem(title: "📂 在访达中打开暂存目录", action: #selector(openFolder), keyEquivalent: "")
        openFolderItem.target = self
        menu.addItem(openFolderItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "❌ 退出 NotchDrop", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
    
    @objc private func toggleShelf() {
        shelfWindow?.toggleShelf()
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
