import Foundation
import SwiftData

struct CSVImporter {
    enum ImportError: Error, Equatable {
        case fileAccessDenied
        case fileReadFailed
        case invalidFormat
        case saveFailed
    }

    static func importCSV(from url: URL, container: ModelContainer) async throws {
        let didAccessSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let importURL: URL
        let cleanupURL: URL?
        if didAccessSecurityScope, !isWithinAppContainer(url) {
            // Security-scoped URLs are fragile across threads/tasks. Copy the file into a
            // local temp location while access is granted, then parse/import off-main.
            importURL = try copyToTemporaryFile(from: url)
            cleanupURL = importURL
        } else {
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                throw ImportError.fileAccessDenied
            }
            importURL = url
            cleanupURL = nil
        }
        defer {
            if let cleanupURL {
                try? FileManager.default.removeItem(at: cleanupURL)
            }
        }

        let job = ImportJob(url: importURL, container: container)
        try await Task.detached(priority: .utility) { try performImport(job) }.value
    }

    private static func copyToTemporaryFile(from url: URL) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("InOffice_Import_\(UUID().uuidString).csv")

        do {
            // Ensure we never reuse a stale file.
            try? FileManager.default.removeItem(at: tempURL)
            try FileManager.default.copyItem(at: url, to: tempURL)
            return tempURL
        } catch {
            AppDiagnostics.error("CSV import temp copy failed", error: error)
            throw ImportError.fileReadFailed
        }
    }

    private static func isWithinAppContainer(_ url: URL) -> Bool {
        let sandboxRoot = FileManager.default.temporaryDirectory.deletingLastPathComponent()
        let sandboxPath = sandboxRoot.path
        return url.path == sandboxPath || url.path.hasPrefix("\(sandboxPath)/")
    }

    private static func performImport(_ job: ImportJob) throws {
        let url = job.url
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            throw ImportError.fileReadFailed
        }

        let normalizedContent = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let rows = parseCSVRows(from: normalizedContent)
        guard rows.count > 1 else {
            throw ImportError.invalidFormat
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        var rowsByDate: [Date: ParsedRow] = [:]
        rowsByDate.reserveCapacity(rows.count - 1)
        var minDate: Date?
        var maxDate: Date?
        var encounteredDataRow = false

        // Skip header row.
        for fields in rows.dropFirst() {
            guard fields.count >= 3 else { continue }
            encounteredDataRow = true

            let dateStr = fields[0]
            let statusStr = fields[1]
            let autoStr = fields[2]
            let notesStr = fields.count >= 4 ? fields[3] : ""

            guard let startOfDay = localDay(from: dateStr, calendar: calendar) else { continue }
            let notes = restoredImportedNotes(from: notesStr)

            guard let status = parseStatus(from: statusStr) else { continue }

            rowsByDate[startOfDay] = ParsedRow(
                date: startOfDay,
                status: status,
                isAutoDetected: autoStr.lowercased() == "true",
                notes: notes
            )

            minDate = minDate.map { min($0, startOfDay) } ?? startOfDay
            maxDate = maxDate.map { max($0, startOfDay) } ?? startOfDay
        }

        guard !rowsByDate.isEmpty else {
            if encounteredDataRow {
                return
            }
            throw ImportError.invalidFormat
        }
        guard let startRange = minDate,
              let endRangeStart = maxDate else {
            throw ImportError.invalidFormat
        }

        let endRange = calendar.date(byAdding: .day, value: 1, to: endRangeStart) ?? endRangeStart
        let context = ModelContext(job.container)

        do {
            let descriptor = FetchDescriptor<DayRecord>(
                predicate: #Predicate { record in
                    record.date >= startRange && record.date < endRange
                }
            )
            let existingRecords = try context.fetch(descriptor)
            var existingByDate: [Date: DayRecord] = [:]
            existingByDate.reserveCapacity(existingRecords.count)

            for record in existingRecords {
                existingByDate[calendar.startOfDay(for: record.date)] = record
            }

            for row in rowsByDate.values {
                if let existing = existingByDate[row.date] {
                    if row.status == .none {
                        context.delete(existing)
                        continue
                    }

                    existing.statusRaw = row.status.rawValue
                    existing.isAutoDetected = row.isAutoDetected
                    existing.notes = row.notes
                    continue
                }

                if row.status == .none {
                    continue
                }

                context.insert(
                    DayRecord(
                        date: row.date,
                        status: row.status,
                        isAutoDetected: row.isAutoDetected,
                        notes: row.notes
                    )
                )
            }

            try context.save()
        } catch {
            AppDiagnostics.error("CSV import failed", error: error)
            throw ImportError.saveFailed
        }
    }

    private static func restoredImportedNotes(from notes: String) -> String? {
        guard !notes.isEmpty else { return nil }

        guard notes.first == "'",
              let secondCharacter = notes.dropFirst().first,
              "=+-@".contains(secondCharacter) else {
            return notes
        }

        return String(notes.dropFirst())
    }

    private static func parseStatus(from statusString: String) -> DayStatus? {
        let trimmed = statusString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let status = DayStatus(rawValue: trimmed) {
            return status
        }

        switch trimmed.lowercased() {
        case "in office", "inoffice", "office", "in_office":
            return .inOffice
        case "remote":
            return .remote
        case "pto":
            return .pto
        case "holiday":
            return .holiday
        case "none":
            return DayStatus.none
        default:
            return nil
        }
    }

    private static func localDay(from dayString: String, calendar: Calendar) -> Date? {
        // Prefer strict parsing of YYYY-MM-DD as a *local calendar day*.
        // Using ISO8601DateFormatter here can shift the day when interpreted as UTC midnight.
        let parts = dayString.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            // Back-compat for any legacy exports that might not match the expected format.
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
            guard let parsed = formatter.date(from: dayString) else { return nil }
            var cal = calendar
            cal.timeZone = .current
            return cal.startOfDay(for: parsed)
        }

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        // Use midday to avoid DST edge cases, then normalize to start-of-day.
        components.hour = 12

        guard let midday = calendar.date(from: components) else { return nil }
        return calendar.startOfDay(for: midday)
    }

    // Minimal CSV parser supporting:
    // - quoted fields
    // - escaped quotes ("")
    // - commas inside quotes
    // - newlines inside quotes
    private static func parseCSVRows(from content: String) -> [[String]] {
        var rows: [[String]] = []
        rows.reserveCapacity(256)

        var currentRow: [String] = []
        currentRow.reserveCapacity(4)

        var currentField = ""
        currentField.reserveCapacity(32)

        var inQuotes = false
        var iterator = content.makeIterator()
        var previousWasCR = false

        func finishField() {
            currentRow.append(currentField)
            currentField = ""
        }

        func finishRow() {
            // Drop trailing completely-empty row (e.g. final newline).
            if currentRow.count == 1, currentRow[0].isEmpty {
                currentRow.removeAll(keepingCapacity: true)
                return
            }
            rows.append(currentRow)
            currentRow.removeAll(keepingCapacity: true)
        }

        while let character = iterator.next() {
            if previousWasCR {
                previousWasCR = false
                if character == "\n" {
                    continue
                }
            }

            if character == "\"" {
                if inQuotes {
                    // If next is another quote, it's an escaped quote. Otherwise, end quote.
                    if let next = iterator.next() {
                        if next == "\"" {
                            currentField.append("\"")
                        } else {
                            inQuotes = false
                            // Put back the non-quote by handling it in the main loop.
                            // Swift's String.Iterator has no pushback, so we handle common cases directly.
                            if next == "," {
                                finishField()
                            } else if next == "\n" {
                                finishField()
                                finishRow()
                            } else if next == "\r" {
                                finishField()
                                finishRow()
                                previousWasCR = true
                            } else {
                                currentField.append(next)
                            }
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    // Start quoted field only if field is currently empty.
                    if currentField.isEmpty {
                        inQuotes = true
                    } else {
                        currentField.append(character)
                    }
                }
                continue
            }

            if character == "," && !inQuotes {
                finishField()
                continue
            }

            if character == "\n" && !inQuotes {
                finishField()
                finishRow()
                continue
            }

            if character == "\r" && !inQuotes {
                finishField()
                finishRow()
                previousWasCR = true
                continue
            }

            currentField.append(character)
        }

        // Final field/row if content doesn't end with newline.
        if inQuotes {
            // Best-effort: treat as closed; we'll still return parsed content.
            inQuotes = false
        }
        if !currentField.isEmpty || !currentRow.isEmpty {
            finishField()
            finishRow()
        }

        return rows
    }
}

private struct ParsedRow {
    let date: Date
    let status: DayStatus
    let isAutoDetected: Bool
    let notes: String?
}

private struct ImportJob: @unchecked Sendable {
    let url: URL
    let container: ModelContainer
}
