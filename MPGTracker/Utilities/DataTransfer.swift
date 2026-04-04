//
//  DataTransfer.swift
//  MPGTracker
//
//  Created by Devin Kott on 4/3/26.
//

import Foundation
import SwiftData

// MARK: - DTO

/// A `Codable` mirror of `FillUpEntry` for JSON serialization.
///
/// `@Model` classes are managed by SwiftData and cannot conform to `Codable` directly —
/// the macro replaces stored properties with PersistentModel backing that the encoder can't traverse.
private struct FillUpEntryDTO: Codable {
    var id: UUID
    var date: Date
    var milesDriven: Double
    var gallonsPumped: Double
    var calculatedMPG: Double
    var totalPricePaid: Double?
    var pricePerGallon: Double?
    var truckReportedMPG: Double?
    var notes: String?
}

// MARK: - DataTransfer

/// Pure static functions for importing and exporting fill-up data.
///
/// No SwiftData imports; no UI code. Safe to call from any context.
enum DataTransfer {

    /// Thrown when the CSV header is missing one or more columns required for import.
    enum ImportError: LocalizedError {
        case missingRequiredColumns([String])

        var errorDescription: String? {
            switch self {
            case .missingRequiredColumns(let cols):
                return "Missing required columns: \(cols.joined(separator: ", "))."
            }
        }
    }

    /// CSV header row — must match the column order used in `csvRow(from:)`.
    private static let csvHeader =
        "date,milesDriven,gallonsPumped,calculatedMPG,totalPricePaid,pricePerGallon,truckReportedMPG,notes"

    /// Columns that must be present in any imported CSV header.
    private static let requiredColumns = ["date", "milesDriven", "gallonsPumped"]

    /// Shared ISO 8601 formatter for consistent date serialization.
    private static let iso8601: ISO8601DateFormatter = ISO8601DateFormatter()

    // MARK: - CSV Export

    /// Serializes all entries to a CSV string with a header row.
    ///
    /// - Parameter entries: The entries to serialize.
    /// - Returns: A UTF-8 CSV string ready to write to a file.
    static func exportCSV(entries: [FillUpEntry]) -> String {
        let rows = entries.map { csvRow(from: $0) }
        return ([csvHeader] + rows).joined(separator: "\n")
    }

    /// Formats a single entry as a CSV row.
    private static func csvRow(from entry: FillUpEntry) -> String {
        let fields: [String] = [
            iso8601.string(from: entry.date),
            String(entry.milesDriven),
            String(entry.gallonsPumped),
            String(entry.calculatedMPG),
            entry.totalPricePaid.map { String($0) } ?? "",
            entry.pricePerGallon.map { String($0) } ?? "",
            entry.truckReportedMPG.map { String($0) } ?? "",
            entry.notes ?? ""
        ]
        return fields.map { csvEscape($0) }.joined(separator: ",")
    }

    /// Wraps a field in double-quotes if it contains a comma, quote, or newline.
    /// Internal double-quotes are escaped by doubling them per RFC 4180.
    private static func csvEscape(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"") || value.contains("\n")
        guard needsQuoting else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: - JSON Export

    /// Serializes all entries to pretty-printed JSON data.
    ///
    /// - Parameter entries: The entries to serialize.
    /// - Returns: UTF-8 JSON data.
    /// - Throws: `EncodingError` if encoding fails.
    static func exportJSON(entries: [FillUpEntry]) throws -> Data {
        let dtos = entries.map { dto(from: $0) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(dtos)
    }

    /// Maps a `FillUpEntry` to a `FillUpEntryDTO` for encoding.
    private static func dto(from entry: FillUpEntry) -> FillUpEntryDTO {
        FillUpEntryDTO(
            id: entry.id,
            date: entry.date,
            milesDriven: entry.milesDriven,
            gallonsPumped: entry.gallonsPumped,
            calculatedMPG: entry.calculatedMPG,
            totalPricePaid: entry.totalPricePaid,
            pricePerGallon: entry.pricePerGallon,
            truckReportedMPG: entry.truckReportedMPG,
            notes: entry.notes
        )
    }

    // MARK: - CSV Import

    /// Parses a CSV string into new `FillUpEntry` objects.
    ///
    /// The first line is parsed as a header to build a name→index column map.
    /// Throws `ImportError.missingRequiredColumns` if any required column is absent.
    /// Malformed data rows are counted but not imported.
    ///
    /// - Parameter csv: A UTF-8 CSV string, typically from a previously exported file.
    /// - Returns: A tuple of successfully created entries and the count of rows that were skipped.
    /// - Throws: `ImportError` if the header is missing required columns.
    static func importCSV(_ csv: String) throws -> (entries: [FillUpEntry], skippedCount: Int) {
        let lines = csv.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count > 1 else { return ([], 0) }
        let columnMap = try parseHeaderColumns(lines[0])
        let dataLines = Array(lines.dropFirst())
        let entries = dataLines.compactMap { parseRow(splitCSVRow($0), columnMap: columnMap) }
        return (entries, dataLines.count - entries.count)
    }

    /// Parses the header row into a name→index map and validates that all required columns are present.
    ///
    /// - Throws: `ImportError.missingRequiredColumns` listing any absent required column names.
    private static func parseHeaderColumns(_ line: String) throws -> [String: Int] {
        let headers = splitCSVRow(line)
        let map = Dictionary(
            uniqueKeysWithValues: headers.enumerated().map { ($1.trimmingCharacters(in: .whitespaces), $0) }
        )
        let missing = requiredColumns.filter { map[$0] == nil }
        guard missing.isEmpty else { throw ImportError.missingRequiredColumns(missing) }
        return map
    }

    /// Splits a CSV row into column strings, respecting RFC 4180 quoting rules.
    private static func splitCSVRow(_ row: String) -> [String] {
        var columns: [String] = []
        var current = ""
        var inQuotes = false
        var index = row.startIndex

        while index < row.endIndex {
            let ch = row[index]
            let next = row.index(after: index)

            if ch == "\"" {
                if inQuotes && next < row.endIndex && row[next] == "\"" {
                    // Escaped quote inside a quoted field
                    current.append("\"")
                    index = row.index(after: next)
                    continue
                }
                inQuotes.toggle()
            } else if ch == "," && !inQuotes {
                columns.append(current)
                current = ""
            } else {
                current.append(ch)
            }
            index = next
        }
        columns.append(current)
        return columns
    }

    /// Parses a split row into a `FillUpEntry` using name-based column lookup.
    ///
    /// Returns `nil` if any required field is missing, unparseable, zero, or exceeds the
    /// allowed range (miles > 1,000 or gallons > 100) — matching form-layer validation.
    /// `calculatedMPG` and `pricePerGallon` are always re-derived; CSV values are ignored.
    private static func parseRow(_ columns: [String], columnMap: [String: Int]) -> FillUpEntry? {
        func value(for key: String) -> String? {
            guard let index = columnMap[key], index < columns.count else { return nil }
            return columns[index]
        }

        guard let dateStr = value(for: "date"),
              let date = iso8601.date(from: dateStr),
              let milesStr = value(for: "milesDriven"),
              let miles = Double(milesStr),
              let gallonsStr = value(for: "gallonsPumped"),
              let gallons = Double(gallonsStr),
              miles > 0, miles <= 1_000,
              gallons > 0, gallons <= 100 else { return nil }

        let totalPricePaid = value(for: "totalPricePaid").flatMap { Double($0) }
        let truckReportedMPG = value(for: "truckReportedMPG").flatMap { Double($0) }
        let rawNotes = value(for: "notes") ?? ""
        let notes: String? = rawNotes.isEmpty ? nil : rawNotes

        return FillUpEntry(
            date: date,
            milesDriven: miles,
            gallonsPumped: gallons,
            totalPricePaid: totalPricePaid,
            truckReportedMPG: truckReportedMPG,
            notes: notes
        )
    }
}
