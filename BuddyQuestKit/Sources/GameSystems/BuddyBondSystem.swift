import Foundation

// MARK: - Bond Level

/// The friendship tier between a player and their buddy.
/// Higher bond levels unlock new abilities.
public enum BondLevel: Int, Codable, CaseIterable, Comparable, Sendable {
    case newFriend   = 0   // 0 pts — follow, speech, basic reactions
    case goodBuddy   = 1   // 50 pts — challenge hints
    case greatBuddy  = 2   // 150 pts — +10% XP bonus
    case bestBuddy   = 3   // 300 pts — second-chance retry

    public var displayName: String {
        switch self {
        case .newFriend:  return "New Friend"
        case .goodBuddy:  return "Good Buddy"
        case .greatBuddy: return "Great Buddy"
        case .bestBuddy:  return "Best Buddy"
        }
    }

    /// Minimum bond points required for this tier
    public var pointThreshold: Int {
        switch self {
        case .newFriend:  return 0
        case .goodBuddy:  return GameConstants.bondGoodBuddyThreshold
        case .greatBuddy: return GameConstants.bondGreatBuddyThreshold
        case .bestBuddy:  return GameConstants.bondBestBuddyThreshold
        }
    }

    /// Points needed to reach the *next* tier (nil if max)
    public var pointsToNext: Int? {
        switch self {
        case .newFriend:  return GameConstants.bondGoodBuddyThreshold
        case .goodBuddy:  return GameConstants.bondGreatBuddyThreshold
        case .greatBuddy: return GameConstants.bondBestBuddyThreshold
        case .bestBuddy:  return nil
        }
    }

    public static func < (lhs: BondLevel, rhs: BondLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Determine the bond level for a given point total
    public static func level(forPoints points: Int) -> BondLevel {
        if points >= GameConstants.bondBestBuddyThreshold { return .bestBuddy }
        if points >= GameConstants.bondGreatBuddyThreshold { return .greatBuddy }
        if points >= GameConstants.bondGoodBuddyThreshold { return .goodBuddy }
        return .newFriend
    }
}

// MARK: - Buddy Bond Data (per-buddy persistent data)

/// Tracks the bond progress with a single buddy. Stored in the save file.
public struct BuddyBondData: Codable {
    public var totalPoints: Int
    public var interactionCooldownDate: Date?
    public var tileWalkAccumulator: Double

    public init(
        totalPoints: Int = 0,
        interactionCooldownDate: Date? = nil,
        tileWalkAccumulator: Double = 0
    ) {
        self.totalPoints = totalPoints
        self.interactionCooldownDate = interactionCooldownDate
        self.tileWalkAccumulator = tileWalkAccumulator
    }

    public var bondLevel: BondLevel {
        BondLevel.level(forPoints: totalPoints)
    }

    /// Progress fraction toward the next bond level (0.0 – 1.0)
    public var progressToNext: Double {
        let current = bondLevel
        guard let nextThreshold = current.pointsToNext else { return 1.0 }
        let base = current.pointThreshold
        let range = nextThreshold - base
        guard range > 0 else { return 1.0 }
        return Double(totalPoints - base) / Double(range)
    }
}

// MARK: - Buddy Bond System

/// Manages bond data for all buddies and the active buddy selection.
/// Owned by GameEngine, persisted through SaveSystem.
public final class BuddyBondSystem: ObservableObject {

    @Published public var bonds: [BuddyType: BuddyBondData] = [:]
    @Published public var activeBuddyType: BuddyType = .lexie

    public init() {
        // Initialize default bond data for all buddies
        for buddy in BuddyType.allCases {
            bonds[buddy] = BuddyBondData()
        }
    }

    // MARK: - Queries

    public func bondData(for buddy: BuddyType) -> BuddyBondData {
        bonds[buddy] ?? BuddyBondData()
    }

    public func bondLevel(for buddy: BuddyType) -> BondLevel {
        bondData(for: buddy).bondLevel
    }

    public func totalPoints(for buddy: BuddyType) -> Int {
        bondData(for: buddy).totalPoints
    }

    // MARK: - Bond Point Mutation

    /// Add bond points to a buddy. Returns the new BondLevel if the buddy leveled up, nil otherwise.
    @discardableResult
    public func addPoints(_ points: Int, to buddy: BuddyType) -> BondLevel? {
        var data = bondData(for: buddy)
        let oldLevel = data.bondLevel
        data.totalPoints += points
        bonds[buddy] = data
        let newLevel = data.bondLevel
        return newLevel > oldLevel ? newLevel : nil
    }

    // MARK: - E-Key Interaction

    /// Whether the interaction cooldown has elapsed for this buddy
    public func canInteract(with buddy: BuddyType) -> Bool {
        guard let cooldown = bondData(for: buddy).interactionCooldownDate else { return true }
        return Date() >= cooldown
    }

    /// Record an E-key interaction: set cooldown, award bond points.
    /// Returns the new BondLevel if the buddy leveled up, nil otherwise.
    @discardableResult
    public func recordInteraction(with buddy: BuddyType) -> BondLevel? {
        var data = bondData(for: buddy)
        data.interactionCooldownDate = Date().addingTimeInterval(GameConstants.bondInteractionCooldown)
        bonds[buddy] = data
        return addPoints(GameConstants.bondPointsPerInteraction, to: buddy)
    }

    // MARK: - Walking

    /// Record walking distance. Awards bond point(s) when accumulator crosses threshold.
    /// Returns the new BondLevel if the buddy leveled up, nil otherwise.
    @discardableResult
    public func recordWalking(tiles: Double, for buddy: BuddyType) -> BondLevel? {
        var data = bondData(for: buddy)
        data.tileWalkAccumulator += tiles
        var levelUp: BondLevel? = nil
        while data.tileWalkAccumulator >= GameConstants.bondWalkTileThreshold {
            data.tileWalkAccumulator -= GameConstants.bondWalkTileThreshold
            let oldLevel = data.bondLevel
            data.totalPoints += GameConstants.bondPointsPerWalk
            let newLevel = data.bondLevel
            if newLevel > oldLevel {
                levelUp = newLevel
            }
        }
        bonds[buddy] = data
        return levelUp
    }

    // MARK: - Buddy Switching

    public func switchBuddy(to buddy: BuddyType) {
        activeBuddyType = buddy
    }

    // MARK: - Ability Checks

    public func hasHintAbility(for buddy: BuddyType) -> Bool {
        bondLevel(for: buddy) >= .goodBuddy
    }

    public func xpBonusMultiplier(for buddy: BuddyType) -> Double {
        bondLevel(for: buddy) >= .greatBuddy
            ? (1.0 + GameConstants.bondXPBonusFraction)
            : 1.0
    }

    public func hasSecondChance(for buddy: BuddyType) -> Bool {
        bondLevel(for: buddy) >= .bestBuddy
    }

    // MARK: - Persistence Helpers

    /// Export bonds to a dictionary keyed by BuddyType.rawValue (for SaveData)
    public func exportBonds() -> [String: BuddyBondData] {
        var out: [String: BuddyBondData] = [:]
        for (type, data) in bonds {
            out[type.rawValue] = data
        }
        return out
    }

    /// Import bonds from a dictionary (from SaveData)
    public func importBonds(_ dict: [String: BuddyBondData]) {
        for (key, data) in dict {
            if let type = BuddyType(rawValue: key) {
                bonds[type] = data
            }
        }
    }
}
