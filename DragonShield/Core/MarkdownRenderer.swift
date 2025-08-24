import Foundation
import SwiftUI

enum MarkdownRenderer {
    static func attributedString(from markdown: String) -> AttributedString {
        let sanitized = markdown.replacingOccurrences(of: "<", with: "&lt;")
        var attr = (try? AttributedString(markdown: sanitized, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(sanitized)
        for run in attr.runs {
            if let link = run.link, let scheme = link.scheme?.lowercased(), scheme != "http" && scheme != "https" {
                attr[run.range].link = nil
            }
        }
        return attr
    }

    static func plainText(from markdown: String) -> String {
        let attr = attributedString(from: markdown)
        return String(attr.characters)
    }
}
