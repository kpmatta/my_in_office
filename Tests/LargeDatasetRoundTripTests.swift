import XCTest
import SwiftData
@testable import InOffice

final class LargeDatasetRoundTripTests: XCTestCase {
    func testExportImportRoundTripPreservesCountsForMultiYearDataset() async throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = ModelContext(container)

        // Seed ~5 years of daily records with a repeating pattern.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TestSupport.timeZone

        let start = TestSupport.date(2021, 1, 1)
        let end = TestSupport.date(2026, 1, 1)

        var cursor = start
        var dayIndex = 0
        while cursor < end {
            let status: DayStatus
            switch dayIndex % 6 {
            case 0, 1:
                status = .inOffice
            case 2:
                status = .remote
            case 3:
                status = .pto
            case 4:
                status = .holiday
            default:
                status = .remote
            }

            let record = DayRecord(date: cursor, status: status, isAutoDetected: false, notes: dayIndex % 17 == 0 ? "note \(dayIndex)" : nil)
            // Force stable stored date for test determinism.
            record.date = cursor
            context.insert(record)

            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
            dayIndex += 1
        }
        try context.save()

        let before = try context.fetch(FetchDescriptor<DayRecord>())
        let beforeCounts = countsByStatus(before)

        let exported = await CSVExporter.export(records: before)
        guard case .success(let url) = exported else {
            XCTFail("Expected export success")
            return
        }
        defer { try? FileManager.default.removeItem(at: url) }

        try context.delete(model: DayRecord.self)
        try context.save()

        try await CSVImporter.importCSV(from: url, container: container)

        let after = try context.fetch(FetchDescriptor<DayRecord>())
        let afterCounts = countsByStatus(after)

        XCTAssertEqual(beforeCounts, afterCounts)
        XCTAssertEqual(after.count, before.count)
    }

    private func countsByStatus(_ records: [DayRecord]) -> [DayStatus: Int] {
        var result: [DayStatus: Int] = [:]
        for record in records {
            result[record.status, default: 0] += 1
        }
        return result
    }
}

