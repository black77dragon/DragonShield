import Foundation
import AppKit

final class ThumbnailService {
    private let attachmentsDir: URL
    private let fm = FileManager.default

    init(attachmentsDir: URL? = nil) {
        if let dir = attachmentsDir {
            self.attachmentsDir = dir
        } else {
            let base = fm.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Containers/com.rene.DragonShield/Data/Library/Application Support/DragonShield/Attachments", isDirectory: true)
            self.attachmentsDir = base
        }
    }

    func loadImage(for attachment: Attachment) async -> NSImage? {
        let file = attachmentsDir
            .appendingPathComponent(String(attachment.sha256.prefix(2)), isDirectory: true)
            .appendingPathComponent(attachment.sha256 + (attachment.ext.map { ".\($0)" } ?? ""))
        return await Task.detached(priority: .userInitiated) {
            guard self.fm.fileExists(atPath: file.path) else { return nil }
            return NSImage(contentsOf: file)
        }.value
    }
}
