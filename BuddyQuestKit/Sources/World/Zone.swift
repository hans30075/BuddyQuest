import Foundation

/// A zone is a collection of related rooms with a shared theme
public final class Zone {
    public let id: String
    public let name: String
    public let subject: Subject?
    public let musicTrack: String?
    public let requiredLevel: Int
    public let requiredFlag: String?

    /// Room factory closures, keyed by room ID
    private var roomFactories: [String: () -> Room] = [:]

    /// Ordered list of room IDs in this zone
    public private(set) var roomIds: [String] = []

    public init(
        id: String,
        name: String,
        subject: Subject? = nil,
        musicTrack: String? = nil,
        requiredLevel: Int = 0,
        requiredFlag: String? = nil
    ) {
        self.id = id
        self.name = name
        self.subject = subject
        self.musicTrack = musicTrack
        self.requiredLevel = requiredLevel
        self.requiredFlag = requiredFlag
    }

    public func registerRoom(id: String, factory: @escaping () -> Room) {
        roomFactories[id] = factory
        if !roomIds.contains(id) {
            roomIds.append(id)
        }
    }

    public func createRoom(id: String) -> Room? {
        roomFactories[id]?()
    }

    public var startRoomId: String? {
        roomIds.first
    }

    public func isUnlocked(playerLevel: Int, flags: Set<String>) -> Bool {
        if playerLevel < requiredLevel { return false }
        if let flag = requiredFlag, !flags.contains(flag) { return false }
        return true
    }
}
