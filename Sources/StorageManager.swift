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
    
    var kind: FileKind {
        FileKind(url: url)
    }
}

/// Something dropped on the shelf that should become a file in storage.
enum ImportSource {
    /// An existing file; `move` is used for temporary files such as received file promises.
    case file(URL, move: Bool)
    /// Raw content (image data, web link) written to a new file with the given name.
    case data(Data, filename: String)
}

final class StorageManager {
    static let shared = StorageManager()
    
    static let maxItemsRange = 5...100
    static let defaultMaxItems = 20
    
    private let fileManager = FileManager.default
    private let maxItemsKey = "MacFileRelay_MaxItems"
    let storageDirectory: URL
    
    /// Serial queue for all writes to storage, so large copies never block the UI.
    private let importQueue = DispatchQueue(label: "com.macfilerelay.import", qos: .userInitiated)
    
    private(set) var items: [ShelvedItem] = []
    var onItemsChanged: (([ShelvedItem]) -> Void)?
    var onImportStateChanged: ((Bool) -> Void)?
    
    private var pendingImports = 0 {
        didSet { onImportStateChanged?(pendingImports > 0) }
    }
    
    /// Maximum number of files kept; the oldest ones are moved to the Trash beyond this.
    var maxItems: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: maxItemsKey)
            return val == 0 ? Self.defaultMaxItems : min(max(val, Self.maxItemsRange.lowerBound), Self.maxItemsRange.upperBound)
        }
        set {
            let clamped = min(max(newValue, Self.maxItemsRange.lowerBound), Self.maxItemsRange.upperBound)
            UserDefaults.standard.set(clamped, forKey: maxItemsKey)
            importQueue.async {
                let trashed = self.trimToLimit(clamped)
                if trashed > 0 {
                    DispatchQueue.main.async { self.reloadItems() }
                }
            }
        }
    }
    
    var totalFormattedSize: String {
        let total = items.reduce(0) { $0 + $1.fileSize }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }
    
    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDirectory = appSupport.appendingPathComponent("MacFileRelay/ShelvedFiles", isDirectory: true)
        
        // Migrate old storage if existing
        for oldName in ["ShakeDrop/ShelvedFiles", "NotchDrop/ShelvedFiles"] {
            let oldStorage = appSupport.appendingPathComponent(oldName, isDirectory: true)
            if fileManager.fileExists(atPath: oldStorage.path) {
                try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
                if let oldFiles = try? fileManager.contentsOfDirectory(at: oldStorage, includingPropertiesForKeys: nil) {
                    for file in oldFiles {
                        let dest = storageDirectory.appendingPathComponent(file.lastPathComponent)
                        try? fileManager.moveItem(at: file, to: dest)
                    }
                }
                try? fileManager.removeItem(at: oldStorage)
            }
        }
        
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
    
    /// Writes the sources into storage on a background queue, trims storage to `maxItems`,
    /// then reloads on the main thread. `completion` receives the number of items added.
    func importItems(_ sources: [ImportSource], completion: ((Int) -> Void)? = nil) {
        guard !sources.isEmpty else {
            completion?(0)
            return
        }
        pendingImports += 1
        let limit = maxItems
        importQueue.async {
            let added = sources.filter { self.write($0) }.count
            if added > 0 {
                self.trimToLimit(limit)
            }
            DispatchQueue.main.async {
                self.pendingImports -= 1
                if added > 0 {
                    self.reloadItems()
                }
                completion?(added)
            }
        }
    }
    
    /// Runs on `importQueue`.
    private func write(_ source: ImportSource) -> Bool {
        do {
            let destinationURL: URL
            switch source {
            case .file(let sourceURL, let move):
                destinationURL = uniqueDestinationURL(for: sourceURL.lastPathComponent)
                if move {
                    try fileManager.moveItem(at: sourceURL, to: destinationURL)
                } else {
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                }
            case .data(let data, let filename):
                destinationURL = uniqueDestinationURL(for: filename)
                try data.write(to: destinationURL, options: .withoutOverwriting)
            }
            
            let now = Date()
            try? fileManager.setAttributes([
                .creationDate: now,
                .modificationDate: now
            ], ofItemAtPath: destinationURL.path)
            return true
        } catch {
            print("Failed to import into MacFileRelay storage: \(error)")
            return false
        }
    }
    
    /// Moves the oldest files to the Trash until at most `limit` remain. Runs on `importQueue`.
    @discardableResult
    private func trimToLimit(_ limit: Int) -> Int {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .creationDateKey]
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: storageDirectory, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        ), fileURLs.count > limit else { return 0 }
        
        func addedDate(_ url: URL) -> Date {
            let values = try? url.resourceValues(forKeys: Set(keys))
            return values?.contentModificationDate ?? values?.creationDate ?? .distantPast
        }
        let oldestFirst = fileURLs.sorted { addedDate($0) < addedDate($1) }
        var trashed = 0
        for url in oldestFirst.prefix(fileURLs.count - limit) {
            do {
                try fileManager.trashItem(at: url, resultingItemURL: nil)
                trashed += 1
            } catch {
                print("MacFileRelay: Could not trash \(url.lastPathComponent): \(error)")
            }
        }
        return trashed
    }
    
    func removeFile(_ item: ShelvedItem) {
        try? fileManager.trashItem(at: item.url, resultingItemURL: nil)
        reloadItems()
    }
    
    func clearAll() {
        for url in items.map({ $0.url }) {
            try? fileManager.trashItem(at: url, resultingItemURL: nil)
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
