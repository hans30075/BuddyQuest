import Foundation

// MARK: - Profile List Wrapper (for persistence)

/// Wrapper for persisting the profiles array + active profile ID
private struct ProfileStore: Codable {
    var profiles: [PlayerProfile]
    var activeProfileId: UUID?
}

// MARK: - Profile Manager

/// Manages player profiles (up to 3) with persistence.
/// Singleton accessed via `ProfileManager.shared`.
public final class ProfileManager: ObservableObject {

    public static let shared = ProfileManager()

    public static let maxProfiles = 3

    @Published public private(set) var profiles: [PlayerProfile] = []
    @Published public var activeProfileId: UUID?

    // MARK: - Derived

    public var activeProfile: PlayerProfile? {
        profiles.first { $0.id == activeProfileId }
    }

    public var canCreateProfile: Bool {
        profiles.count < Self.maxProfiles
    }

    // MARK: - Init

    private init() {
        load()
    }

    // MARK: - CRUD

    /// Create a new profile and make it active.
    /// If this is the first profile and a legacy save exists, migrate it.
    public func createProfile(_ profile: PlayerProfile) {
        guard profiles.count < Self.maxProfiles else { return }

        // Legacy migration: if this is the first profile and old save exists
        if profiles.isEmpty {
            SaveSystem.shared.migrateLegacySave(to: profile.id)
        }

        profiles.append(profile)
        activeProfileId = profile.id
        persist()
    }

    /// Update an existing profile (name, color, grade level).
    public func updateProfile(_ profile: PlayerProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index] = profile
        persist()
    }

    /// Delete a profile and its save data.
    public func deleteProfile(id: UUID) {
        profiles.removeAll { $0.id == id }
        SaveSystem.shared.deleteSave(for: id)
        AdaptiveQuestionBankManager.shared.deleteBank(for: id)
        ChallengeHistoryLog.shared.deleteHistory(for: id)

        // If we deleted the active profile, pick another or clear
        if activeProfileId == id {
            activeProfileId = profiles.first?.id
        }
        persist()
    }

    /// Set the active profile (called when a kid taps their avatar).
    public func setActive(id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        activeProfileId = id
        SaveSystem.shared.setActiveProfile(id)
        ChallengeHistoryLog.shared.setActiveProfile(id)
        persist()
    }

    // MARK: - Persistence

    private static let fileName = "buddyquest_profiles.json"

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent(Self.fileName)
    }

    private func persist() {
        let store = ProfileStore(profiles: profiles, activeProfileId: activeProfileId)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(store)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[ProfileManager] Save failed: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let store = try decoder.decode(ProfileStore.self, from: data)
            profiles = store.profiles
            activeProfileId = store.activeProfileId
            print("[ProfileManager] Loaded \(profiles.count) profile(s)")
        } catch {
            print("[ProfileManager] Load failed: \(error)")
        }
    }
}
