import Foundation

struct CSVExporter {
    enum ExportError: Error {
        case writeFailed
    }

    static func export(records: [DayRecord]) async -> Result<URL, ExportError> {
        let snapshots = records.map { record in
            ExportRecordSnapshot(
                date: record.date,
                statusRaw: record.statusRaw,
                isAutoDetected: record.isAutoDetected,
                notes: record.notes
            )
        }

        return await Task.detached(priority: .utility) {
            exportSnapshots(snapshots)
        }.value
    }

    private static func exportSnapshots(_ records: [ExportRecordSnapshot]) -> Result<URL, ExportError> {
        var csvString = "Date,Status,AutoDetected,Notes\n"
        let calendar = Calendar(identifier: .gregorian)

        for record in records {
            let dateStr = localDayString(from: record.date, calendar: calendar)
            let autoStr = record.isAutoDetected ? "true" : "false"
            let notesStr = escapedCSVField(formulaSafeNotes(from: record.notes ?? ""))

            csvString.append("\(dateStr),\(record.statusRaw),\(autoStr),\(notesStr)\n")
        }

        let fileName = "InOffice_Backup_\(Int(Date().timeIntervalSince1970)).csv"
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csvString.write(to: tempUrl, atomically: true, encoding: .utf8)
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: tempUrl.path
            )
            return .success(tempUrl)
        } catch {
            AppDiagnostics.error("CSV export failed", error: error)
            return .failure(.writeFailed)
        }
    }

    private static func formulaSafeNotes(from notes: String) -> String {
        guard let firstCharacter = notes.first,
              "=+-@".contains(firstCharacter) else {
            return notes
        }

        return "'\(notes)"
    }

    private static func escapedCSVField(_ value: String) -> String {
        guard value.contains(",") || value.contains("\n") || value.contains("\"") else {
            return value
        }

        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static func localDayString(from date: Date, calendar: Calendar) -> String {
        var calendar = calendar
        calendar.timeZone = .current

        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            // Fallback: should not happen for persisted DayRecord dates.
            return "1970-01-01"
        }

        // YYYY-MM-DD
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

private struct ExportRecordSnapshot: Sendable {
    let date: Date
    let statusRaw: String
    let isAutoDetected: Bool
    let notes: String?
}
