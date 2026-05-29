import XCTest
import SwiftData
@testable import InOffice

final class CSVImportExportTests: XCTestCase {
    func testExportNeutralizesSpreadsheetFormulaNotes() async throws {
        let records = [
            TestSupport.record(2026, 5, 1, status: .inOffice, notes: "=SUM(A1:A2)")
        ]

        let result = await CSVExporter.export(records: records)

        switch result {
        case .success(let url):
            defer { try? FileManager.default.removeItem(at: url) }
            let exported = try String(contentsOf: url, encoding: .utf8)
            XCTAssertTrue(exported.contains("'=SUM(A1:A2)"))
        case .failure:
            XCTFail("Expected CSV export to succeed")
        }
    }

    func testImportUpsertsRecordsAndRestoresFormulaNotes() async throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = ModelContext(container)
        let original = TestSupport.record(2026, 5, 1, status: .remote, notes: "Original")
        context.insert(original)
        try context.save()

        let csv = """
        Date,Status,AutoDetected,Notes
        2026-05-01,In Office,false,'=Planned office day
        2026-05-02,PTO,true,
        """

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        try await CSVImporter.importCSV(from: url, container: container)

        let verificationContext = ModelContext(container)
        let descriptor = FetchDescriptor<DayRecord>(sortBy: [SortDescriptor(\DayRecord.date)])
        let importedRecords = try verificationContext.fetch(descriptor)

        XCTAssertEqual(importedRecords.count, 2)
        XCTAssertEqual(importedRecords[0].status, .inOffice)
        XCTAssertEqual(importedRecords[0].notes, "=Planned office day")
        XCTAssertFalse(importedRecords[0].isAutoDetected)
        XCTAssertEqual(importedRecords[1].status, .pto)
        XCTAssertTrue(importedRecords[1].isAutoDetected)
    }

    func testImportRejectsMalformedCSV() async throws {
        let container = try TestSupport.makeInMemoryContainer()
        let csv = "Date,Status,AutoDetected,Notes\n"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            try await CSVImporter.importCSV(from: url, container: container)
            XCTFail("Expected malformed CSV import to fail")
        } catch let error as CSVImporter.ImportError {
            XCTAssertEqual(error, .invalidFormat)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
