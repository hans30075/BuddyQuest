import Foundation

/// Static offline question bank — fallback when AI is unavailable.
/// Questions are organized by subject, difficulty, and grade level.
public enum QuestionBank {

    /// Get a random question for the given subject and difficulty.
    /// Returns nil only if no questions match the criteria.
    public static func randomQuestion(
        subject: Subject,
        difficulty: DifficultyLevel = .easy,
        gradeLevel: GradeLevel = .third
    ) -> MultipleChoiceQuestion? {
        let pool = questions(for: subject, difficulty: difficulty)
        return pool.randomElement()
    }

    /// Get all questions matching a subject and difficulty
    public static func questions(
        for subject: Subject,
        difficulty: DifficultyLevel
    ) -> [MultipleChoiceQuestion] {
        switch subject {
        case .languageArts:
            return languageArtsQuestions.filter { $0.difficulty == difficulty }
        case .math:
            return mathQuestions.filter { $0.difficulty == difficulty }
        case .science:
            return scienceQuestions.filter { $0.difficulty == difficulty }
        case .social:
            return socialQuestions.filter { $0.difficulty == difficulty }
        }
    }

    // MARK: - Language Arts Questions

    private static let languageArtsQuestions: [MultipleChoiceQuestion] = [
        // Beginner
        MultipleChoiceQuestion(
            question: "Which word rhymes with 'cat'?",
            options: ["dog", "bat", "cup", "sun"],
            correctIndex: 1,
            explanation: "'Bat' and 'cat' both end with '-at'!",
            subject: .languageArts, difficulty: .beginner, gradeLevel: .first
        ),
        MultipleChoiceQuestion(
            question: "Which word is a noun?",
            options: ["run", "happy", "tree", "quickly"],
            correctIndex: 2,
            explanation: "A noun is a person, place, or thing. 'Tree' is a thing!",
            subject: .languageArts, difficulty: .beginner, gradeLevel: .first
        ),
        MultipleChoiceQuestion(
            question: "What letter does 'apple' start with?",
            options: ["B", "A", "C", "D"],
            correctIndex: 1,
            explanation: "'Apple' starts with the letter A!",
            subject: .languageArts, difficulty: .beginner, gradeLevel: .kindergarten
        ),

        // Easy
        MultipleChoiceQuestion(
            question: "What is a synonym for 'happy'?",
            options: ["sad", "joyful", "angry", "tired"],
            correctIndex: 1,
            explanation: "A synonym means a similar word. 'Joyful' means the same as 'happy'!",
            subject: .languageArts, difficulty: .easy, gradeLevel: .second
        ),
        MultipleChoiceQuestion(
            question: "Which sentence uses correct punctuation?",
            options: ["I like cats", "I like cats.", "i like cats.", "I like cats,"],
            correctIndex: 1,
            explanation: "Sentences start with a capital letter and end with a period!",
            subject: .languageArts, difficulty: .easy, gradeLevel: .second
        ),
        MultipleChoiceQuestion(
            question: "What is the plural of 'mouse'?",
            options: ["mouses", "mice", "mouse's", "mousies"],
            correctIndex: 1,
            explanation: "'Mouse' has an irregular plural — it becomes 'mice'!",
            subject: .languageArts, difficulty: .easy, gradeLevel: .second
        ),
        MultipleChoiceQuestion(
            question: "Which word is a verb?",
            options: ["table", "beautiful", "jump", "slowly"],
            correctIndex: 2,
            explanation: "A verb is an action word. 'Jump' is something you do!",
            subject: .languageArts, difficulty: .easy, gradeLevel: .second
        ),
        MultipleChoiceQuestion(
            question: "What is the opposite of 'hot'?",
            options: ["warm", "cold", "wet", "dry"],
            correctIndex: 1,
            explanation: "An antonym is the opposite. 'Cold' is the opposite of 'hot'!",
            subject: .languageArts, difficulty: .easy, gradeLevel: .first
        ),

        // Medium
        MultipleChoiceQuestion(
            question: "Which word is an adjective in: 'The tall tree swayed gently.'?",
            options: ["tree", "swayed", "tall", "gently"],
            correctIndex: 2,
            explanation: "An adjective describes a noun. 'Tall' describes the tree!",
            subject: .languageArts, difficulty: .medium, gradeLevel: .third
        ),
        MultipleChoiceQuestion(
            question: "What does the prefix 'un-' mean?",
            options: ["again", "not", "before", "after"],
            correctIndex: 1,
            explanation: "'Un-' means 'not'. For example, 'unhappy' means 'not happy'.",
            subject: .languageArts, difficulty: .medium, gradeLevel: .third
        ),
        MultipleChoiceQuestion(
            question: "Which is a compound sentence?",
            options: [
                "I ran fast.",
                "I ran fast and won the race.",
                "Running is fun.",
                "The fast runner."
            ],
            correctIndex: 1,
            explanation: "A compound sentence joins two complete ideas with 'and', 'but', or 'or'.",
            subject: .languageArts, difficulty: .medium, gradeLevel: .fourth
        ),
        MultipleChoiceQuestion(
            question: "What type of writing tells a made-up story?",
            options: ["non-fiction", "biography", "fiction", "report"],
            correctIndex: 2,
            explanation: "Fiction is writing that comes from imagination — it tells made-up stories!",
            subject: .languageArts, difficulty: .medium, gradeLevel: .third
        ),

        // Hard
        MultipleChoiceQuestion(
            question: "Which sentence uses 'their' correctly?",
            options: [
                "Their going to the park.",
                "They put their coats away.",
                "The dog wagged their tail.",
                "Their is a cat outside."
            ],
            correctIndex: 1,
            explanation: "'Their' shows possession — it means 'belonging to them'.",
            subject: .languageArts, difficulty: .hard, gradeLevel: .fifth
        ),
        MultipleChoiceQuestion(
            question: "What is a simile?",
            options: [
                "Giving human traits to objects",
                "A comparison using 'like' or 'as'",
                "An extreme exaggeration",
                "A word that sounds like what it means"
            ],
            correctIndex: 1,
            explanation: "A simile compares two things using 'like' or 'as'. Example: 'fast as lightning'.",
            subject: .languageArts, difficulty: .hard, gradeLevel: .fifth
        ),

        // --- New Easy ---
        MultipleChoiceQuestion(
            question: "What is the past tense of 'run'?",
            options: ["runned", "ran", "running", "runs"],
            correctIndex: 1,
            explanation: "'Run' becomes 'ran' in the past tense. It's an irregular verb!",
            subject: .languageArts, difficulty: .easy, gradeLevel: .second
        ),
        MultipleChoiceQuestion(
            question: "How many vowels are in the English alphabet?",
            options: ["4", "5", "6", "7"],
            correctIndex: 1,
            explanation: "The 5 vowels are A, E, I, O, U!",
            subject: .languageArts, difficulty: .easy, gradeLevel: .first
        ),

        // --- New Medium ---
        MultipleChoiceQuestion(
            question: "What is an antonym?",
            options: ["A word that means the opposite", "A word that sounds the same", "A type of verb", "A describing word"],
            correctIndex: 0,
            explanation: "An antonym is a word with the opposite meaning. Hot and cold are antonyms!",
            subject: .languageArts, difficulty: .medium, gradeLevel: .third
        ),
        MultipleChoiceQuestion(
            question: "Which word has a silent letter?",
            options: ["knight", "cat", "dog", "fish"],
            correctIndex: 0,
            explanation: "In 'knight', the 'k' is silent! We say 'nite'.",
            subject: .languageArts, difficulty: .medium, gradeLevel: .third
        ),
        MultipleChoiceQuestion(
            question: "What is the subject in 'The dog ran fast'?",
            options: ["fast", "ran", "The dog", "quickly"],
            correctIndex: 2,
            explanation: "The subject is who or what does the action. 'The dog' is doing the running!",
            subject: .languageArts, difficulty: .medium, gradeLevel: .fourth
        ),
        MultipleChoiceQuestion(
            question: "What is a proper noun?",
            options: ["A type of verb", "A name for a specific person or place", "An adjective", "A plural word"],
            correctIndex: 1,
            explanation: "A proper noun names a specific person, place, or thing and starts with a capital letter!",
            subject: .languageArts, difficulty: .medium, gradeLevel: .third
        ),

        // --- New Hard ---
        MultipleChoiceQuestion(
            question: "Which sentence uses passive voice?",
            options: [
                "The cat chased the mouse",
                "The mouse was chased by the cat",
                "The mouse ran away",
                "Cats chase mice"
            ],
            correctIndex: 1,
            explanation: "Passive voice puts the receiver of the action first: 'The mouse was chased by the cat'.",
            subject: .languageArts, difficulty: .hard, gradeLevel: .sixth
        ),
        MultipleChoiceQuestion(
            question: "What is an onomatopoeia?",
            options: ["A word that sounds like what it means", "A figure of speech", "A type of rhyme", "A punctuation mark"],
            correctIndex: 0,
            explanation: "Onomatopoeia are words that imitate sounds, like 'buzz', 'splash', or 'bang'!",
            subject: .languageArts, difficulty: .hard, gradeLevel: .fifth
        ),
        MultipleChoiceQuestion(
            question: "What is the correct possessive form?",
            options: ["The dogs bone", "The dog's bone", "The dogs' bone", "The dogs's bone"],
            correctIndex: 1,
            explanation: "For a singular noun, add 's to show possession: the dog's bone.",
            subject: .languageArts, difficulty: .hard, gradeLevel: .fourth
        ),
        MultipleChoiceQuestion(
            question: "Which is a metaphor?",
            options: ["She is as fast as lightning", "She is a shining star", "She ran very quickly", "She was quite bright"],
            correctIndex: 1,
            explanation: "A metaphor says something IS something else. 'She is a shining star' compares directly!",
            subject: .languageArts, difficulty: .hard, gradeLevel: .fifth
        ),

        // --- New Advanced ---
        MultipleChoiceQuestion(
            question: "What is an oxymoron?",
            options: ["Two contradictory words together", "A type of poem", "A figure of repetition", "An old saying"],
            correctIndex: 0,
            explanation: "An oxymoron pairs contradictory words, like 'jumbo shrimp' or 'deafening silence'!",
            subject: .languageArts, difficulty: .advanced, gradeLevel: .seventh
        ),
        MultipleChoiceQuestion(
            question: "Which literary device is 'The wind whispered through the trees'?",
            options: ["Simile", "Metaphor", "Personification", "Alliteration"],
            correctIndex: 2,
            explanation: "Personification gives human qualities to non-human things. Wind can't actually whisper!",
            subject: .languageArts, difficulty: .advanced, gradeLevel: .sixth
        ),
    ]

    // MARK: - Math Questions

    private static let mathQuestions: [MultipleChoiceQuestion] = [
        // Beginner
        MultipleChoiceQuestion(
            question: "What is 3 + 4?",
            options: ["5", "6", "7", "8"],
            correctIndex: 2,
            explanation: "3 + 4 = 7. Count 3 and then add 4 more!",
            subject: .math, difficulty: .beginner, gradeLevel: .first
        ),
        MultipleChoiceQuestion(
            question: "Which number comes after 9?",
            options: ["8", "11", "10", "7"],
            correctIndex: 2,
            explanation: "The numbers go 8, 9, 10! So 10 comes after 9.",
            subject: .math, difficulty: .beginner, gradeLevel: .kindergarten
        ),
        MultipleChoiceQuestion(
            question: "How many sides does a triangle have?",
            options: ["2", "3", "4", "5"],
            correctIndex: 1,
            explanation: "'Tri' means three — a triangle has 3 sides!",
            subject: .math, difficulty: .beginner, gradeLevel: .kindergarten
        ),

        // Easy
        MultipleChoiceQuestion(
            question: "What is 12 - 5?",
            options: ["6", "7", "8", "5"],
            correctIndex: 1,
            explanation: "12 - 5 = 7. Start at 12 and count back 5!",
            subject: .math, difficulty: .easy, gradeLevel: .second
        ),
        MultipleChoiceQuestion(
            question: "What is 6 × 3?",
            options: ["15", "18", "21", "12"],
            correctIndex: 1,
            explanation: "6 × 3 = 18. That's 6 + 6 + 6!",
            subject: .math, difficulty: .easy, gradeLevel: .third
        ),
        MultipleChoiceQuestion(
            question: "Which fraction is bigger: 1/2 or 1/4?",
            options: ["1/4", "1/2", "They're equal", "Can't tell"],
            correctIndex: 1,
            explanation: "1/2 is bigger than 1/4. Half a pizza is more than a quarter!",
            subject: .math, difficulty: .easy, gradeLevel: .third
        ),
        MultipleChoiceQuestion(
            question: "What is 25 + 17?",
            options: ["42", "32", "43", "41"],
            correctIndex: 0,
            explanation: "25 + 17 = 42. Add the ones first: 5 + 7 = 12, carry the 1!",
            subject: .math, difficulty: .easy, gradeLevel: .second
        ),
        MultipleChoiceQuestion(
            question: "How many minutes are in one hour?",
            options: ["30", "100", "60", "45"],
            correctIndex: 2,
            explanation: "There are 60 minutes in every hour!",
            subject: .math, difficulty: .easy, gradeLevel: .second
        ),

        // Medium
        MultipleChoiceQuestion(
            question: "What is 144 ÷ 12?",
            options: ["10", "11", "12", "14"],
            correctIndex: 2,
            explanation: "144 ÷ 12 = 12. 12 × 12 = 144!",
            subject: .math, difficulty: .medium, gradeLevel: .fourth
        ),
        MultipleChoiceQuestion(
            question: "What is the area of a rectangle that is 5cm long and 3cm wide?",
            options: ["8 cm²", "15 cm²", "16 cm²", "10 cm²"],
            correctIndex: 1,
            explanation: "Area = length × width. 5 × 3 = 15 cm²!",
            subject: .math, difficulty: .medium, gradeLevel: .fourth
        ),
        MultipleChoiceQuestion(
            question: "Which number is prime?",
            options: ["4", "9", "15", "7"],
            correctIndex: 3,
            explanation: "7 is prime because it can only be divided by 1 and itself!",
            subject: .math, difficulty: .medium, gradeLevel: .fifth
        ),
        MultipleChoiceQuestion(
            question: "What is 3/4 as a decimal?",
            options: ["0.34", "0.75", "0.50", "0.25"],
            correctIndex: 1,
            explanation: "3 ÷ 4 = 0.75. Three quarters equals 0.75!",
            subject: .math, difficulty: .medium, gradeLevel: .fourth
        ),

        // Hard
        MultipleChoiceQuestion(
            question: "What is 15% of 200?",
            options: ["15", "20", "30", "25"],
            correctIndex: 2,
            explanation: "15% of 200 = 0.15 × 200 = 30.",
            subject: .math, difficulty: .hard, gradeLevel: .sixth
        ),
        MultipleChoiceQuestion(
            question: "If x + 7 = 15, what is x?",
            options: ["7", "22", "8", "6"],
            correctIndex: 2,
            explanation: "x = 15 - 7 = 8. Subtract 7 from both sides!",
            subject: .math, difficulty: .hard, gradeLevel: .sixth
        ),

        // --- New Easy ---
        MultipleChoiceQuestion(
            question: "What is 8 × 7?",
            options: ["49", "54", "56", "63"],
            correctIndex: 2,
            explanation: "8 × 7 = 56. A handy multiplication fact to memorize!",
            subject: .math, difficulty: .easy, gradeLevel: .third
        ),
        MultipleChoiceQuestion(
            question: "What shape has 6 faces, all squares?",
            options: ["Pyramid", "Cube", "Sphere", "Cylinder"],
            correctIndex: 1,
            explanation: "A cube has 6 square faces, 12 edges, and 8 corners!",
            subject: .math, difficulty: .easy, gradeLevel: .second
        ),

        // --- New Medium ---
        MultipleChoiceQuestion(
            question: "What is the perimeter of a square with side length 6 cm?",
            options: ["12 cm", "24 cm", "36 cm", "18 cm"],
            correctIndex: 1,
            explanation: "Perimeter of a square = 4 × side. 4 × 6 = 24 cm!",
            subject: .math, difficulty: .medium, gradeLevel: .fourth
        ),
        MultipleChoiceQuestion(
            question: "What is 2/3 + 1/6?",
            options: ["3/9", "5/6", "1/2", "3/6"],
            correctIndex: 1,
            explanation: "Convert 2/3 to 4/6, then 4/6 + 1/6 = 5/6!",
            subject: .math, difficulty: .medium, gradeLevel: .fourth
        ),
        MultipleChoiceQuestion(
            question: "How many degrees are in a right angle?",
            options: ["45", "90", "180", "360"],
            correctIndex: 1,
            explanation: "A right angle is exactly 90 degrees — like the corner of a square!",
            subject: .math, difficulty: .medium, gradeLevel: .fourth
        ),
        MultipleChoiceQuestion(
            question: "What is the next number: 2, 4, 8, 16, ...?",
            options: ["20", "24", "32", "18"],
            correctIndex: 2,
            explanation: "Each number doubles! 16 × 2 = 32.",
            subject: .math, difficulty: .medium, gradeLevel: .fourth
        ),

        // --- New Hard ---
        MultipleChoiceQuestion(
            question: "What is the volume of a cube with side length 3 cm?",
            options: ["9 cm³", "12 cm³", "27 cm³", "18 cm³"],
            correctIndex: 2,
            explanation: "Volume of a cube = side³. 3 × 3 × 3 = 27 cm³!",
            subject: .math, difficulty: .hard, gradeLevel: .fifth
        ),
        MultipleChoiceQuestion(
            question: "Simplify: 12/18",
            options: ["2/3", "3/4", "6/9", "4/6"],
            correctIndex: 0,
            explanation: "Divide both by their GCD (6): 12÷6 = 2, 18÷6 = 3. So 12/18 = 2/3!",
            subject: .math, difficulty: .hard, gradeLevel: .fifth
        ),
        MultipleChoiceQuestion(
            question: "A shirt costs $40 and is 25% off. What is the sale price?",
            options: ["$10", "$25", "$30", "$35"],
            correctIndex: 2,
            explanation: "25% of $40 = $10 discount. $40 - $10 = $30!",
            subject: .math, difficulty: .hard, gradeLevel: .sixth
        ),
        MultipleChoiceQuestion(
            question: "What is the value of 2⁵?",
            options: ["10", "25", "32", "64"],
            correctIndex: 2,
            explanation: "2⁵ = 2×2×2×2×2 = 32. That's 2 multiplied by itself 5 times!",
            subject: .math, difficulty: .hard, gradeLevel: .sixth
        ),

        // --- New Advanced ---
        MultipleChoiceQuestion(
            question: "What is the mean of 4, 8, 6, 10, 12?",
            options: ["6", "7", "8", "10"],
            correctIndex: 2,
            explanation: "Mean = sum ÷ count. (4+8+6+10+12) = 40. 40 ÷ 5 = 8!",
            subject: .math, difficulty: .advanced, gradeLevel: .sixth
        ),
        MultipleChoiceQuestion(
            question: "Solve: 3x - 5 = 16",
            options: ["x = 5", "x = 7", "x = 3", "x = 11"],
            correctIndex: 1,
            explanation: "Add 5 to both sides: 3x = 21. Divide by 3: x = 7!",
            subject: .math, difficulty: .advanced, gradeLevel: .seventh
        ),
    ]

    // MARK: - Science Questions

    private static let scienceQuestions: [MultipleChoiceQuestion] = [
        // Beginner
        MultipleChoiceQuestion(
            question: "Which of these is a living thing?",
            options: ["rock", "flower", "water", "cloud"],
            correctIndex: 1,
            explanation: "A flower is a living thing — it grows, needs water, and makes seeds!",
            subject: .science, difficulty: .beginner, gradeLevel: .first
        ),
        MultipleChoiceQuestion(
            question: "What do plants need to grow?",
            options: ["darkness", "sunlight and water", "only air", "sand"],
            correctIndex: 1,
            explanation: "Plants need sunlight, water, and air to grow!",
            subject: .science, difficulty: .beginner, gradeLevel: .first
        ),

        // Easy
        MultipleChoiceQuestion(
            question: "What is the closest star to Earth?",
            options: ["The Moon", "Mars", "The Sun", "Polaris"],
            correctIndex: 2,
            explanation: "The Sun is our closest star — it gives us light and warmth!",
            subject: .science, difficulty: .easy, gradeLevel: .third
        ),
        MultipleChoiceQuestion(
            question: "What state of matter is ice?",
            options: ["gas", "liquid", "solid", "plasma"],
            correctIndex: 2,
            explanation: "Ice is water in its solid state. When it melts, it becomes liquid!",
            subject: .science, difficulty: .easy, gradeLevel: .second
        ),
        MultipleChoiceQuestion(
            question: "What do we call animals that eat only plants?",
            options: ["carnivores", "omnivores", "herbivores", "insectivores"],
            correctIndex: 2,
            explanation: "Herbivores eat only plants. Cows and rabbits are herbivores!",
            subject: .science, difficulty: .easy, gradeLevel: .third
        ),
        MultipleChoiceQuestion(
            question: "How many legs does an insect have?",
            options: ["4", "6", "8", "10"],
            correctIndex: 1,
            explanation: "All insects have exactly 6 legs. Spiders have 8 — they're not insects!",
            subject: .science, difficulty: .easy, gradeLevel: .second
        ),

        // Medium
        MultipleChoiceQuestion(
            question: "What is the process by which plants make food from sunlight?",
            options: ["respiration", "digestion", "photosynthesis", "evaporation"],
            correctIndex: 2,
            explanation: "Photosynthesis uses sunlight, water, and CO₂ to make food for plants!",
            subject: .science, difficulty: .medium, gradeLevel: .fourth
        ),
        MultipleChoiceQuestion(
            question: "Which planet in our solar system is the largest?",
            options: ["Saturn", "Earth", "Mars", "Jupiter"],
            correctIndex: 3,
            explanation: "Jupiter is the largest planet — over 1,000 Earths could fit inside!",
            subject: .science, difficulty: .medium, gradeLevel: .fourth
        ),
        MultipleChoiceQuestion(
            question: "What type of rock is formed from cooled lava?",
            options: ["sedimentary", "metamorphic", "igneous", "fossil"],
            correctIndex: 2,
            explanation: "Igneous rocks form when hot melted rock (magma or lava) cools and hardens!",
            subject: .science, difficulty: .medium, gradeLevel: .fourth
        ),

        // Hard
        MultipleChoiceQuestion(
            question: "What is the chemical formula for water?",
            options: ["CO₂", "O₂", "NaCl", "H₂O"],
            correctIndex: 3,
            explanation: "Water is H₂O — two hydrogen atoms and one oxygen atom!",
            subject: .science, difficulty: .hard, gradeLevel: .sixth
        ),
        MultipleChoiceQuestion(
            question: "What force keeps planets orbiting the Sun?",
            options: ["magnetism", "friction", "gravity", "wind"],
            correctIndex: 2,
            explanation: "Gravity is the force that keeps planets in orbit around the Sun!",
            subject: .science, difficulty: .hard, gradeLevel: .fifth
        ),

        // --- New Beginner ---
        MultipleChoiceQuestion(
            question: "What color is the sky on a sunny day?",
            options: ["Green", "Blue", "Red", "Yellow"],
            correctIndex: 1,
            explanation: "The sky looks blue because of how sunlight interacts with the atmosphere!",
            subject: .science, difficulty: .beginner, gradeLevel: .kindergarten
        ),
        MultipleChoiceQuestion(
            question: "Which animal can fly?",
            options: ["Dog", "Fish", "Eagle", "Cat"],
            correctIndex: 2,
            explanation: "Eagles are birds and have wings that let them fly high in the sky!",
            subject: .science, difficulty: .beginner, gradeLevel: .kindergarten
        ),

        // --- New Easy ---
        MultipleChoiceQuestion(
            question: "What gas do humans breathe out?",
            options: ["Oxygen", "Nitrogen", "Carbon dioxide", "Helium"],
            correctIndex: 2,
            explanation: "We breathe in oxygen and breathe out carbon dioxide!",
            subject: .science, difficulty: .easy, gradeLevel: .second
        ),
        MultipleChoiceQuestion(
            question: "What is the largest organ in the human body?",
            options: ["Heart", "Brain", "Skin", "Liver"],
            correctIndex: 2,
            explanation: "Your skin is your largest organ — it covers and protects your whole body!",
            subject: .science, difficulty: .easy, gradeLevel: .third
        ),

        // --- New Medium ---
        MultipleChoiceQuestion(
            question: "What are the three states of matter?",
            options: [
                "Solid, liquid, gas",
                "Hot, warm, cold",
                "Red, blue, green",
                "Big, medium, small"
            ],
            correctIndex: 0,
            explanation: "Matter exists as solid (ice), liquid (water), or gas (steam)!",
            subject: .science, difficulty: .medium, gradeLevel: .third
        ),
        MultipleChoiceQuestion(
            question: "What part of the plant absorbs water from the soil?",
            options: ["Leaves", "Stem", "Roots", "Flowers"],
            correctIndex: 2,
            explanation: "Roots grow underground and absorb water and nutrients for the plant!",
            subject: .science, difficulty: .medium, gradeLevel: .third
        ),
        MultipleChoiceQuestion(
            question: "What causes day and night?",
            options: [
                "The Moon orbiting Earth",
                "Earth rotating on its axis",
                "The Sun moving around Earth",
                "Clouds blocking the Sun"
            ],
            correctIndex: 1,
            explanation: "Earth spins (rotates) on its axis once every 24 hours, creating day and night!",
            subject: .science, difficulty: .medium, gradeLevel: .fourth
        ),
        MultipleChoiceQuestion(
            question: "What layer of Earth do we live on?",
            options: ["Mantle", "Core", "Crust", "Atmosphere"],
            correctIndex: 2,
            explanation: "We live on the crust — the thin, outermost solid layer of Earth!",
            subject: .science, difficulty: .medium, gradeLevel: .fourth
        ),

        // --- New Hard ---
        MultipleChoiceQuestion(
            question: "What is the unit of electrical resistance?",
            options: ["Volt", "Ampere", "Ohm", "Watt"],
            correctIndex: 2,
            explanation: "The ohm (Ω) is the unit of electrical resistance, named after Georg Ohm!",
            subject: .science, difficulty: .hard, gradeLevel: .sixth
        ),
        MultipleChoiceQuestion(
            question: "Which element has the chemical symbol 'Fe'?",
            options: ["Fluorine", "Iron", "Fermium", "Francium"],
            correctIndex: 1,
            explanation: "Fe comes from 'ferrum', the Latin word for iron!",
            subject: .science, difficulty: .hard, gradeLevel: .sixth
        ),
        MultipleChoiceQuestion(
            question: "What is Newton's First Law about?",
            options: [
                "Gravity",
                "Objects in motion stay in motion",
                "Every action has a reaction",
                "Energy cannot be created or destroyed"
            ],
            correctIndex: 1,
            explanation: "Newton's First Law: an object stays at rest or in motion unless acted on by a force!",
            subject: .science, difficulty: .hard, gradeLevel: .sixth
        ),

        // --- New Advanced ---
        MultipleChoiceQuestion(
            question: "What organelle is called the 'powerhouse of the cell'?",
            options: ["Nucleus", "Ribosome", "Mitochondria", "Cell membrane"],
            correctIndex: 2,
            explanation: "Mitochondria produce ATP — the energy currency that powers the cell!",
            subject: .science, difficulty: .advanced, gradeLevel: .seventh
        ),
    ]

    // MARK: - Social Skills Questions

    private static let socialQuestions: [MultipleChoiceQuestion] = [
        // Beginner
        MultipleChoiceQuestion(
            question: "Your friend drops their books. What should you do?",
            options: ["Laugh at them", "Help them pick up the books", "Walk away", "Tell the teacher"],
            correctIndex: 1,
            explanation: "Helping others when they need it is a kind thing to do!",
            subject: .social, difficulty: .beginner, gradeLevel: .first
        ),
        MultipleChoiceQuestion(
            question: "What is a good way to say 'hello' to someone new?",
            options: ["Ignore them", "Smile and wave", "Make a face", "Run away"],
            correctIndex: 1,
            explanation: "A smile and wave is a friendly way to greet someone new!",
            subject: .social, difficulty: .beginner, gradeLevel: .kindergarten
        ),

        // Easy
        MultipleChoiceQuestion(
            question: "A classmate feels sad. What is the best thing to say?",
            options: [
                "Stop being sad!",
                "Are you okay? Do you want to talk?",
                "Just ignore them",
                "It's not a big deal."
            ],
            correctIndex: 1,
            explanation: "Asking if they're okay shows empathy — it means you care about their feelings!",
            subject: .social, difficulty: .easy, gradeLevel: .second
        ),
        MultipleChoiceQuestion(
            question: "What does 'taking turns' mean?",
            options: [
                "Doing everything yourself",
                "Letting everyone have a chance",
                "Going first always",
                "Waiting until it's too late"
            ],
            correctIndex: 1,
            explanation: "Taking turns means everyone gets a fair chance. It's a key teamwork skill!",
            subject: .social, difficulty: .easy, gradeLevel: .second
        ),
        MultipleChoiceQuestion(
            question: "You disagree with a friend. What should you do?",
            options: [
                "Yell at them",
                "Never talk to them again",
                "Listen to their side and explain yours calmly",
                "Tell everyone they're wrong"
            ],
            correctIndex: 2,
            explanation: "Good communication means listening and sharing ideas respectfully!",
            subject: .social, difficulty: .easy, gradeLevel: .third
        ),

        // Medium
        MultipleChoiceQuestion(
            question: "What is empathy?",
            options: [
                "Being the smartest person",
                "Understanding how others feel",
                "Always agreeing with everyone",
                "Ignoring your own feelings"
            ],
            correctIndex: 1,
            explanation: "Empathy means understanding and sharing the feelings of others!",
            subject: .social, difficulty: .medium, gradeLevel: .fourth
        ),
        MultipleChoiceQuestion(
            question: "In a group project, one person isn't helping. What should you do?",
            options: [
                "Do all the work yourself",
                "Tell the teacher immediately",
                "Talk to them kindly and ask how they'd like to help",
                "Leave them out of the project"
            ],
            correctIndex: 2,
            explanation: "Good teamwork starts with communication. Ask how they want to contribute!",
            subject: .social, difficulty: .medium, gradeLevel: .fourth
        ),

        // Hard
        MultipleChoiceQuestion(
            question: "A friend is being bullied by someone else. What should you do?",
            options: [
                "Join in so you don't get bullied too",
                "Stand up for them or get help from an adult",
                "Pretend you didn't see it",
                "Tell your friend it's their fault"
            ],
            correctIndex: 1,
            explanation: "Being an upstander means standing up for others or getting help from a trusted adult!",
            subject: .social, difficulty: .hard, gradeLevel: .fifth
        ),

        // --- New Beginner ---
        MultipleChoiceQuestion(
            question: "What should you say when someone gives you a gift?",
            options: ["Nothing", "Thank you", "Give me more", "I don't want it"],
            correctIndex: 1,
            explanation: "Saying 'thank you' shows gratitude and makes the other person feel appreciated!",
            subject: .social, difficulty: .beginner, gradeLevel: .kindergarten
        ),
        MultipleChoiceQuestion(
            question: "When is it your turn to speak in class?",
            options: [
                "Whenever you want",
                "When the teacher calls on you or you raise your hand",
                "When your friend is talking",
                "Never"
            ],
            correctIndex: 1,
            explanation: "Raising your hand and waiting shows respect for the teacher and classmates!",
            subject: .social, difficulty: .beginner, gradeLevel: .kindergarten
        ),

        // --- New Easy ---
        MultipleChoiceQuestion(
            question: "A new student joins your class. What should you do?",
            options: ["Ignore them", "Introduce yourself", "Make fun of them", "Tell them to go away"],
            correctIndex: 1,
            explanation: "Introducing yourself helps the new student feel welcome and included!",
            subject: .social, difficulty: .easy, gradeLevel: .second
        ),
        MultipleChoiceQuestion(
            question: "What is a good way to solve a problem with a friend?",
            options: ["Fight about it", "Ignore each other", "Talk about it calmly", "Tell everyone about it"],
            correctIndex: 2,
            explanation: "Calm communication helps friends understand each other and find solutions!",
            subject: .social, difficulty: .easy, gradeLevel: .second
        ),

        // --- New Medium ---
        MultipleChoiceQuestion(
            question: "What does it mean to be a good listener?",
            options: [
                "Wait for your turn then talk about yourself",
                "Pay attention and think about what the person is saying",
                "Look at your phone",
                "Interrupt with your own story"
            ],
            correctIndex: 1,
            explanation: "Good listening means giving your full attention and thinking about the other person's words!",
            subject: .social, difficulty: .medium, gradeLevel: .third
        ),
        MultipleChoiceQuestion(
            question: "Your team lost a game. What is the best response?",
            options: [
                "Blame your teammates",
                "Congratulate the other team and try harder next time",
                "Refuse to play again",
                "Yell at the referee"
            ],
            correctIndex: 1,
            explanation: "Good sportsmanship means being gracious in both winning and losing!",
            subject: .social, difficulty: .medium, gradeLevel: .third
        ),
        MultipleChoiceQuestion(
            question: "What is 'compromise'?",
            options: [
                "Always getting your way",
                "Finding a solution both sides can agree on",
                "Giving up completely",
                "Ignoring the problem"
            ],
            correctIndex: 1,
            explanation: "Compromise means meeting in the middle so everyone feels heard and respected!",
            subject: .social, difficulty: .medium, gradeLevel: .fourth
        ),

        // --- New Hard ---
        MultipleChoiceQuestion(
            question: "A classmate says something that hurts your feelings. What should you do?",
            options: [
                "Say something mean back",
                "Tell them calmly how their words made you feel",
                "Ignore it and never talk to them",
                "Post about it online"
            ],
            correctIndex: 1,
            explanation: "Using 'I feel' statements helps others understand the impact of their words!",
            subject: .social, difficulty: .hard, gradeLevel: .fifth
        ),
        MultipleChoiceQuestion(
            question: "What does it mean to be 'inclusive'?",
            options: [
                "Only including your best friends",
                "Making sure everyone feels welcome and included",
                "Doing everything alone",
                "Picking the best players for your team"
            ],
            correctIndex: 1,
            explanation: "Being inclusive means making sure no one is left out and everyone feels valued!",
            subject: .social, difficulty: .hard, gradeLevel: .fourth
        ),
        MultipleChoiceQuestion(
            question: "Your friend wants you to do something you know is wrong. What should you do?",
            options: [
                "Do it to keep the friendship",
                "Politely say no and explain why",
                "Never talk to them again",
                "Tell everyone what they asked"
            ],
            correctIndex: 1,
            explanation: "True friends respect your choices. Saying no takes courage but builds integrity!",
            subject: .social, difficulty: .hard, gradeLevel: .fifth
        ),

        // --- New Advanced ---
        MultipleChoiceQuestion(
            question: "What is 'constructive criticism'?",
            options: [
                "Only saying nice things",
                "Giving helpful suggestions for improvement in a kind way",
                "Pointing out everything wrong",
                "Avoiding feedback entirely"
            ],
            correctIndex: 1,
            explanation: "Constructive criticism focuses on helping someone improve while being respectful!",
            subject: .social, difficulty: .advanced, gradeLevel: .sixth
        ),
        MultipleChoiceQuestion(
            question: "Why is it important to consider different perspectives?",
            options: [
                "It isn't important",
                "It helps you understand others and make better decisions",
                "So you can prove others wrong",
                "So everyone agrees with you"
            ],
            correctIndex: 1,
            explanation: "Understanding different viewpoints helps build empathy and leads to wiser choices!",
            subject: .social, difficulty: .advanced, gradeLevel: .sixth
        ),
    ]
}
