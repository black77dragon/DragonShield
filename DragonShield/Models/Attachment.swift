import Foundation

struct Attachment {
    let id: Int
    let sha256: String
    let originalFilename: String
    let mime: String
    let byteSize: Int
    let ext: String?
    let createdAt: String
    let createdBy: String
}
