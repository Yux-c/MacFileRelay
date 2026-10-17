import Cocoa
import UniformTypeIdentifiers

/// Broad file categories, each drawn as a small tinted symbol badge in the list.
enum FileKind {
    case image, pdf, video, audio, archive, spreadsheet, presentation, document, code, text, link, folder, app, other
    
    init(url: URL) {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .contentTypeKey])
        let type = values?.contentType ?? UTType(filenameExtension: url.pathExtension)
        
        if let type = type, type.conforms(to: .application) || type.conforms(to: .applicationBundle) {
            self = .app
            return
        }
        if values?.isDirectory == true && values?.isPackage != true {
            self = .folder
            return
        }
        guard let type = type else {
            self = .other
            return
        }
        
        let ext = url.pathExtension.lowercased()
        if type.conforms(to: .image) { self = .image }
        else if type.conforms(to: .pdf) { self = .pdf }
        else if type.conforms(to: .movie) || type.conforms(to: .video) { self = .video }
        else if type.conforms(to: .audio) { self = .audio }
        else if type.conforms(to: .archive) || ["zip", "rar", "7z", "gz", "tar", "dmg"].contains(ext) { self = .archive }
        else if type.conforms(to: .spreadsheet) || ["xls", "xlsx", "numbers", "csv", "tsv"].contains(ext) { self = .spreadsheet }
        else if type.conforms(to: .presentation) || ["ppt", "pptx", "key"].contains(ext) { self = .presentation }
        else if type.conforms(to: .internetLocation) || ["webloc", "url"].contains(ext) { self = .link }
        else if type.conforms(to: .sourceCode) || type.conforms(to: .json) || type.conforms(to: .xml)
                    || ["swift", "py", "js", "ts", "html", "css", "sh", "yml", "yaml"].contains(ext) { self = .code }
        else if ["doc", "docx", "pages", "rtf", "odt"].contains(ext) || type.conforms(to: .rtf) { self = .document }
        else if type.conforms(to: .plainText) || type.conforms(to: .text) { self = .text }
        else { self = .other }
    }
    
    var symbolName: String {
        switch self {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .video: return "film"
        case .audio: return "music.note"
        case .archive: return "doc.zipper"
        case .spreadsheet: return "tablecells"
        case .presentation: return "play.rectangle"
        case .document: return "doc.text"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .text: return "doc.plaintext"
        case .link: return "link"
        case .folder: return "folder.fill"
        case .app: return "app.dashed"
        case .other: return "doc"
        }
    }
    
    var tint: NSColor {
        switch self {
        case .image: return .systemTeal
        case .pdf: return .systemRed
        case .video: return .systemPurple
        case .audio: return .systemPink
        case .archive: return .systemBrown
        case .spreadsheet: return .systemGreen
        case .presentation: return .systemOrange
        case .document, .link, .folder: return .systemBlue
        case .code: return .systemIndigo
        case .text, .app, .other: return .systemGray
        }
    }
    
    private static var badgeCache: [String: NSImage] = [:]
    
    /// A rounded square tinted with the category colour, with the symbol on top.
    func badge(size: CGFloat) -> NSImage {
        let key = "\(symbolName)|\(Int(size))"
        if let cached = Self.badgeCache[key] { return cached }
        
        let tint = self.tint
        let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: size * 0.5, weight: .semibold))
        // Drawn on demand, so the colours follow light/dark appearance changes.
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            tint.withAlphaComponent(0.22).setFill()
            NSBezierPath(roundedRect: rect, xRadius: size * 0.24, yRadius: size * 0.24).fill()
            if let symbol = symbol {
                let tinted = NSImage(size: symbol.size, flipped: false) { symbolRect in
                    symbol.draw(in: symbolRect)
                    tint.set()
                    symbolRect.fill(using: .sourceAtop)
                    return true
                }
                let origin = NSPoint(x: rect.midX - symbol.size.width / 2, y: rect.midY - symbol.size.height / 2)
                tinted.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1)
            }
            return true
        }
        Self.badgeCache[key] = image
        return image
    }
}
