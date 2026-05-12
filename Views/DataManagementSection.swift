import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataManagementSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [DayRecord]
    
    @State private var showingExporter = false
    @State private var exportUrl: URL? = nil
    
    @State private var showingImporter = false
    @State private var showDeleteConfirmation = false
    @State private var importMessage: String?
    
    var body: some View {
        Section(header: Text("Data Management"), footer: Text("Backup or restore your attendance data. Deleting data cannot be undone.")) {
            
            HStack {
                Text("Total Records")
                Spacer()
                Text("\(records.count)")
                    .foregroundColor(.secondary)
            }
            
            // Export Button
            Button(action: {
                if let url = CSVExporter.export(records: records) {
                    exportUrl = url
                    showingExporter = true
                } else {
                    importMessage = "Failed to generate CSV for export."
                }
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export Data")
                }
            }
            .disabled(records.isEmpty)
            .sheet(isPresented: $showingExporter, onDismiss: {
                // Cleanup temp file
                if let url = exportUrl {
                    try? FileManager.default.removeItem(at: url)
                    exportUrl = nil
                }
            }) {
                ActivityViewController(activityItems: [exportUrl ?? URL(fileURLWithPath: "")])
            }
            
            // Import Button
            Button(action: {
                showingImporter = true
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("Import from CSV")
                }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.commaSeparatedText]) { result in
                switch result {
                case .success(let url):
                    do {
                        try CSVImporter.importCSV(from: url, context: modelContext)
                        importMessage = "Import successful!"
                    } catch {
                        importMessage = "Failed to import CSV: \(error.localizedDescription)"
                    }
                case .failure(let error):
                    importMessage = "Failed to select file: \(error.localizedDescription)"
                }
            }
            
            if let message = importMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            // Delete Button
            Button(role: .destructive, action: {
                showDeleteConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete All Data")
                }
            }
            .confirmationDialog("Are you sure you want to delete all data?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete All", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
    
    private func deleteAllData() {
        do {
            try modelContext.delete(model: DayRecord.self)
            try modelContext.save()
            importMessage = "All data deleted."
        } catch {
            importMessage = "Failed to delete data: \(error.localizedDescription)"
        }
    }
}

// Helper to present UIActivityViewController
struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
