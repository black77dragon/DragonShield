// DragonShield/XLSXParsingService.swift
// MARK: - Version 1.0.1.0
// MARK: - History
// - 1.0.0.2 -> 1.0.1.0: Initial XLSX parsing implementation replacing CSV logic.

import Foundation
import ZIPFoundation

/// Parses the first worksheet of an XLSX workbook into dictionaries keyed by the header row.
struct XLSXParsingService {
    func parseWorkbook(at url: URL) throws -> [[String: String]] {
        guard let archive = Archive(url: url, accessMode: .read) else { return [] }
        let sharedStrings = try extractSharedStrings(from: archive)
        guard let sheetEntry = archive["xl/worksheets/sheet1.xml"] else { return [] }
        var sheetData = Data()
        _ = try archive.extract(sheetEntry) { sheetData.append($0) }
        let worksheetParser = WorksheetParser(sharedStrings: sharedStrings)
        let parser = XMLParser(data: sheetData)
        parser.delegate = worksheetParser
        parser.parse()
        return worksheetParser.rows
    }

    private func extractSharedStrings(from archive: Archive) throws -> [String] {
        guard let entry = archive["xl/sharedStrings.xml"] else { return [] }
        var xmlData = Data()
        _ = try archive.extract(entry) { xmlData.append($0) }
        let delegate = SharedStringsParser()
        let parser = XMLParser(data: xmlData)
        parser.delegate = delegate
        parser.parse()
        return delegate.strings
    }
}

private final class SharedStringsParser: NSObject, XMLParserDelegate {
    var strings: [String] = []
    private var current = ""
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "t" { current = "" }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { current += string }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "t" { strings.append(current) }
    }
}

private final class WorksheetParser: NSObject, XMLParserDelegate {
    let sharedStrings: [String]
    var rows: [[String: String]] = []
    private var headers: [Int: String] = [:]
    private var currentRow: [Int: String] = [:]
    private var currentCol = 0
    private var cellType: String?
    private var value = ""
    private var capturing = false

    init(sharedStrings: [String]) { self.sharedStrings = sharedStrings }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        switch elementName {
        case "c":
            currentCol = columnIndex(from: attributeDict["r"] ?? "A")
            cellType = attributeDict["t"]
        case "v":
            capturing = true
            value = ""
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturing { value += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "v":
            capturing = false
            var val = value
            if cellType == "s", let idx = Int(val), idx < sharedStrings.count {
                val = sharedStrings[idx]
            }
            if headers.isEmpty {
                headers[currentCol] = val
            } else {
                currentRow[currentCol] = val
            }
        case "row":
            if !headers.isEmpty {
                var dict: [String: String] = [:]
                for (idx, header) in headers {
                    dict[header] = currentRow[idx] ?? ""
                }
                rows.append(dict)
            }
            currentRow.removeAll()
        default: break
        }
    }

    private func columnIndex(from cellRef: String) -> Int {
        let letters = cellRef.prefix { $0.isLetter }
        var index = 0
        for ch in letters {
            index = index * 26 + Int(ch.asciiValue! - 65 + 1)
        }
        return index
    }
}
