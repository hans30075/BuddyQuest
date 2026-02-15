import Foundation

/// Static dialogue trees for all NPCs.
/// Each dialogue has a unique ID matching the `dialogueId` in NPCSpawnDefinition.
public enum DialogueData {

    /// Registry of all dialogue by ID
    public static func dialogue(forId id: String) -> Dialogue? {
        allDialogues[id]
    }

    private static let allDialogues: [String: Dialogue] = {
        var map: [String: Dialogue] = [:]
        for d in allDialogueList {
            map[d.id] = d
        }
        return map
    }()

    private static let allDialogueList: [Dialogue] = [
        guideIntro,
        guideIntroMore,
        librarianIntro,
        forestWelcome,
        forestWillowWelcome,
        forestGuardianWelcome,
        peaksWelcome,
        peaksInfo,
        peaksCrystalSageWelcome,
        peaksSummitKeeperWelcome,
        labWelcome,
        labInfo,
        labResearcherWelcome,
        labDirectorWelcome,
        arenaWelcome,
        arenaInfo,
        arenaCaptainWelcome,
        arenaChampionWelcome,
    ]

    // MARK: - Pip the Guide (Hub Main)

    static let guideIntro = Dialogue(
        id: "guide_intro",
        lines: [
            DialogueLine(
                speaker: "Pip the Guide",
                text: "Welcome to Buddy Base! This is the heart of our world."
            ),
            DialogueLine(
                speaker: "Pip the Guide",
                text: "See those glowing portals? Each one leads to a different learning zone!"
            ),
            DialogueLine(
                speaker: "Pip the Guide",
                text: "The Word Forest is already open — just walk into the portal to enter.",
                choices: [
                    DialogueChoice(
                        text: "Tell me more about the zones!",
                        nextDialogueId: "guide_intro_more"
                    ),
                    DialogueChoice(
                        text: "I'll go explore now!",
                        nextDialogueId: nil
                    ),
                ]
            ),
        ]
    )

    static let guideIntroMore = Dialogue(
        id: "guide_intro_more",
        lines: [
            DialogueLine(
                speaker: "Pip the Guide",
                text: "The Word Forest is where you'll learn about reading and writing!"
            ),
            DialogueLine(
                speaker: "Pip the Guide",
                text: "Number Peaks will challenge your math skills — it opens at Level 3."
            ),
            DialogueLine(
                speaker: "Pip the Guide",
                text: "The Science Lab opens at Level 5, and the Teamwork Arena needs a buddy!"
            ),
            DialogueLine(
                speaker: "Pip the Guide",
                text: "Oh, and don't forget to visit the Library and Courtyard too. Good luck!"
            ),
        ]
    )

    // MARK: - Sage the Librarian (Hub Library)

    static let librarianIntro = Dialogue(
        id: "librarian_intro",
        lines: [
            DialogueLine(
                speaker: "Sage the Librarian",
                text: "Welcome to the library! Knowledge is the greatest treasure."
            ),
            DialogueLine(
                speaker: "Sage the Librarian",
                text: "Every adventure you complete earns XP and unlocks new areas."
            ),
            DialogueLine(
                speaker: "Sage the Librarian",
                text: "Speak to me again if you ever need a hint. Books always have the answers!"
            ),
        ]
    )

    // MARK: - Fern the Forest Sprite (Word Forest)

    static let forestWelcome = Dialogue(
        id: "forest_welcome",
        lines: [
            DialogueLine(
                speaker: "Fern the Forest Sprite",
                text: "You made it to the Word Forest! The trees here whisper stories..."
            ),
            DialogueLine(
                speaker: "Fern the Forest Sprite",
                text: "If you listen carefully, you can learn all sorts of wonderful words!",
                choices: [
                    DialogueChoice(
                        text: "What kind of challenges are here?",
                        nextDialogueId: "forest_challenges_info"
                    ),
                    DialogueChoice(
                        text: "This place is beautiful!",
                        nextDialogueId: nil
                    ),
                ]
            ),
        ]
    )

    // MARK: - Rocky the Calcinator (Number Peaks)

    static let peaksWelcome = Dialogue(
        id: "peaks_welcome",
        lines: [
            DialogueLine(
                speaker: "Rocky the Calcinator",
                text: "Welcome to Number Peaks! Up here, every rock holds a mathematical secret."
            ),
            DialogueLine(
                speaker: "Rocky the Calcinator",
                text: "The crystals you see grow in perfect geometric patterns — nature loves math!",
                choices: [
                    DialogueChoice(
                        text: "I'm ready for some math challenges!",
                        nextDialogueId: nil
                    ),
                    DialogueChoice(
                        text: "Tell me more about this place!",
                        nextDialogueId: "peaks_info"
                    ),
                ]
            ),
        ]
    )

    static let peaksInfo = Dialogue(
        id: "peaks_info",
        lines: [
            DialogueLine(
                speaker: "Rocky the Calcinator",
                text: "These mountains are built on numbers! Addition, subtraction, fractions, geometry..."
            ),
            DialogueLine(
                speaker: "Rocky the Calcinator",
                text: "The harder you work, the higher you'll climb. Every correct answer makes you stronger!"
            ),
            DialogueLine(
                speaker: "Rocky the Calcinator",
                text: "Ready to put your math skills to the test? Let's calculate!"
            ),
        ]
    )

    // MARK: - Professor Atom (Science Lab)

    static let labWelcome = Dialogue(
        id: "lab_welcome",
        lines: [
            DialogueLine(
                speaker: "Professor Atom",
                text: "Ah, a new scientist! Welcome to the Science Lab!"
            ),
            DialogueLine(
                speaker: "Professor Atom",
                text: "Here we observe, hypothesize, and experiment. Science is about asking questions!",
                choices: [
                    DialogueChoice(
                        text: "Let's do some experiments!",
                        nextDialogueId: nil
                    ),
                    DialogueChoice(
                        text: "What kind of science will I learn?",
                        nextDialogueId: "lab_info"
                    ),
                ]
            ),
        ]
    )

    static let labInfo = Dialogue(
        id: "lab_info",
        lines: [
            DialogueLine(
                speaker: "Professor Atom",
                text: "We cover everything! Living things, planets, the states of matter..."
            ),
            DialogueLine(
                speaker: "Professor Atom",
                text: "Chemistry, physics, biology — the whole universe is our classroom!"
            ),
            DialogueLine(
                speaker: "Professor Atom",
                text: "Remember: there are no wrong answers in science, only new experiments to try!"
            ),
        ]
    )

    // MARK: - Coach Unity (Teamwork Arena)

    static let arenaWelcome = Dialogue(
        id: "arena_welcome",
        lines: [
            DialogueLine(
                speaker: "Coach Unity",
                text: "Hey there, champ! Welcome to the Teamwork Arena!"
            ),
            DialogueLine(
                speaker: "Coach Unity",
                text: "This is where we learn to work together, solve problems, and be great friends!",
                choices: [
                    DialogueChoice(
                        text: "I want to practice teamwork!",
                        nextDialogueId: nil
                    ),
                    DialogueChoice(
                        text: "What will I learn here?",
                        nextDialogueId: "arena_info"
                    ),
                ]
            ),
        ]
    )

    static let arenaInfo = Dialogue(
        id: "arena_info",
        lines: [
            DialogueLine(
                speaker: "Coach Unity",
                text: "Here you'll learn about empathy, kindness, and working with others."
            ),
            DialogueLine(
                speaker: "Coach Unity",
                text: "Sometimes the hardest challenge is understanding how someone else feels."
            ),
            DialogueLine(
                speaker: "Coach Unity",
                text: "But that's what makes a true champion! Ready to show your team spirit?"
            ),
        ]
    )

    // MARK: - Willow the Wise (Word Forest Deep Woods)

    static let forestWillowWelcome = Dialogue(
        id: "forest_willow_welcome",
        lines: [
            DialogueLine(
                speaker: "Willow the Wise",
                text: "Ah, a traveler ventures into the Deep Woods! The stories here are ancient..."
            ),
            DialogueLine(
                speaker: "Willow the Wise",
                text: "Each leaf carries a word, each branch a sentence. Will you read them?",
                choices: [
                    DialogueChoice(
                        text: "I'm ready to learn!",
                        nextDialogueId: nil
                    ),
                    DialogueChoice(
                        text: "What can you teach me?",
                        nextDialogueId: nil
                    ),
                ]
            ),
        ]
    )

    // MARK: - Elder Oak (Word Forest Ancient Grove)

    static let forestGuardianWelcome = Dialogue(
        id: "forest_guardian_welcome",
        lines: [
            DialogueLine(
                speaker: "Elder Oak",
                text: "Welcome to the Ancient Grove, young wordsmith. Few make it this far."
            ),
            DialogueLine(
                speaker: "Elder Oak",
                text: "The language of the forest is deep and rich. Show me what you have learned."
            ),
            DialogueLine(
                speaker: "Elder Oak",
                text: "Master the words here, and the forest will forever be your friend."
            ),
        ]
    )

    // MARK: - Crystal Sage (Number Peaks Crystal Cavern)

    static let peaksCrystalSageWelcome = Dialogue(
        id: "peaks_crystal_sage_welcome",
        lines: [
            DialogueLine(
                speaker: "Crystal Sage",
                text: "The crystals in these caverns grow in mathematical patterns..."
            ),
            DialogueLine(
                speaker: "Crystal Sage",
                text: "Fibonacci spirals, geometric progressions — nature is the greatest mathematician!",
                choices: [
                    DialogueChoice(
                        text: "Show me the patterns!",
                        nextDialogueId: nil
                    ),
                    DialogueChoice(
                        text: "I love math!",
                        nextDialogueId: nil
                    ),
                ]
            ),
        ]
    )

    // MARK: - Summit Keeper (Number Peaks Summit)

    static let peaksSummitKeeperWelcome = Dialogue(
        id: "peaks_summit_keeper_welcome",
        lines: [
            DialogueLine(
                speaker: "Summit Keeper",
                text: "You have climbed far! The summit holds the greatest mathematical challenges."
            ),
            DialogueLine(
                speaker: "Summit Keeper",
                text: "Only those who truly understand numbers can conquer the peaks."
            ),
            DialogueLine(
                speaker: "Summit Keeper",
                text: "Are you ready for the ultimate test?"
            ),
        ]
    )

    // MARK: - Dr. Helix (Science Lab Research Station)

    static let labResearcherWelcome = Dialogue(
        id: "lab_researcher_welcome",
        lines: [
            DialogueLine(
                speaker: "Dr. Helix",
                text: "Welcome to the Research Station! I'm studying the building blocks of life."
            ),
            DialogueLine(
                speaker: "Dr. Helix",
                text: "Every experiment teaches us something new. Shall we discover together?",
                choices: [
                    DialogueChoice(
                        text: "Let's experiment!",
                        nextDialogueId: nil
                    ),
                    DialogueChoice(
                        text: "What are you researching?",
                        nextDialogueId: nil
                    ),
                ]
            ),
        ]
    )

    // MARK: - Director Spark (Science Lab Reactor Room)

    static let labDirectorWelcome = Dialogue(
        id: "lab_director_welcome",
        lines: [
            DialogueLine(
                speaker: "Director Spark",
                text: "Impressive — you've made it to the Reactor Room! This is where breakthroughs happen."
            ),
            DialogueLine(
                speaker: "Director Spark",
                text: "The energy in this room powers all of Buddy Base. It runs on pure knowledge!"
            ),
            DialogueLine(
                speaker: "Director Spark",
                text: "Show me your scientific mastery, and you'll earn the title of Master Scientist!"
            ),
        ]
    )

    // MARK: - Captain Rally (Teamwork Arena Training Grounds)

    static let arenaCaptainWelcome = Dialogue(
        id: "arena_captain_welcome",
        lines: [
            DialogueLine(
                speaker: "Captain Rally",
                text: "Welcome to the Training Grounds! This is where real teamwork begins."
            ),
            DialogueLine(
                speaker: "Captain Rally",
                text: "It's not about being the strongest — it's about lifting others up!",
                choices: [
                    DialogueChoice(
                        text: "I'm a team player!",
                        nextDialogueId: nil
                    ),
                    DialogueChoice(
                        text: "Teach me about teamwork!",
                        nextDialogueId: nil
                    ),
                ]
            ),
        ]
    )

    // MARK: - Champion Star (Teamwork Arena Grand Arena)

    static let arenaChampionWelcome = Dialogue(
        id: "arena_champion_welcome",
        lines: [
            DialogueLine(
                speaker: "Champion Star",
                text: "The Grand Arena! Only the most dedicated team players reach this stage."
            ),
            DialogueLine(
                speaker: "Champion Star",
                text: "A true champion knows that every person matters, every voice counts."
            ),
            DialogueLine(
                speaker: "Champion Star",
                text: "Prove your heart is as strong as your mind, and you'll be our champion!"
            ),
        ]
    )
}
