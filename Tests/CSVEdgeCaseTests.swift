import XCTest
import SwiftData
@testable import InOffice

final class CSVEdgeCaseTests: XCTestCase {
    func testImportHandlesQuotedCommasQuotesAndNewlines() async throws {
        let container = try TestSupport.makeInMemoryContainer()

        let csv = """
        Date,Status,AutoDetected,Notes
        2026-05-01,In Office,false,"Hello, world"
        2026-05-02,Remote,false,"She said ""hi""."
        2026-05-03,PTO,true,"Line1
        Line2"
        """

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        try await CSVImporter.importCSV(from: url, container: container)

        let context = ModelContext(container)
        let records = try context.fetch(FetchDescriptor<DayRecord>(sortBy: [SortDescriptor(\.date)]))
        XCTAssertEqual(records.count, 3)
        XCTAssertEqual(records[0].notes, "Hello, world")
        XCTAssertEqual(records[1].notes, "She said \"hi\".")
        XCTAssertEqual(records[2].notes, "Line1\nLine2")
    }

    func testImportAcceptsCRLFLineEndings() async throws {
        let container = try TestSupport.makeInMemoryContainer()

        let csv = "Date,Status,AutoDetected,Notes\r\n2026-05-01,Holiday,false,Hi\r\n"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        try await CSVImporter.importCSV(from: url, container: container)

        let context = ModelContext(container)
        let records = try context.fetch(FetchDescriptor<DayRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].status, .holiday)
        XCTAssertEqual(records[0].notes, "Hi")
    }

    func testImportTreatsNoneAsDeletionAndDoesNotCreateRecords() async throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = ModelContext(container)
        context.insert(TestSupport.record(2026, 5, 1, status: .remote, notes: "existing"))
        try context.save()

        let csv = """
        Date,Status,AutoDetected,Notes
        2026-05-01,None,false,
        2026-05-02,None,false,
        """

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        try await CSVImporter.importCSV(from: url, container: container)

        let remaining = try context.fetch(FetchDescriptor<DayRecord>())
        XCTAssertEqual(remaining.count, 0)
    }

    func testImportSkipsUnknownStatusesInsteadOfOverwritingData() async throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = ModelContext(container)
        context.insert(TestSupport.record(2026, 5, 1, status: .inOffice, notes: "keep"))
        try context.save()

        let csv = """
        Date,Status,AutoDetected,Notes
        2026-05-01,NotARealStatus,false,evil
        """

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        try await CSVImporter.importCSV(from: url, container: container)

        let records = try context.fetch(FetchDescriptor<DayRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].status, .inOffice)
        XCTAssertEqual(records[0].notes, "keep")
    }
}

