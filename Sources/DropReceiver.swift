import Cocoa

/// Turns whatever is dropped on the shelf into storage imports: files, file promises
/// (Photos, Mail attachments, browser images), raw image data and web links.
enum DropReceiver {
    static let draggedTypes: [NSPasteboard.PasteboardType] =
        [.fileURL, .URL, .png, .tiff] + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
    
    private static let promiseQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()
    
    /// The operation to show while dragging over the shelf: `.copy` only for content we can store.
    static func operation(for info: NSDraggingInfo) -> NSDragOperation {
        // Dragging a row back onto the shelf would only duplicate it.
        if info.draggingSource is ShelfItemRowView { return [] }
        
        let pasteboard = info.draggingPasteboard
        let canRead = pasteboard.canReadObject(forClasses: [NSURL.self, NSFilePromiseReceiver.self], options: nil)
            || pasteboard.availableType(from: [.png, .tiff]) != nil
        return canRead ? .copy : []
    }
    
    /// Starts importing the drop. Returns false if nothing usable was on the pasteboard.
    @discardableResult
    static func receive(_ info: NSDraggingInfo) -> Bool {
        guard operation(for: info) == .copy else { return false }
        let pasteboard = info.draggingPasteboard
        
        // 1. Real files from Finder and most apps.
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !fileURLs.isEmpty {
            StorageManager.shared.importItems(fileURLs.map { .file($0, move: false) }, completion: playFeedback)
            return true
        }
        
        // 2. File promises: the file is written by the source app on demand.
        if let receivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver],
           !receivers.isEmpty {
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("MacFileRelay-Promises-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            for receiver in receivers {
                receiver.receivePromisedFiles(atDestination: destination, options: [:], operationQueue: promiseQueue) { url, error in
                    if let error = error {
                        print("MacFileRelay: Failed to receive promised file: \(error)")
                        return
                    }
                    DispatchQueue.main.async {
                        StorageManager.shared.importItems([.file(url, move: true)], completion: playFeedback)
                    }
                }
            }
            return true
        }
        
        // 3. Raw image data (e.g. images dragged out of some editors).
        if let png = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff).flatMap(pngData(fromTIFF:)) {
            StorageManager.shared.importItems([.data(png, filename: "\(imageBaseName()).png")], completion: playFeedback)
            return true
        }
        
        // 4. Web links become .webloc files that open in the browser.
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            let sources: [ImportSource] = urls.compactMap { url in
                guard url.scheme == "http" || url.scheme == "https",
                      let data = try? PropertyListSerialization.data(fromPropertyList: ["URL": url.absoluteString],
                                                                      format: .xml, options: 0) else { return nil }
                return .data(data, filename: "\(weblocName(for: url)).webloc")
            }
            if !sources.isEmpty {
                StorageManager.shared.importItems(sources, completion: playFeedback)
                return true
            }
        }
        return false
    }
    
    private static func playFeedback(addedCount: Int) {
        guard addedCount > 0 else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        NSSound(named: "Pop")?.play()
    }
    
    private static func pngData(fromTIFF tiff: Data) -> Data? {
        NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
    }
    
    private static func imageBaseName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return "Image \(formatter.string(from: Date()))"
    }
    
    private static func weblocName(for url: URL) -> String {
        let host = url.host ?? "Link"
        let last = url.lastPathComponent
        let name = (last.isEmpty || last == "/") ? host : "\(host) - \(last)"
        // Keep it a valid, reasonably short filename.
        return String(name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-").prefix(80))
    }
}
