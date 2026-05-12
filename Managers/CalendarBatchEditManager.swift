import Foundation
import SwiftData
import Observation

@Observable
final class CalendarBatchEditManager {
    var selectedDates: Set<Date> = []
    var isBatchEditMode: Bool = false
    
    private let calendar = Calendar.current
    
    func enterBatchMode(initialDate: Date? = nil) {
        isBatchEditMode = true
        if let initialDate = initialDate {
            let normalizedDate = calendar.startOfDay(for: initialDate)
            selectedDates = [normalizedDate]
        }
    }
    
    func toggleSelection(for date: Date) {
        let normalizedDate = calendar.startOfDay(for: date)
        if selectedDates.contains(normalizedDate) {
            selectedDates.remove(normalizedDate)
            if selectedDates.isEmpty {
                exitBatchMode()
            }
        } else {
            selectedDates.insert(normalizedDate)
        }
    }
    
    func exitBatchMode() {
        isBatchEditMode = false
        selectedDates.removeAll()
    }
    
    func applyStatus(_ status: DayStatus, context: ModelContext) {
        guard !selectedDates.isEmpty else { return }
        
        for date in selectedDates {
            let start = date
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { continue }
            
            var descriptor = FetchDescriptor<DayRecord>(
                predicate: #Predicate { $0.date >= start && $0.date < end }
            )
            descriptor.fetchLimit = 1
            
            do {
                let existingRecords = try context.fetch(descriptor)
                if let existing = existingRecords.first {
                    if status == .none {
                        context.delete(existing)
                    } else {
                        existing.statusRaw = status.rawValue
                        existing.isAutoDetected = false
                    }
                } else if status != .none {
                    let newRecord = DayRecord(date: start, status: status, isAutoDetected: false)
                    context.insert(newRecord)
                }
            } catch {
                print("Failed to fetch/update record for batch edit: \(error)")
            }
        }
        
        do {
            try context.save()
        } catch {
            print("Failed to save context after batch edit: \(error)")
        }
        
        exitBatchMode()
    }
}
