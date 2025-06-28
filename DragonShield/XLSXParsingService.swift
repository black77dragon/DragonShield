// DragonShield/XLSXParsingService.swift
// MARK: - Version 1.0.3.0
// MARK: - History
// - 1.0.0.2 -> 1.0.1.0: Initial XLSX parsing implementation replacing CSV logic.
// - 1.0.1.0 -> 1.0.1.1: Remove ZIPFoundation dependency and extract files via `unzip` command.
// - 1.0.1.1 -> 1.0.1.2: Provide descriptive parsing errors.
// - 1.0.1.2 -> 1.0.2.0: Support specifying the header row index.
// - 1.0.2.0 -> 1.0.3.0: Add helper to extract a specific cell value.

import Foundation

/// Parses the first worksheet of an XLSX workbook into dictionaries keyed by the header row.
enum XLSXParsingError: LocalizedError {
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .extractionFailed(let path):
            return "Failed to extract entry '\(path)' from XLSX archive."
        }
    }
}

struct XLSXParsingService {
    func parseWorkbook(at url: URL, headerRow: Int = 1) throws -> [[String: String]] {
        let sharedStrings = try extractSharedStrings(from: url)
        let sheetData = try extractEntry(from: url, path: "xl/worksheets/sheet1.xml")
        let worksheetParser = WorksheetParser(sharedStrings: sharedStrings, headerRow: headerRow)
        let parser = XMLParser(data: sheetData)
        parser.delegate = worksheetParser
        parser.parse()
        return worksheetParser.rows
    }

    func cellValue(from url: URL, cell: String) throws -> String? {
        let sharedStrings = try extractSharedStrings(from: url)
        let sheetData = try extractEntry(from: url, path: "xl/worksheets/sheet1.xml")
        let parser = XMLParser(data: sheetData)
        let delegate = SingleCellParser(targetCell: cell, sharedStrings: sharedStrings)
        parser.delegate = delegate
        parser.parse()
        return delegate.value
    }

    private func extractSharedStrings(from url: URL) throws -> [String] {
        guard let xmlData = try? extractEntry(from: url, path: "xl/sharedStrings.xml") else {
            return []
        }
        let delegate = SharedStringsParser()
        let parser = XMLParser(data: xmlData)
        parser.delegate = delegate
        parser.parse()
        return delegate.strings
    }

    private func extractEntry(from url: URL, path: String) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", url.path, path]
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        process.waitUntilExit()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
            throw XLSXParsingError.extractionFailed(path)
        }
        return data
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
    let headerRow: Int
    var rows: [[String: String]] = []
    private var headers: [Int: String] = [:]
    private var currentRow: [Int: String] = [:]
    private var currentCol = 0
    private var cellType: String?
    private var value = ""
    private var capturing = false
    private var rowIndex = 0

    init(sharedStrings: [String], headerRow: Int) {
        self.sharedStrings = sharedStrings
        self.headerRow = headerRow
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        switch elementName {
        case "row":
            rowIndex += 1
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
            if rowIndex == headerRow {
                headers[currentCol] = val
            } else if rowIndex > headerRow {
                currentRow[currentCol] = val
            }
        case "row":
            if rowIndex > headerRow {
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

private final class SingleCellParser: NSObject, XMLParserDelegate {
    let targetCell: String
    let sharedStrings: [String]
    var value: String?
    private var currentCell: String?
    private var cellType: String?
    private var capturing = false
    private var buffer = ""

    init(targetCell: String, sharedStrings: [String]) {
        self.targetCell = targetCell
        self.sharedStrings = sharedStrings
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        switch elementName {
        case "c":
            currentCell = attributeDict["r"]
            cellType = attributeDict["t"]
        case "v":
            if currentCell == targetCell { capturing = true; buffer = "" }
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturing { buffer += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "v" && capturing {
            capturing = false
            var val = buffer
            if cellType == "s", let idx = Int(val), idx < sharedStrings.count {
                val = sharedStrings[idx]
            }
            value = val
            parser.abortParsing()
        }
    }
}
