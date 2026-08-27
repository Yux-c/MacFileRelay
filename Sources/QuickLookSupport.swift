import Cocoa
import QuickLookUI

final class QuickLookItem: NSObject, QLPreviewItem {
    let previewItemURL: URL?
    let previewItemTitle: String?
    
    init(url: URL) {
        self.previewItemURL = url
        self.previewItemTitle = url.lastPathComponent
        super.init()
    }
}

final class QuickLookCoordinator: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookCoordinator()
    
    private var currentItem: QuickLookItem?
    
    func preview(url: URL) {
        guard let panel = QLPreviewPanel.shared() else { return }
        
        if panel.isVisible && currentItem?.previewItemURL == url {
            panel.orderOut(nil)
            currentItem = nil
            return
        }
        
        currentItem = QuickLookItem(url: url)
        panel.dataSource = self
        panel.delegate = self
        panel.reloadData()
        
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
    
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return currentItem != nil ? 1 : 0
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)? {
        return currentItem
    }
}
