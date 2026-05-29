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
    
    @discardableResult
    func applyStatus(_ status: DayStatus, context: ModelContext) -> Result<Void, AppAlertInfo> {
        guard !selectedDates.isEmpty else {
            return .failure(AppUserFeedback.batchUpdateUnavailable)
        }

        var encounteredError: Error?
        
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
                encounteredError = error
                break
            }
        }

        if let encounteredError {
            AppDiagnostics.error("Batch edit fetch/update failed", error: encounteredError)
            return .failure(AppUserFeedback.batchUpdateUnavailable)
        }
        
        do {
            try context.save()
        } catch {
            AppDiagnostics.error("Batch edit save failed", error: error)
            return .failure(AppUserFeedback.batchUpdateUnavailable)
        }
        
        exitBatchMode()
        return .success(())
    }
}
