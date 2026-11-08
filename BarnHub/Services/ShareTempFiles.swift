import Foundation

/// Files written so the share sheet has a URL to hand out. Each share gets its
/// own UUID folder under `tmp/BarnHubShare`, so two documents with the same
/// title never overwrite each other, and the folder is removed when the sheet
/// closes. Anything left behind (a crash, a force quit) is purged at launch.
enum ShareTempFiles {
    static let rootFolderName = "BarnHubShare"

    static var rootDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(rootFolderName, isDirectory: true)
    }

    /// Writes `data` to a fresh share folder and returns the file's URL.
    static func write(_ data: Data, fileName: String, fileExtension: String) throws -> URL {
        let folder = try makeShareFolder()
        let url = folder.appendingPathComponent(sanitizedFileName(fileName, fileExtension: fileExtension))
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            discardShareFolder(folder)
            throw error
        }
        return url
    }

    /// Creates an empty `tmp/BarnHubShare/<UUID>/` folder for callers that write
    /// their own files (the CSV export). Share a file or subfolder placed
    /// directly inside it so `cleanUp(_:)` removes the whole share folder.
    static func makeShareFolder() throws -> URL {
        let folder = rootDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Deletes a share folder that was never shown in a share sheet (the write
    /// failed or was cancelled), on every platform.
    static func discardShareFolder(_ folder: URL) {
        guard folder.deletingLastPathComponent().standardizedFileURL == rootDirectory.standardizedFileURL else { return }
        try? FileManager.default.removeItem(at: folder)
    }

    /// Removes the share folder that holds `url`. Call when the share sheet is
    /// dismissed. On native macOS the sheet offers Reveal in Finder, so the file
    /// is kept until the next launch instead.
    static func cleanUp(_ url: URL?) {
        #if os(macOS)
        return
        #else
        guard let url else { return }
        let folder = url.deletingLastPathComponent()
        guard folder.deletingLastPathComponent().standardizedFileURL == rootDirectory.standardizedFileURL else { return }
        try? FileManager.default.removeItem(at: folder)
        #endif
    }

    /// Deletes leftovers from earlier runs. Safe to call from every window's
    /// launch task: only the first call in a process purges, so a second iPad or
    /// Mac window can't delete a file another window is sharing.
    static func purgeLeftoversAtLaunch() {
        _ = purgeOnce
    }

    private static let purgeOnce: Void = purgeAll()

    /// Deletes every share folder.
    static func purgeAll() {
        let root = rootDirectory
        guard FileManager.default.fileExists(atPath: root.path) else { return }
        do {
            try FileManager.default.removeItem(at: root)
        } catch {
            BarnHubLogger.warning("Failed to purge share temp files error=\(error.localizedDescription)")
        }
    }

    /// A file name safe for every share target: no path separators or characters
    /// Finder and Windows reject, no leading dot, bounded length, and exactly one
    /// extension.
    static func sanitizedFileName(_ name: String, fileExtension: String) -> String {
        let ext = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).lowercased()
        var base = name
        if !ext.isEmpty, base.lowercased().hasSuffix(".\(ext)") {
            base = String(base.dropLast(ext.count + 1))
        }
        let disallowed = CharacterSet(charactersIn: "/\\:?%*|\"<>")
            .union(.controlCharacters)
            .union(.newlines)
        base = base.unicodeScalars
            .map { disallowed.contains($0) ? "-" : String($0) }
            .joined()
            .replacingOccurrences(of: " ", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". _-"))
        if base.count > 120 { base = String(base.prefix(120)) }
        if base.isEmpty { base = "BarnHub" }
        return ext.isEmpty ? base : "\(base).\(ext)"
    }
}
