import Foundation

// MARK: - Skill Domain (maps to California education standards)

/// Fine-grained skill domain that maps to California standards.
/// Each challenge question gets tagged with one of these for parent progress reports.
///
/// Sources:
/// - Math: California Common Core State Standards for Mathematics (CCSS-M)
/// - ELA: California Common Core State Standards for ELA (CCSS-ELA)
/// - Science: Next Generation Science Standards (CA NGSS)
/// - SEL: California Transformative SEL Competencies (T-SEL)
public enum SkillDomain: String, Codable, CaseIterable, Sendable {
    // Math (CCSS-M) domains
    case countingCardinality = "Counting & Cardinality"
    case operationsAlgebraicThinking = "Operations & Algebraic Thinking"
    case numberOperationsBaseTen = "Number & Operations in Base Ten"
    case numberOperationsFractions = "Number & Operations—Fractions"
    case measurementData = "Measurement & Data"
    case geometry = "Geometry"
    case ratiosProportional = "Ratios & Proportional Relationships"
    case theNumberSystem = "The Number System"
    case expressionsEquations = "Expressions & Equations"
    case statisticsProbability = "Statistics & Probability"

    // ELA (CCSS-ELA) strands
    case readingLiterature = "Reading: Literature"
    case readingInformational = "Reading: Informational Text"
    case writing = "Writing"
    case language = "Language"
    case foundationalSkills = "Foundational Skills"

    // Science (NGSS) Disciplinary Core Ideas
    case lifeScience = "Life Science"
    case physicalScience = "Physical Science"
    case earthSpaceScience = "Earth & Space Science"
    case engineeringDesign = "Engineering Design"

    // SEL (CASEL / CA T-SEL) competencies
    case selfAwareness = "Self-Awareness"
    case selfManagement = "Self-Management"
    case socialAwareness = "Social Awareness"
    case relationshipSkills = "Relationship Skills"
    case responsibleDecisionMaking = "Responsible Decision-Making"

    /// The parent subject this domain belongs to
    public var subject: Subject {
        switch self {
        case .countingCardinality, .operationsAlgebraicThinking,
             .numberOperationsBaseTen, .numberOperationsFractions,
             .measurementData, .geometry, .ratiosProportional,
             .theNumberSystem, .expressionsEquations, .statisticsProbability:
            return .math
        case .readingLiterature, .readingInformational,
             .writing, .language, .foundationalSkills:
            return .languageArts
        case .lifeScience, .physicalScience,
             .earthSpaceScience, .engineeringDesign:
            return .science
        case .selfAwareness, .selfManagement, .socialAwareness,
             .relationshipSkills, .responsibleDecisionMaking:
            return .social
        }
    }

    /// Short abbreviated name for compact display
    public var shortName: String {
        switch self {
        case .countingCardinality: return "Counting"
        case .operationsAlgebraicThinking: return "Operations"
        case .numberOperationsBaseTen: return "Place Value"
        case .numberOperationsFractions: return "Fractions"
        case .measurementData: return "Measurement"
        case .geometry: return "Geometry"
        case .ratiosProportional: return "Ratios"
        case .theNumberSystem: return "Number System"
        case .expressionsEquations: return "Algebra"
        case .statisticsProbability: return "Statistics"
        case .readingLiterature: return "Literature"
        case .readingInformational: return "Informational"
        case .writing: return "Writing"
        case .language: return "Language"
        case .foundationalSkills: return "Phonics & Fluency"
        case .lifeScience: return "Life Science"
        case .physicalScience: return "Physical Science"
        case .earthSpaceScience: return "Earth & Space"
        case .engineeringDesign: return "Engineering"
        case .selfAwareness: return "Self-Awareness"
        case .selfManagement: return "Self-Management"
        case .socialAwareness: return "Social Awareness"
        case .relationshipSkills: return "Relationships"
        case .responsibleDecisionMaking: return "Decision-Making"
        }
    }
}

// MARK: - Standards Mapping

/// Static data mapping game subjects and grade levels to California education standards.
/// Used by the parent progress report to evaluate which skills have been covered
/// and what the child should be working on at their grade level.
public enum StandardsMapping {

    // MARK: - Expected Domains Per Grade

    /// Returns the CA standards domains expected for a given subject at a given grade level.
    /// Based on:
    /// - Math: CCSS-M domain progressions (CC for K, NF starts at 3, RP/NS/EE for 6+)
    /// - ELA: CCSS-ELA strand progressions (RF only K-5)
    /// - Science: NGSS DCIs (all four at every grade band)
    /// - SEL: CA T-SEL (all five competencies at every grade band)
    public static func expectedDomains(
        subject: Subject,
        gradeLevel: GradeLevel
    ) -> [SkillDomain] {
        let grade = gradeLevel.rawValue
        switch subject {
        case .math:
            if grade <= 2 {
                // K-2: Counting & Cardinality (K only but included for band),
                // Operations, Base Ten, Measurement, Geometry
                return [.countingCardinality, .operationsAlgebraicThinking,
                        .numberOperationsBaseTen, .measurementData, .geometry]
            } else if grade <= 5 {
                // 3-5: Operations, Base Ten, Fractions (new!), Measurement, Geometry
                return [.operationsAlgebraicThinking, .numberOperationsBaseTen,
                        .numberOperationsFractions, .measurementData, .geometry]
            } else {
                // 6-8: Ratios, Number System, Expressions & Equations,
                // Statistics & Probability, Geometry
                return [.ratiosProportional, .theNumberSystem,
                        .expressionsEquations, .statisticsProbability, .geometry]
            }

        case .languageArts:
            if grade <= 5 {
                // K-5: All strands including Foundational Skills
                return [.readingLiterature, .readingInformational,
                        .writing, .language, .foundationalSkills]
            } else {
                // 6-8: Foundational Skills no longer a separate strand
                return [.readingLiterature, .readingInformational,
                        .writing, .language]
            }

        case .science:
            // NGSS: All four DCIs at every grade band
            return [.lifeScience, .physicalScience,
                    .earthSpaceScience, .engineeringDesign]

        case .social:
            // CA T-SEL: All five competencies at every grade band
            return [.selfAwareness, .selfManagement, .socialAwareness,
                    .relationshipSkills, .responsibleDecisionMaking]
        }
    }

    // MARK: - Question Classification

    /// Classify a question's text into a SkillDomain using keyword heuristics.
    /// Returns the best-matching domain for the given subject.
    public static func classifyQuestion(
        questionText: String,
        subject: Subject
    ) -> SkillDomain {
        let text = questionText.lowercased()
        switch subject {
        case .math:
            return classifyMathDomain(text)
        case .languageArts:
            return classifyELADomain(text)
        case .science:
            return classifyScienceDomain(text)
        case .social:
            return classifySELDomain(text)
        }
    }

    // MARK: - Private Classifiers

    private static func classifyMathDomain(_ text: String) -> SkillDomain {
        // Geometry keywords
        let geometryKeywords = ["area", "perimeter", "triangle", "rectangle", "square",
                                "circle", "angle", "parallel", "perpendicular", "shape",
                                "polygon", "vertex", "vertices", "side", "edge", "face",
                                "volume", "surface area", "cone", "cylinder", "sphere",
                                "cube", "prism", "symmetry", "congruent", "similar",
                                "pythagorean", "coordinate", "transform", "reflect",
                                "rotate", "translate", "radius", "diameter", "circumference"]
        if geometryKeywords.contains(where: { text.contains($0) }) {
            return .geometry
        }

        // Fractions / Decimals
        let fractionKeywords = ["fraction", "decimal", "numerator", "denominator",
                                "mixed number", "improper", "equivalent fraction",
                                "simplify", "reduce", "common denominator",
                                "tenth", "hundredth", "thousandth"]
        if fractionKeywords.contains(where: { text.contains($0) }) {
            return .numberOperationsFractions
        }

        // Ratios & Proportional Relationships (6-8)
        let ratioKeywords = ["ratio", "proportion", "percent", "rate", "unit rate",
                             "scale", "discount", "tax", "tip", "interest",
                             "percent change", "markup", "markdown"]
        if ratioKeywords.contains(where: { text.contains($0) }) {
            return .ratiosProportional
        }

        // Expressions & Equations (6-8)
        let algebraKeywords = ["equation", "variable", "expression", "solve for",
                               "x =", "y =", "inequality", "coefficient",
                               "exponent", "power", "scientific notation",
                               "linear", "slope", "intercept", "function",
                               "system of equations"]
        if algebraKeywords.contains(where: { text.contains($0) }) {
            return .expressionsEquations
        }

        // Statistics & Probability
        let statsKeywords = ["mean", "median", "mode", "range", "average",
                             "probability", "data", "graph", "chart", "histogram",
                             "scatter plot", "box plot", "sample", "survey",
                             "random", "likelihood", "odds", "frequency"]
        if statsKeywords.contains(where: { text.contains($0) }) {
            return .statisticsProbability
        }

        // Measurement & Data
        let measurementKeywords = ["measure", "length", "width", "height", "weight",
                                   "mass", "capacity", "liter", "gallon", "ounce",
                                   "pound", "gram", "kilogram", "meter", "centimeter",
                                   "inch", "foot", "feet", "mile", "kilometer",
                                   "time", "clock", "hour", "minute", "second",
                                   "money", "dollar", "cent", "coin", "temperature",
                                   "degree", "elapsed"]
        if measurementKeywords.contains(where: { text.contains($0) }) {
            return .measurementData
        }

        // Counting & Cardinality (primarily K)
        let countingKeywords = ["count", "how many", "number of", "more than",
                                "less than", "fewer", "greater", "compare",
                                "order", "sequence", "before", "after", "between"]
        if countingKeywords.contains(where: { text.contains($0) }) {
            return .countingCardinality
        }

        // Default: Operations & Algebraic Thinking (add, subtract, multiply, divide)
        let opsKeywords = ["add", "subtract", "multiply", "divide", "plus", "minus",
                           "times", "sum", "difference", "product", "quotient",
                           "remainder", "factor", "multiple", "pattern"]
        if opsKeywords.contains(where: { text.contains($0) }) {
            return .operationsAlgebraicThinking
        }

        // Fallback
        return .numberOperationsBaseTen
    }

    private static func classifyELADomain(_ text: String) -> SkillDomain {
        // Foundational Skills (phonics, fluency, decoding)
        let foundationalKeywords = ["rhyme", "phonics", "vowel", "consonant", "syllable",
                                    "letter", "sound", "blend", "digraph", "prefix",
                                    "suffix", "decode", "fluency", "sight word",
                                    "spell", "spelling"]
        if foundationalKeywords.contains(where: { text.contains($0) }) {
            return .foundationalSkills
        }

        // Reading: Literature
        let literatureKeywords = ["story", "fiction", "poem", "poetry", "character",
                                  "plot", "setting", "theme", "simile", "metaphor",
                                  "onomatopoeia", "personification", "alliteration",
                                  "narrator", "point of view", "fairy tale", "fable",
                                  "myth", "legend", "drama", "play", "stanza",
                                  "rhyme scheme", "imagery", "symbolism", "moral",
                                  "conflict", "resolution", "climax", "protagonist"]
        if literatureKeywords.contains(where: { text.contains($0) }) {
            return .readingLiterature
        }

        // Reading: Informational Text
        let informationalKeywords = ["article", "non-fiction", "nonfiction", "report",
                                     "informational", "fact", "main idea", "detail",
                                     "evidence", "text feature", "caption", "heading",
                                     "glossary", "index", "table of contents", "diagram",
                                     "author's purpose", "argument", "claim", "source"]
        if informationalKeywords.contains(where: { text.contains($0) }) {
            return .readingInformational
        }

        // Writing
        let writingKeywords = ["write", "essay", "paragraph", "sentence", "topic sentence",
                               "conclusion", "opinion", "narrative", "persuasive",
                               "informative", "draft", "revise", "edit", "publish"]
        if writingKeywords.contains(where: { text.contains($0) }) {
            return .writing
        }

        // Default: Language (vocabulary, grammar)
        // This catches synonym, antonym, noun, verb, adjective, etc.
        return .language
    }

    private static func classifyScienceDomain(_ text: String) -> SkillDomain {
        // Life Science
        let lifeKeywords = ["plant", "animal", "cell", "organism", "ecosystem", "habitat",
                            "food chain", "food web", "photosynthesis", "insect",
                            "herbivore", "carnivore", "omnivore", "predator", "prey",
                            "reproduction", "heredity", "gene", "dna", "trait",
                            "species", "adaptation", "evolution", "fossil",
                            "bacteria", "fungus", "organ", "tissue", "population",
                            "biodiversity", "decomposer", "pollination"]
        if lifeKeywords.contains(where: { text.contains($0) }) {
            return .lifeScience
        }

        // Earth & Space Science
        let earthKeywords = ["planet", "solar system", "earth", "rock", "weather",
                             "climate", "volcano", "earthquake", "orbit", "star",
                             "moon", "sun", "season", "erosion", "weathering",
                             "mineral", "soil", "ocean", "atmosphere", "water cycle",
                             "continent", "tectonic", "glacier", "fossil fuel",
                             "renewable", "natural resource", "constellation",
                             "gravity", "tide", "hurricane", "tornado"]
        if earthKeywords.contains(where: { text.contains($0) }) {
            return .earthSpaceScience
        }

        // Engineering Design
        let engineeringKeywords = ["design", "build", "engineer", "prototype",
                                   "test", "improve", "solution", "criteria",
                                   "constraint", "technology", "invention",
                                   "innovation", "material", "structure"]
        if engineeringKeywords.contains(where: { text.contains($0) }) {
            return .engineeringDesign
        }

        // Default: Physical Science
        return .physicalScience
    }

    private static func classifySELDomain(_ text: String) -> SkillDomain {
        // Self-Awareness
        let selfAwarenessKeywords = ["feel", "emotion", "how do you feel", "feeling",
                                     "strength", "weakness", "identity", "value",
                                     "self-esteem", "confidence", "recognize",
                                     "mindful", "aware"]
        if selfAwarenessKeywords.contains(where: { text.contains($0) }) {
            return .selfAwareness
        }

        // Social Awareness
        let socialAwarenessKeywords = ["empathy", "understand", "perspective", "inclusive",
                                       "diverse", "culture", "respect", "compassion",
                                       "bias", "prejudice", "stereotype", "fairness",
                                       "equity", "community"]
        if socialAwarenessKeywords.contains(where: { text.contains($0) }) {
            return .socialAwareness
        }

        // Relationship Skills
        let relationshipKeywords = ["teamwork", "cooperation", "cooperate", "together",
                                    "communicate", "listen", "share", "friend",
                                    "conflict", "resolve", "apologize", "forgive",
                                    "collaborate", "partner", "group", "team"]
        if relationshipKeywords.contains(where: { text.contains($0) }) {
            return .relationshipSkills
        }

        // Responsible Decision-Making
        let decisionKeywords = ["decision", "responsible", "right thing", "wrong",
                                "consequence", "choice", "ethical", "integrity",
                                "honest", "rule", "safety", "risk", "problem solving"]
        if decisionKeywords.contains(where: { text.contains($0) }) {
            return .responsibleDecisionMaking
        }

        // Default: Self-Management
        return .selfManagement
    }
}
