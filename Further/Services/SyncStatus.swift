import CloudKit
import CoreData
import Foundation
import Observation

/// Reports whether this launch is actually syncing, and why not when it isn't.
///
/// SwiftData gives no direct sync-state API, so there are two things worth
/// knowing and neither is observable from the model layer alone:
///
///  1. whether the `ModelContainer` was built with CloudKit backing at all
///     (`FurtherApp` falls back to a local store if the container can't be
///     opened, rather than crashing at launch),
///  2. whether the device is signed into iCloud, and
///  3. whether the mirroring engine is actually completing its import/export
///     passes.
///
/// (3) matters more than it looks. `ModelContainer` init succeeds even when
/// CloudKit cannot work at all — setup runs asynchronously afterwards, and a
/// missing account or unprovisioned container surfaces only as a later
/// `NSPersistentCloudKitContainer` event. Without observing those events the
/// app would report "On" while syncing nothing.
///
/// All three surface in Settings. Silent non-syncing is the failure mode that
/// costs data, so the app says so out loud.
@MainActor
@Observable
final class SyncStatus {

    /// Read from Info.plist rather than hardcoded, so the identifier has a
    /// single source of truth: `FURTHER_ICLOUD_CONTAINER` in
    /// `Config/Further.xcconfig`, which also fills in the entitlement. Forking
    /// the project means editing one config file, not hunting literals.
    static let containerIdentifier: String = {
        let value = Bundle.main.object(forInfoDictionaryKey: "FurtherCloudKitContainer") as? String
        return value?.isEmpty == false ? value! : "iCloud.com.example.Further"
    }()

    /// The user's sync preference, in `UserDefaults` rather than
    /// `UserPreferences`.
    ///
    /// It must NOT live in the SwiftData store: that store is the thing being
    /// synced, so a "sync off" flag stored there would propagate the shutoff
    /// to every other device — the opposite of a per-device setting. It also
    /// has to be readable before the `ModelContainer` exists, since it decides
    /// how that container is built.
    static let syncEnabledDefaultsKey = "cloudSyncEnabled"

    /// Defaults to true: sync is the intended state, and a fresh install with
    /// no stored value should back up.
    static var syncEnabledPreference: Bool {
        UserDefaults.standard.object(forKey: syncEnabledDefaultsKey) as? Bool ?? true
    }

    /// False when opening the CloudKit-backed store failed and we fell back to
    /// local-only for this launch.
    let isCloudBacked: Bool

    /// True when this launch is local-only because the user asked for it,
    /// rather than because anything failed.
    let isDisabledByPreference: Bool

    /// Underlying error text when CloudKit was wanted but couldn't be opened.
    let fallbackReason: String?

    /// Nil until the first `refresh()` resolves.
    private(set) var accountStatus: CKAccountStatus?

    /// Most recent completed mirroring event that failed, if any.
    private(set) var lastEventError: String?

    /// When a mirroring pass last completed cleanly.
    private(set) var lastSyncedAt: Date?

    @ObservationIgnored private var eventObserver: NSObjectProtocol?

    init(
        isCloudBacked: Bool,
        isDisabledByPreference: Bool = false,
        fallbackReason: String? = nil
    ) {
        self.isCloudBacked = isCloudBacked
        self.isDisabledByPreference = isDisabledByPreference
        self.fallbackReason = fallbackReason
        if isCloudBacked {
            observeMirroringEvents()
        }
    }

    deinit {
        if let eventObserver {
            NotificationCenter.default.removeObserver(eventObserver)
        }
    }

    func refresh() async {
        guard isCloudBacked else { return }
        accountStatus = try? await CKContainer(
            identifier: Self.containerIdentifier
        ).accountStatus()
    }

    /// SwiftData runs on `NSPersistentCloudKitContainer` underneath, so its
    /// setup / import / export events are the only truthful signal that data
    /// is moving.
    private func observeMirroringEvents() {
        eventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event else { return }

            MainActor.assumeIsolated {
                self?.record(event)
            }
        }
    }

    private func record(_ event: NSPersistentCloudKitContainer.Event) {
        // Only completed events say anything; an in-flight pass is just noise.
        guard event.endDate != nil else { return }

        if let error = event.error {
            lastEventError = error.localizedDescription
        } else {
            lastEventError = nil
            lastSyncedAt = event.endDate
        }
    }

    // MARK: - Presentation

    /// One-word state for the Settings row.
    var summary: String {
        if isDisabledByPreference { return "Off" }
        guard isCloudBacked else { return "Unavailable" }
        switch accountStatus {
        case .noAccount: return "Not signed in"
        case .restricted: return "Restricted"
        case .temporarilyUnavailable: return "Unavailable"
        case .couldNotDetermine: return "Unknown"
        case .none: return "Checking…"
        case .available, .some:
            if lastEventError != nil { return "Error" }
            return lastSyncedAt == nil ? "Starting…" : "On"
        @unknown default: return "Unknown"
        }
    }

    /// True only when data is genuinely flowing to iCloud.
    var isHealthy: Bool {
        isCloudBacked && accountStatus == .available && lastEventError == nil
    }

    /// "2 minutes ago" — the timestamp of the last completed mirroring pass.
    /// This is the concrete evidence behind a green "On": a status word can be
    /// wrong, a moving timestamp cannot.
    var lastSyncedDescription: String? {
        guard let lastSyncedAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastSyncedAt, relativeTo: Date())
    }

    /// Actionable explanation, shown under the row when something is wrong.
    var explanation: String? {
        if isDisabledByPreference {
            return "Your workouts are saved on this device only. Anything already in iCloud stays there and comes back if you turn sync on again."
        }
        guard isCloudBacked else {
            let detail = fallbackReason.map { " (\($0))" } ?? ""
            return "iCloud couldn't be reached, so this session is saving to this device only\(detail). Your data is safe — keep an exported backup until sync recovers."
        }
        if let lastEventError {
            return "iCloud reported a problem: \(lastEventError) Your data is safe on this device — export a backup if this persists."
        }
        switch accountStatus {
        case .available, .none:
            return nil
        case .noAccount:
            return "Sign in to iCloud in the Settings app to sync your workouts across devices."
        case .restricted:
            return "iCloud is restricted on this device, likely by a profile or Screen Time limit."
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable. Syncing will resume on its own."
        case .couldNotDetermine:
            return "Couldn't reach iCloud. Check your network connection."
        @unknown default:
            return nil
        }
    }
}
