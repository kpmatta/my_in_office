import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataManagementSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DayRecord.date, order: .reverse) private var records: [DayRecord]

    @State private var shareSheetItem: ExportShareItem?
    @State private var exportCleanupURL: URL?
    @State private var showingImporter = false
    @State private var showDeleteConfirmation = false
    @State private var statusMessage: String?
    @State private var activeAlert: AppAlertInfo?
    @State private var isExporting = false
    @State private var isImporting = false

    private var isBusy: Bool {
        isExporting || isImporting
    }

    var body: some View {
        Section(
            header: Text("Data Management"),
            footer: Text("Backup or restore your attendance data. Deleting data cannot be undone.")
        ) {
            HStack {
                Text("Total Records")
                Spacer()
                Text("\(records.count)")
                    .foregroundColor(.secondary)
            }

            Button(action: {
                Task {
                    await exportData()
                }
            }) {
                HStack {
                    if isExporting {
                        ProgressView()
                            .padding(.trailing, 2)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Text(isExporting ? "Preparing Backup..." : "Export Data")
                }
            }
            .disabled(records.isEmpty || isBusy)
            .sheet(item: $shareSheetItem, onDismiss: cleanupExportFile) { item in
                ActivityViewController(activityItems: [item.url])
            }

            Button(action: {
                showingImporter = true
            }) {
                HStack {
                    if isImporting {
                        ProgressView()
                            .padding(.trailing, 2)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Text(isImporting ? "Importing..." : "Import from CSV")
                }
            }
            .disabled(isBusy)
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.commaSeparatedText]) { result in
                switch result {
                case .success(let url):
                    Task {
                        await importData(from: url)
                    }
                case .failure(let error):
                    if let alert = AppUserFeedback.fileSelectionUnavailable(for: error) {
                        statusMessage = nil
                        activeAlert = alert
                        AppHaptics.error()
                    }
                }
            }

            if isBusy, let message = statusMessage {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(message)
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            } else if let message = statusMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Button(role: .destructive, action: {
                showDeleteConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete All Data")
                }
            }
            .disabled(records.isEmpty || isBusy)
            .confirmationDialog(
                "Are you sure you want to delete all data?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete All", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) { }
            }
        }
        .alert(item: $activeAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func exportData() async {
        guard !records.isEmpty else { return }

        isExporting = true
        activeAlert = nil
        statusMessage = "Preparing your backup..."

        let result = await CSVExporter.export(records: records)

        isExporting = false

        switch result {
        case .success(let url):
            exportCleanupURL = url
            shareSheetItem = ExportShareItem(url: url)
            statusMessage = "Backup ready to share."
            AppHaptics.success()
        case .failure:
            statusMessage = nil
            activeAlert = AppUserFeedback.exportUnavailable
            AppHaptics.error()
        }
    }

    private func importData(from url: URL) async {
        let container = modelContext.container

        isImporting = true
        activeAlert = nil
        statusMessage = "Importing your backup..."

        do {
            try await CSVImporter.importCSV(from: url, container: container)
            statusMessage = "Import complete. Your attendance history has been updated."
            AppHaptics.success()
        } catch let importError as CSVImporter.ImportError {
            statusMessage = nil
            activeAlert = AppUserFeedback.importUnavailable(for: importError)
            AppHaptics.error()
        } catch {
            AppDiagnostics.error("Unexpected CSV import failure", error: error)
            statusMessage = nil
            activeAlert = AppUserFeedback.importUnavailable(for: .saveFailed)
            AppHaptics.error()
        }

        isImporting = false
    }

    private func deleteAllData() {
        do {
            try modelContext.delete(model: DayRecord.self)
            try modelContext.save()
            activeAlert = nil
            statusMessage = "All attendance data has been deleted."
            AppHaptics.success()
        } catch {
            AppDiagnostics.error("Delete all data failed", error: error)
            statusMessage = nil
            activeAlert = AppUserFeedback.deleteUnavailable
            AppHaptics.error()
        }
    }

    private func cleanupExportFile() {
        guard let url = exportCleanupURL else { return }
        try? FileManager.default.removeItem(at: url)
        exportCleanupURL = nil
        shareSheetItem = nil
    }
}

private struct ExportShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
