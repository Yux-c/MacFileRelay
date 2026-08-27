import Cocoa

struct ShelvedItem: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let originalName: String
    let addedDate: Date
    let fileSize: Int64
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
}

final class StorageManager {
    static let shared = StorageManager()
    
    private let fileManager = FileManager.default
    let storageDirectory: URL
    
    private(set) var items: [ShelvedItem] = []
    var onItemsChanged: (([ShelvedItem]) -> Void)?
    
    var totalFormattedSize: String {
        let total = items.reduce(0) { $0 + $1.fileSize }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }
    
    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDirectory = appSupport.appendingPathComponent("NotchDrop/ShelvedFiles", isDirectory: true)
        
        try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        reloadItems()
    }
    
    func reloadItems() {
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey, .fileSizeKey, .nameKey],
            options: [.skipsHiddenFiles]
        ) else {
            items = []
            onItemsChanged?([])
            return
        }
        
        var loadedItems: [ShelvedItem] = []
        for url in fileURLs {
            let resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey, .fileSizeKey])
            // Use content modification date (which we update to Date() when shelved into NotchDrop)
            let addedDate = resourceValues?.contentModificationDate ?? resourceValues?.creationDate ?? Date()
            let fileSize = Int64(resourceValues?.fileSize ?? 0)
            
            loadedItems.append(ShelvedItem(
                id: UUID(),
                url: url,
                originalName: url.lastPathComponent,
                addedDate: addedDate,
                fileSize: fileSize
            ))
        }
        
        // Sort by newest first
        items = loadedItems.sorted { $0.addedDate > $1.addedDate }
        onItemsChanged?(items)
    }
    
    @discardableResult
    func addFile(from sourceURL: URL) -> Bool {
        let destinationURL = uniqueDestinationURL(for: sourceURL.lastPathComponent)
        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            
            // Crucial: Set creation & modification date of the shelved copy to NOW
            // This ensures auto-cleanup timer counts from the moment it enters NotchDrop, NOT when the song was created years ago!
            let now = Date()
            try? fileManager.setAttributes([
                .creationDate: now,
                .modificationDate: now
            ], ofItemAtPath: destinationURL.path)
            
            reloadItems()
            return true
        } catch {
            print("Failed to copy file to NotchDrop storage: \(error)")
            return false
        }
    }
    
    func removeFile(_ item: ShelvedItem) {
        try? fileManager.removeItem(at: item.url)
        reloadItems()
    }
    
    func clearAll() {
        let urls = items.map { $0.url }
        for url in urls {
            try? fileManager.removeItem(at: url)
        }
        reloadItems()
    }
    
    private func uniqueDestinationURL(for filename: String) -> URL {
        var destination = storageDirectory.appendingPathComponent(filename)
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        
        var counter = 1
        while fileManager.fileExists(atPath: destination.path) {
            let newName = ext.isEmpty ? "\(name) \(counter)" : "\(name) \(counter).\(ext)"
            destination = storageDirectory.appendingPathComponent(newName)
            counter += 1
        }
        return destination
    }
}
