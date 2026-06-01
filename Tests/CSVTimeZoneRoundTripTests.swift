import XCTest
import SwiftData
@testable import InOffice

final class CSVTimeZoneRoundTripTests: XCTestCase {
    func testRoundTripDoesNotShiftDaysInNegativeOffsetTimeZones() async throws {
        let losAngeles = TimeZone(identifier: "America/Los_Angeles")!

        try await TestSupport.withDefaultTimeZone(losAngeles) {
            let container = try TestSupport.makeInMemoryContainer()
            let context = ModelContext(container)

            // May 4, 2026 is a Monday.
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = losAngeles
            let mondayComponents = DateComponents(timeZone: losAngeles, year: 2026, month: 5, day: 4, hour: 12)
            let mondayMidday = calendar.date(from: mondayComponents)!

            context.insert(DayRecord(date: mondayMidday, status: .inOffice, isAutoDetected: false, notes: "monday"))
            try context.save()

            let exported = await CSVExporter.export(records: try context.fetch(FetchDescriptor<DayRecord>()))
            guard case .success(let url) = exported else {
                XCTFail("Expected export success")
                return
            }
            defer { try? FileManager.default.removeItem(at: url) }

            try context.delete(model: DayRecord.self)
            try context.save()

            try await CSVImporter.importCSV(from: url, container: container)

            let imported = try context.fetch(FetchDescriptor<DayRecord>())
            XCTAssertEqual(imported.count, 1)

            let importedDate = imported[0].date
            let importedWeekday = calendar.component(.weekday, from: importedDate)

            // Monday in Gregorian calendar is 2 when week starts on Sunday.
            XCTAssertEqual(importedWeekday, 2)
            XCTAssertEqual(imported[0].notes, "monday")
        }
    }
}

