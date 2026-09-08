import SwiftUI
import SwiftData

@main
struct FurtherApp: App {

    // ModelContainer wired to the V1 schema (D-030, D-033, D-034), backed by
    // the private CloudKit database (D-061).
    //
    // Every model already satisfies the CloudKit constraints: defaulted or
    // optional attributes, optional relationships with explicit inverses, and
    // no unique attributes (D-030).
    let modelContainer: ModelContainer
    let syncStatus: SyncStatus
    let exerciseCatalog: ExerciseCatalog
    let healthWriter: HealthKitWorkoutWriter

    init() {
        let schema = Schema(versionedSchema: SchemaV1.self)

        // Whether to sync is decided here, once, because a ModelContainer's
        // CloudKit backing is fixed at construction — the Settings toggle
        // therefore takes effect on the next launch, not immediately.
        let wantsSync = SyncStatus.syncEnabledPreference

        // Prefer the synced store; fall back to local-only rather than
        // refusing to launch. An unprovisioned container or a revoked
        // entitlement should cost sync, not the user's access to their data.
        var container: ModelContainer?
        var fallbackReason: String?

        if wantsSync {
            do {
                let cloudConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .private(SyncStatus.containerIdentifier)
                )
                container = try ModelContainer(for: schema, configurations: [cloudConfig])
            } catch {
                fallbackReason = error.localizedDescription
            }
        }

        if let container {
            modelContainer = container
            syncStatus = SyncStatus(isCloudBacked: true)
        } else {
            do {
                let localConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false
                )
                modelContainer = try ModelContainer(for: schema, configurations: [localConfig])
                syncStatus = SyncStatus(
                    isCloudBacked: false,
                    isDisabledByPreference: !wantsSync,
                    fallbackReason: fallbackReason
                )
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }

        exerciseCatalog = ExerciseCatalog()
        healthWriter = HealthKitWorkoutWriter()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(exerciseCatalog)
                .environment(syncStatus)
                .environment(healthWriter)
                .task { await syncStatus.refresh() }
        }
        .modelContainer(modelContainer)
    }
}
