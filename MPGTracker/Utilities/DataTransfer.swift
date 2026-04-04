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

    /// CSV header row — must match the column order used in `csvRow(from:)`.
    private static let csvHeader =
        "date,milesDriven,gallonsPumped,calculatedMPG,totalPricePaid,pricePerGallon,truckReportedMPG,notes"

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
    /// The first line is treated as a header and skipped. Malformed rows are counted but
    /// not imported — this function never throws or crashes.
    ///
    /// - Parameter csv: A UTF-8 CSV string, typically from a previously exported file.
    /// - Returns: A tuple of successfully created entries and the count of rows that were skipped.
    static func importCSV(_ csv: String) -> (entries: [FillUpEntry], skippedCount: Int) {
        let lines = csv.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count > 1 else { return ([], 0) }
        let dataLines = Array(lines.dropFirst())
        let entries = dataLines.compactMap { parseRow(splitCSVRow($0)) }
        return (entries, dataLines.count - entries.count)
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

    /// Parses a split row into a `FillUpEntry`. Returns `nil` if required fields are invalid.
    ///
    /// Required columns: date (index 0), milesDriven (1), gallonsPumped (2).
    /// calculatedMPG (3) is re-derived from the model; it is not read from CSV.
    private static func parseRow(_ columns: [String]) -> FillUpEntry? {
        guard columns.count >= 3 else { return nil }

        guard let date = iso8601.date(from: columns[0]),
              let miles = Double(columns[1]),
              let gallons = Double(columns[2]),
              miles > 0,
              gallons > 0 else { return nil }

        let totalPricePaid = columns.count > 4 ? Double(columns[4]) : nil
        let truckReportedMPG = columns.count > 6 ? Double(columns[6]) : nil
        let rawNotes = columns.count > 7 ? columns[7] : ""
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
