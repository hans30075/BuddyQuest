import Foundation

/// Static quest definitions for all quests in BuddyQuest.
/// Follows the same registry pattern as DialogueData.
public enum QuestData {

    /// Look up a quest by ID
    public static func quest(forId id: String) -> QuestDefinition? {
        allQuestMap[id]
    }

    /// All quest definitions
    public static let allQuests: [QuestDefinition] = allQuestList

    private static let allQuestMap: [String: QuestDefinition] = {
        var map: [String: QuestDefinition] = [:]
        for q in allQuestList { map[q.id] = q }
        return map
    }()

    // MARK: - All Quests Registry

    private static let allQuestList: [QuestDefinition] = [
        // Tutorial chain
        tutorialStart,
        tutorialFirstChallenge,
        tutorialExplore,
        // Word Forest chain
        forestBeginnerPath,
        forestDeepWoods,
        forestMasterWordsmith,
        // Number Peaks chain
        peaksBeginnerClimb,
        peaksRidgeTrail,
        peaksSummitConquest,
        // Science Lab chain
        labFirstExperiment,
        labResearchStation,
        labMasterScientist,
        // Teamwork Arena chain
        arenaFirstTeamup,
        arenaTeamChallenge,
        arenaChampion,
    ]

    // MARK: - Tutorial Quests (Pip the Guide)

    static let tutorialStart = QuestDefinition(
        id: "tutorial_start",
        name: "Welcome, Adventurer!",
        description: "Talk to Pip the Guide to learn about Buddy Base.",
        giverNPCId: "guide_pip",
        turnInNPCId: "guide_pip",
        objectives: [
            .talkToNPC(npcId: "guide_pip")
        ],
        reward: QuestReward(xpBonus: 10)
    )

    static let tutorialFirstChallenge = QuestDefinition(
        id: "tutorial_first_challenge",
        name: "Your First Challenge",
        description: "Visit the Word Forest and complete a challenge with Fern.",
        giverNPCId: "guide_pip",
        turnInNPCId: "guide_pip",
        objectives: [
            .visitRoom(roomId: "forest_entrance"),
            .completeChallenges(subject: .languageArts, count: 1)
        ],
        reward: QuestReward(xpBonus: 25),
        prerequisiteQuestIds: ["tutorial_start"]
    )

    static let tutorialExplore = QuestDefinition(
        id: "tutorial_explore",
        name: "Explore the Base",
        description: "Visit the Library and the Courtyard to discover what Buddy Base has to offer.",
        giverNPCId: "guide_pip",
        turnInNPCId: "guide_pip",
        objectives: [
            .visitRoom(roomId: "hub_library"),
            .visitRoom(roomId: "hub_courtyard")
        ],
        reward: QuestReward(xpBonus: 20, bondPoints: 5),
        prerequisiteQuestIds: ["tutorial_first_challenge"]
    )

    // MARK: - Word Forest Quests

    static let forestBeginnerPath = QuestDefinition(
        id: "forest_beginner_path",
        name: "The Beginner's Path",
        description: "Complete 3 Language Arts challenges in the Word Forest to prove you're ready for deeper exploration.",
        giverNPCId: "forest_sprite",
        turnInNPCId: "forest_sprite",
        objectives: [
            .completeChallenges(subject: .languageArts, count: 3)
        ],
        reward: QuestReward(
            xpBonus: 30,
            unlocksFlag: "forest_middle_unlocked"
        ),
        prerequisiteQuestIds: ["tutorial_first_challenge"]
    )

    static let forestDeepWoods = QuestDefinition(
        id: "forest_deep_woods",
        name: "Deep Woods Discovery",
        description: "Explore the Deep Woods and complete challenges with Willow the Wise.",
        giverNPCId: "forest_willow",
        turnInNPCId: "forest_willow",
        objectives: [
            .visitRoom(roomId: "forest_deep"),
            .completeChallenges(subject: .languageArts, count: 3)
        ],
        reward: QuestReward(
            xpBonus: 40,
            bondPoints: 5,
            unlocksFlag: "forest_boss_unlocked"
        ),
        prerequisiteQuestIds: ["forest_beginner_path"]
    )

    static let forestMasterWordsmith = QuestDefinition(
        id: "forest_master_wordsmith",
        name: "Master Wordsmith",
        description: "Prove your mastery of Language Arts to Elder Oak in the Ancient Grove.",
        giverNPCId: "forest_guardian",
        turnInNPCId: "forest_guardian",
        objectives: [
            .completeChallenges(subject: .languageArts, count: 5),
            .reachDifficulty(subject: .languageArts, level: .medium)
        ],
        reward: QuestReward(
            xpBonus: 75,
            bondPoints: 10,
            unlocksFlag: "forest_mastered"
        ),
        prerequisiteQuestIds: ["forest_deep_woods"]
    )

    // MARK: - Number Peaks Quests

    static let peaksBeginnerClimb = QuestDefinition(
        id: "peaks_beginner_climb",
        name: "The First Ascent",
        description: "Complete 3 Math challenges at Number Peaks Base Camp to begin your climb.",
        giverNPCId: "rocky_calcinator",
        turnInNPCId: "rocky_calcinator",
        objectives: [
            .completeChallenges(subject: .math, count: 3)
        ],
        reward: QuestReward(
            xpBonus: 30,
            unlocksFlag: "peaks_middle_unlocked"
        ),
        prerequisiteLevel: 3
    )

    static let peaksRidgeTrail = QuestDefinition(
        id: "peaks_ridge_trail",
        name: "The Ridge Trail",
        description: "Navigate the Crystal Caverns and prove your math skills to the Crystal Sage.",
        giverNPCId: "peaks_crystal_sage",
        turnInNPCId: "peaks_crystal_sage",
        objectives: [
            .visitRoom(roomId: "peaks_cavern"),
            .completeChallenges(subject: .math, count: 3)
        ],
        reward: QuestReward(
            xpBonus: 40,
            bondPoints: 5,
            unlocksFlag: "peaks_boss_unlocked"
        ),
        prerequisiteQuestIds: ["peaks_beginner_climb"]
    )

    static let peaksSummitConquest = QuestDefinition(
        id: "peaks_summit_conquest",
        name: "Summit Conquest",
        description: "Reach the Summit and conquer the most challenging math problems.",
        giverNPCId: "peaks_summit_keeper",
        turnInNPCId: "peaks_summit_keeper",
        objectives: [
            .completeChallenges(subject: .math, count: 5),
            .reachDifficulty(subject: .math, level: .medium)
        ],
        reward: QuestReward(
            xpBonus: 75,
            bondPoints: 10,
            unlocksFlag: "peaks_mastered"
        ),
        prerequisiteQuestIds: ["peaks_ridge_trail"]
    )

    // MARK: - Science Lab Quests

    static let labFirstExperiment = QuestDefinition(
        id: "lab_first_experiment",
        name: "First Experiment",
        description: "Complete 3 Science challenges in the Lab Lobby to earn lab access.",
        giverNPCId: "professor_atom",
        turnInNPCId: "professor_atom",
        objectives: [
            .completeChallenges(subject: .science, count: 3)
        ],
        reward: QuestReward(
            xpBonus: 30,
            unlocksFlag: "lab_middle_unlocked"
        ),
        prerequisiteLevel: 5
    )

    static let labResearchStation = QuestDefinition(
        id: "lab_research_station",
        name: "Research Station",
        description: "Explore the Research Lab and complete experiments with Dr. Helix.",
        giverNPCId: "lab_researcher",
        turnInNPCId: "lab_researcher",
        objectives: [
            .visitRoom(roomId: "lab_research"),
            .completeChallenges(subject: .science, count: 3)
        ],
        reward: QuestReward(
            xpBonus: 40,
            bondPoints: 5,
            unlocksFlag: "lab_boss_unlocked"
        ),
        prerequisiteQuestIds: ["lab_first_experiment"]
    )

    static let labMasterScientist = QuestDefinition(
        id: "lab_master_scientist",
        name: "Master Scientist",
        description: "Complete the ultimate experiment in the Reactor Room with Director Spark.",
        giverNPCId: "lab_director",
        turnInNPCId: "lab_director",
        objectives: [
            .completeChallenges(subject: .science, count: 5),
            .reachDifficulty(subject: .science, level: .medium)
        ],
        reward: QuestReward(
            xpBonus: 75,
            bondPoints: 10,
            unlocksFlag: "lab_mastered"
        ),
        prerequisiteQuestIds: ["lab_research_station"]
    )

    // MARK: - Teamwork Arena Quests

    static let arenaFirstTeamup = QuestDefinition(
        id: "arena_first_teamup",
        name: "First Team-Up",
        description: "Complete 3 Social challenges in the Arena to show your team spirit.",
        giverNPCId: "coach_unity",
        turnInNPCId: "coach_unity",
        objectives: [
            .completeChallenges(subject: .social, count: 3)
        ],
        reward: QuestReward(
            xpBonus: 30,
            unlocksFlag: "arena_middle_unlocked"
        ),
        prerequisiteLevel: 2
    )

    static let arenaTeamChallenge = QuestDefinition(
        id: "arena_team_challenge",
        name: "Team Challenge",
        description: "Prove your teamwork skills in the Training Grounds with Captain Rally.",
        giverNPCId: "arena_captain",
        turnInNPCId: "arena_captain",
        objectives: [
            .visitRoom(roomId: "arena_training"),
            .completeChallenges(subject: .social, count: 3)
        ],
        reward: QuestReward(
            xpBonus: 40,
            bondPoints: 5,
            unlocksFlag: "arena_boss_unlocked"
        ),
        prerequisiteQuestIds: ["arena_first_teamup"]
    )

    static let arenaChampion = QuestDefinition(
        id: "arena_champion",
        name: "Arena Champion",
        description: "Become the ultimate team player in the Grand Arena.",
        giverNPCId: "arena_champion_npc",
        turnInNPCId: "arena_champion_npc",
        objectives: [
            .completeChallenges(subject: .social, count: 5),
            .reachDifficulty(subject: .social, level: .medium)
        ],
        reward: QuestReward(
            xpBonus: 75,
            bondPoints: 10,
            unlocksFlag: "arena_mastered"
        ),
        prerequisiteQuestIds: ["arena_team_challenge"]
    )
}
