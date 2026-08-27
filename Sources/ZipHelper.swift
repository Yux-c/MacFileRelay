import Cocoa

final class ZipHelper {
    static func createZip(of urls: [URL], in destinationDirectory: URL, completion: @escaping (URL?) -> Void) {
        guard !urls.isEmpty else {
            completion(nil)
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let zipName = "ShakeDrop_Archive_\(timestamp).zip"
        let zipURL = destinationDirectory.appendingPathComponent(zipName)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        
        var arguments = ["-r", "-j", zipURL.path]
        for url in urls {
            arguments.append(url.path)
        }
        process.arguments = arguments
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
                process.waitUntilExit()
                DispatchQueue.main.async {
                    if process.terminationStatus == 0 {
                        completion(zipURL)
                    } else {
                        completion(nil)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}
