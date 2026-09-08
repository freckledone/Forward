import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Settings sheet (D-019). Presented from the gear icon in the Workouts tab.
///
/// V1 surface:
///   - Weight units (kg ↔ lb, D-004 display-only conversion)
///   - iCloud sync status (D-061)
///   - Apple Health mirroring (D-028)
///   - Data (JSON backup export / restore)
///   - About (credits, license)
///
/// UserPreferences is a singleton by convention (D-030 §3.4). We fetch it and
/// create it lazily on first read.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Environment(SyncStatus.self) private var syncStatus
    @Environment(HealthKitWorkoutWriter.self) private var healthWriter

    /// Device-local, and read before the ModelContainer exists — see
    /// `SyncStatus.syncEnabledDefaultsKey` for why this isn't in
    /// `UserPreferences`.
    @AppStorage(SyncStatus.syncEnabledDefaultsKey) private var syncEnabled = true

    @Query private var prefsList: [UserPreferences]

    @State private var exportDocument: ArchiveFile?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var resultTitle = ""
    @State private var resultMessage = ""
    @State private var showingResult = false

    /// The singleton, created lazily on first access.
    private var prefs: UserPreferences {
        if let existing = prefsList.first { return existing }
        let created = UserPreferences()
        modelContext.insert(created)
        return created
    }

    var body: some View {
        NavigationStack {
            Form {
                unitsSection
                syncSection
                healthSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: Self.backupFilename()
        ) { result in
            if case .failure(let error) = result {
                present(title: "Export Failed", message: error.localizedDescription)
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json]
        ) { result in
            handleImport(result)
        }
        .alert(resultTitle, isPresented: $showingResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resultMessage)
        }
    }

    // MARK: - Sync

    /// Silent non-syncing is the failure mode that costs data, so the state is
    /// stated plainly and a problem explains itself rather than just reading
    /// "Off".
    private var syncSection: some View {
        Section {
            Toggle(isOn: $syncEnabled) {
                Label("iCloud Sync", systemImage: "arrow.triangle.2.circlepath.icloud")
            }

            if restartRequired {
                Label(
                    syncEnabled
                        ? "Restart Further to start syncing."
                        : "Restart Further to stop syncing.",
                    systemImage: "arrow.clockwise"
                )
                .font(.footnote)
                .foregroundStyle(Color.orange)
            } else {
                HStack {
                    Text("Status")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(syncStatus.summary)
                        .foregroundStyle(syncStatus.isHealthy ? .secondary : Color.orange)
                }
                .font(.footnote)

                if let synced = syncStatus.lastSyncedDescription {
                    HStack {
                        Text("Last activity")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(synced)
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                }
            }
        } footer: {
            if let explanation = syncStatus.explanation, !restartRequired {
                Text(explanation)
            } else {
                Text("Workouts and history sync automatically to your other devices through your private iCloud database. Nothing is sent to any other server. Turning sync off never deletes anything — it only stops this device from sending and receiving changes.")
            }
        }
    }

    /// The toggle sets a preference; the container that honours it is built at
    /// launch. When the two disagree we say so, rather than letting the switch
    /// imply a state that isn't running. A failed CloudKit connection is a
    /// different problem and reports itself through `explanation` instead.
    private var restartRequired: Bool {
        syncEnabled != syncStatus.isCloudBacked && syncStatus.fallbackReason == nil
    }

    // MARK: - Apple Health (D-028)

    private var healthSection: some View {
        Section {
            Toggle(isOn: healthBinding) {
                Label("Apple Health", systemImage: "heart.fill")
            }
            .disabled(!healthWriter.isAvailable)

            if prefs.healthKitEnabled, healthWriter.isDenied {
                Label(
                    "Permission denied — enable Further in Settings › Health › Data Access & Devices.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.footnote)
                .foregroundStyle(Color.orange)
            }
        } header: {
            Text("Apple Health")
        } footer: {
            Text(healthWriter.isAvailable
                 ? "Finished workouts are added to Health as strength training, so they count toward your Activity rings. Further only writes — it never reads your health data, and it doesn't estimate calories."
                 : "Apple Health isn't available on this device.")
        }
    }

    /// Turning the toggle on asks for permission immediately, because that's
    /// the moment the user expressed the intent. D-028's "ask at first End
    /// Workout" still applies on devices that inherited the preference over
    /// iCloud without ever being asked.
    private var healthBinding: Binding<Bool> {
        Binding(
            get: { prefs.healthKitEnabled },
            set: { newValue in
                prefs.healthKitEnabled = newValue
                guard newValue else { return }
                Task { _ = try? await healthWriter.requestAuthorization() }
            }
        )
    }

    // MARK: - Data

    private var dataSection: some View {
        Section {
            Button {
                startExport()
            } label: {
                Label("Export Backup", systemImage: "square.and.arrow.up")
            }
            Button {
                showingImporter = true
            } label: {
                Label("Import Backup", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Export writes every program, workout, and logged session to a JSON file. Importing adds anything the file contains that isn't already here — it never overwrites or deletes what you have, so importing the same file twice is harmless.")
        }
    }

    private static func backupFilename() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "Further-Backup-\(formatter.string(from: Date()))"
    }

    private func startExport() {
        do {
            let data = try DataArchive.export(from: modelContext)
            exportDocument = ArchiveFile(data: data)
            showingExporter = true
        } catch {
            present(title: "Export Failed", message: error.localizedDescription)
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            present(title: "Import Failed", message: error.localizedDescription)

        case .success(let url):
            // Files chosen through the picker live outside the app sandbox.
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            do {
                let data = try Data(contentsOf: url)
                let document = try DataArchive.decode(data)
                let summary = try DataArchive.importArchive(document, into: modelContext)
                present(
                    title: summary.addedAnything ? "Import Complete" : "Nothing to Import",
                    message: summary.description
                )
            } catch {
                present(title: "Import Failed", message: error.localizedDescription)
            }
        }
    }

    private func present(title: String, message: String) {
        resultTitle = title
        resultMessage = message
        showingResult = true
    }

    // MARK: - Units

    private var unitsSection: some View {
        Section {
            Picker(
                "Weight units",
                selection: Binding(
                    get: { prefs.unit },
                    set: { prefs.unit = $0 }
                )
            ) {
                Text("Kilograms").tag(DisplayUnit.kg)
                Text("Pounds").tag(DisplayUnit.lb)
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Weight units")
        } footer: {
            Text("Weights are stored in kilograms and converted for display. Switching units never changes your logged numbers.")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            HStack {
                Text("License")
                Spacer()
                Text("MIT")
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .top) {
                Text("Exercise data")
                Spacer()
                Text("Free Exercise DB · Unlicense")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (short, build) {
        case let (s?, b?): return "\(s) (\(b))"
        case let (s?, nil): return s
        default: return "—"
        }
    }
}

/// Minimal `FileDocument` wrapper so `.fileExporter` can hand the system a
/// blob of already-encoded JSON. Read support exists only to satisfy the
/// protocol — imports go through `.fileImporter` and `DataArchive.decode`.
struct ArchiveFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
