import Foundation
import SwiftData

struct CSVImporter {
    enum ImportError: Error {
        case fileReadError
        case parseError
    }
    
    static func importCSV(from url: URL, context: ModelContext) throws {
        // Read file content securely
        guard url.startAccessingSecurityScopedResource() else {
            throw ImportError.fileReadError
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            throw ImportError.fileReadError
        }
        
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else { return } // Only header or empty
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        
        let calendar = Calendar.current
        
        // Skip header (lines[0])
        for i in 1..<lines.count {
            let line = lines[i]
            let fields = parseCSVLine(line)
            guard fields.count >= 3 else { continue }
            
            let dateStr = fields[0]
            let statusStr = fields[1]
            let autoStr = fields[2]
            let notesStr = fields.count >= 4 ? fields[3] : ""
            
            guard let date = formatter.date(from: dateStr) else { continue }
            let isAuto = (autoStr.lowercased() == "true")
            let status = DayStatus(rawValue: statusStr) ?? .none
            
            // Normalize date to start of day
            let startOfDay = calendar.startOfDay(for: date)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { continue }
            
            // Check if record exists for this day
            var descriptor = FetchDescriptor<DayRecord>(
                predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay }
            )
            descriptor.fetchLimit = 1
            
            do {
                let existingRecords = try context.fetch(descriptor)
                if let existing = existingRecords.first {
                    // Update existing
                    existing.statusRaw = status.rawValue
                    existing.isAutoDetected = isAuto
                    if !notesStr.isEmpty {
                        existing.notes = notesStr
                    }
                } else {
                    // Insert new
                    let newRecord = DayRecord(date: startOfDay, status: status, isAutoDetected: isAuto, notes: notesStr.isEmpty ? nil : notesStr)
                    context.insert(newRecord)
                }
            } catch {
                print("Failed to fetch/insert record during import: \(error)")
            }
        }
        
        try context.save()
    }
    
    // A simple CSV line parser to handle quotes
    private static func parseCSVLine(_ line: String) -> [String] {
        var result = [String]()
        var currentField = ""
        var inQuotes = false
        
        let characters = Array(line)
        var i = 0
        
        while i < characters.count {
            let char = characters[i]
            
            if char == "\"" {
                if inQuotes && i + 1 < characters.count && characters[i+1] == "\"" {
                    // Escaped quote ""
                    currentField.append("\"")
                    i += 1 // skip the second quote
                } else {
                    inQuotes.toggle()
                }
            } else if char == "," && !inQuotes {
                result.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }
            i += 1
        }
        result.append(currentField)
        
        return result
    }
}
