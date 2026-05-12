import Foundation

struct CSVExporter {
    static func export(records: [DayRecord]) -> URL? {
        var csvString = "Date,Status,AutoDetected,Notes\n"
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        
        for record in records {
            let dateStr = formatter.string(from: record.date)
            let statusStr = record.statusRaw
            let autoStr = record.isAutoDetected ? "true" : "false"
            
            // Escape notes
            var notesStr = record.notes ?? ""
            if notesStr.contains(",") || notesStr.contains("\n") || notesStr.contains("\"") {
                notesStr = notesStr.replacingOccurrences(of: "\"", with: "\"\"")
                notesStr = "\"\(notesStr)\""
            }
            
            csvString.append("\(dateStr),\(statusStr),\(autoStr),\(notesStr)\n")
        }
        
        let fileName = "InOffice_Backup_\(Int(Date().timeIntervalSince1970)).csv"
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: tempUrl, atomically: true, encoding: .utf8)
            return tempUrl
        } catch {
            print("Failed to write CSV: \(error)")
            return nil
        }
    }
}
