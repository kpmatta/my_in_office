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
        let job = ImportJob(url: url, container: container)
        try await Task.detached(priority: .utility) {
            try performImport(job)
        }.value
    }

    private static func performImport(_ job: ImportJob) throws {
        let url = job.url
        let didAccessSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        if !didAccessSecurityScope,
           !FileManager.default.isReadableFile(atPath: url.path) {
            throw ImportError.fileAccessDenied
        }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            throw ImportError.fileReadFailed
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else {
            throw ImportError.invalidFormat
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]

        let calendar = Calendar.current
        var rowsByDate: [Date: ParsedRow] = [:]
        rowsByDate.reserveCapacity(lines.count - 1)
        var minDate: Date?
        var maxDate: Date?

        for line in lines.dropFirst() {
            let fields = parseCSVLine(line)
            guard fields.count >= 3 else { continue }

            let dateStr = fields[0]
            let statusStr = fields[1]
            let autoStr = fields[2]
            let notesStr = fields.count >= 4 ? fields[3] : ""

            guard let date = formatter.date(from: dateStr) else { continue }

            let startOfDay = calendar.startOfDay(for: date)
            let notes = restoredImportedNotes(from: notesStr)

            rowsByDate[startOfDay] = ParsedRow(
                date: startOfDay,
                status: DayStatus(rawValue: statusStr) ?? .none,
                isAutoDetected: autoStr.lowercased() == "true",
                notes: notes
            )

            minDate = minDate.map { min($0, startOfDay) } ?? startOfDay
            maxDate = maxDate.map { max($0, startOfDay) } ?? startOfDay
        }

        guard !rowsByDate.isEmpty,
              let startRange = minDate,
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
                    existing.statusRaw = row.status.rawValue
                    existing.isAutoDetected = row.isAutoDetected
                    existing.notes = row.notes
                } else {
                    context.insert(
                        DayRecord(
                            date: row.date,
                            status: row.status,
                            isAutoDetected: row.isAutoDetected,
                            notes: row.notes
                        )
                    )
                }
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

    private static func parseCSVLine(_ line: String) -> [String] {
        var result = [String]()
        var currentField = ""
        var inQuotes = false

        let characters = Array(line)
        var index = 0

        while index < characters.count {
            let character = characters[index]

            if character == "\"" {
                if inQuotes && index + 1 < characters.count && characters[index + 1] == "\"" {
                    currentField.append("\"")
                    index += 1
                } else {
                    inQuotes.toggle()
                }
            } else if character == "," && !inQuotes {
                result.append(currentField)
                currentField = ""
            } else {
                currentField.append(character)
            }

            index += 1
        }

        result.append(currentField)
        return result
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
