import Cocoa
import QuickLookUI

final class QuickLookCoordinator: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookCoordinator()
    
    var currentPreviewURL: URL?
    
    func preview(url: URL) {
        currentPreviewURL = url
        if let panel = QLPreviewPanel.shared() {
            panel.dataSource = self
            panel.delegate = self
            panel.reloadData()
            panel.makeKeyAndOrderFront(nil)
        }
    }
    
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return currentPreviewURL != nil ? 1 : 0
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        return currentPreviewURL as? QLPreviewItem
    }
}
