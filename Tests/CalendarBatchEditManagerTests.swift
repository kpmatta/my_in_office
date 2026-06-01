import XCTest
import SwiftData
@testable import InOffice

final class CalendarBatchEditManagerTests: XCTestCase {
    func testApplyStatusCreatesAndUpdatesRecords() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = ModelContext(container)

        var manager = CalendarBatchEditManager()
        manager.enterBatchMode()
        manager.toggleSelection(for: TestSupport.date(2026, 5, 1))
        manager.toggleSelection(for: TestSupport.date(2026, 5, 2))
        manager.toggleSelection(for: TestSupport.date(2026, 5, 3))

        let result = manager.applyStatus(.inOffice, context: context)
        switch result {
        case .success:
            break
        case .failure(let alert):
            XCTFail("Expected success, got \(alert)")
        }

        let records = try context.fetch(FetchDescriptor<DayRecord>(sortBy: [SortDescriptor(\.date)]))
        XCTAssertEqual(records.count, 3)
        XCTAssertTrue(records.allSatisfy { $0.status == .inOffice })
        XCTAssertTrue(records.allSatisfy { $0.isAutoDetected == false })
        XCTAssertFalse(manager.isBatchEditMode)
        XCTAssertTrue(manager.selectedDates.isEmpty)
    }

    func testApplyNoneDeletesExistingRecords() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = ModelContext(container)

        // Seed two records.
        context.insert(TestSupport.record(2026, 5, 1, status: .remote))
        context.insert(TestSupport.record(2026, 5, 2, status: .pto))
        try context.save()

        var manager = CalendarBatchEditManager()
        manager.enterBatchMode()
        manager.toggleSelection(for: TestSupport.date(2026, 5, 1))
        manager.toggleSelection(for: TestSupport.date(2026, 5, 2))

        let result = manager.applyStatus(.none, context: context)
        switch result {
        case .success:
            break
        case .failure(let alert):
            XCTFail("Expected success, got \(alert)")
        }

        let records = try context.fetch(FetchDescriptor<DayRecord>())
        XCTAssertEqual(records.count, 0)
        XCTAssertFalse(manager.isBatchEditMode)
        XCTAssertTrue(manager.selectedDates.isEmpty)
    }

    func testApplyWithoutSelectionFails() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = ModelContext(container)

        var manager = CalendarBatchEditManager()
        manager.enterBatchMode()

        let result = manager.applyStatus(.inOffice, context: context)
        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure:
            break
        }
    }
}

