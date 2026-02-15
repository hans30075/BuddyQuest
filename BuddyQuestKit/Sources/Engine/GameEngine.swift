import Foundation
import SpriteKit

/// The core SpriteKit scene that runs the game loop.
/// Manages all game subsystems and dispatches updates based on the current GameState.
public final class GameEngine: SKScene {

    // MARK: - Subsystems
    public let inputManager = InputManager()
    public let cameraController = CameraController()
    public let collisionSystem = CollisionSystem()
    public let worldManager = WorldManager()
    public let stateManager = GameStateManager()
    public let dialogueSystem = DialogueSystem()
    public let challengeEngine = ChallengeEngine()
    public let progressionSystem = ProgressionSystem()
    public let questSystem = QuestSystem()

    // MARK: - Entities
    public private(set) var player: PlayerCharacter!
    public private(set) var activeBuddy: BuddyCharacter?
    public let bondSystem = BuddyBondSystem()

    // MARK: - HUD
    private var hudNode: SKNode!
    private var xpBarBackground: SKShapeNode!
    private var xpBarFill: SKShapeNode!
    private var levelBadge: SKShapeNode!
    private var levelLabel: SKLabelNode!
    private var xpLabel: SKLabelNode!
    private var lastDisplayedLevel: Int = 1
    private var buddyBadge: SKNode?
    private var buddyBadgeSprite: SKSpriteNode?
    private var bondHUDNode: SKNode?
    private var bondHUDProgressBg: SKShapeNode?
    private var bondHUDProgressFill: SKShapeNode?
    private var bondHeartLabel: SKLabelNode?

    // MARK: - Profile
    /// The active player's grade level (set from profile before scene loads)
    public var gradeLevel: GradeLevel = .third

    // MARK: - State
    private var lastUpdateTime: TimeInterval = 0
    private var isInitialized = false
    private var lastPlayerPosition: CGPoint = .zero
    private var questMarkerRefreshTimer: TimeInterval = 0

    /// Set to true on first launch when no buddy has been selected yet
    public var needsInitialBuddySelection: Bool = false
    /// Set to true when buddy badge is tapped — observed by SwiftUI to open buddy select sheet
    @Published public var buddySelectRequested: Bool = false

    // MARK: - Lifecycle

    public override func didMove(to view: SKView) {
        super.didMove(to: view)

        guard !isInitialized else { return }
        isInitialized = true

        backgroundColor = .black
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        // Ensure the SKView has keyboard focus immediately on macOS
        #if os(macOS)
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        #endif

        // Set up camera
        camera = cameraController.cameraNode
        addChild(cameraController.cameraNode)
        cameraController.viewportSize = size

        // Create player
        player = PlayerCharacter()
        worldManager.worldNode.addChild(player.node)

        // Add world node to scene
        addChild(worldManager.worldNode)

        // Configure world manager
        worldManager.configure(
            collisionSystem: collisionSystem,
            cameraController: cameraController,
            player: player
        )

        // Show room name banner on room transitions
        worldManager.onRoomLoaded = { [weak self] room in
            guard let self = self else { return }
            self.showRoomNameBanner(room.name)
            // Record room visit for quest objectives
            self.questSystem.recordRoomVisit(roomId: room.id)
            // Refresh NPC quest markers for this room
            self.worldManager.updateNPCQuestMarkers(questSystem: self.questSystem, playerLevel: self.player.level)
            // Buddy reacts to zone changes
            if let zoneName = self.worldManager.currentZoneId,
               zoneName != "buddy_base" {
                self.activeBuddy?.reactZoneEnter(zoneName: zoneName.replacingOccurrences(of: "_", with: " ").capitalized)
            }
        }

        // Set up dialogue system callbacks
        dialogueSystem.onDialogueComplete = { [weak self] in
            guard let self = self else { return }

            // Record NPC talk for quest objectives
            if let npc = self.worldManager.nearestInteractableNPC() {
                self.questSystem.recordNPCTalk(npcId: npc.id)

                // Check completable quests first (turn-in)
                let completable = self.questSystem.completableQuestsForNPC(npc.id)
                for quest in completable {
                    if let reward = self.questSystem.completeQuest(quest.id) {
                        self.applyQuestReward(reward)
                        self.showQuestCompleteBanner(quest)
                    }
                }

                // Check for new quests to accept
                let available = self.questSystem.questsForNPC(
                    npc.id,
                    playerLevel: self.player.level,
                    flags: self.worldManager.gameFlags
                )
                for quest in available {
                    self.questSystem.acceptQuest(quest.id)
                    self.showQuestAcceptBanner(quest)
                }

                // Refresh NPC markers after quest changes
                self.worldManager.updateNPCQuestMarkers(
                    questSystem: self.questSystem,
                    playerLevel: self.player.level
                )

                // After quest handling, check if NPC should trigger a challenge
                if npc.givesChallenge {
                    self.startChallengeFromNPC(npc)
                } else {
                    self.stateManager.transition(to: .playing)
                }
            } else {
                self.stateManager.transition(to: .playing)
            }
        }
        dialogueSystem.onRequestDialogue = { id in
            DialogueData.dialogue(forId: id)
        }

        // Set up challenge engine callbacks
        challengeEngine.onChallengeComplete = { [weak self] result in
            guard let self = self else { return }

            // Award bond points for each question
            let activeBuddy = self.bondSystem.activeBuddyType
            var bondLevelUp: BondLevel? = nil
            if let roundChallenge = self.challengeEngine.currentChallenge as? RoundChallenge {
                for wasCorrect in roundChallenge.perQuestionResults {
                    let pts = wasCorrect
                        ? GameConstants.bondPointsPerCorrect
                        : GameConstants.bondPointsPerWrong
                    if let newLevel = self.bondSystem.addPoints(pts, to: activeBuddy) {
                        bondLevelUp = newLevel
                    }
                }

                // Subject match bonus
                if let zoneId = self.worldManager.currentZoneId {
                    let challengeSubject = self.progressionSystem.subjectForZone(zoneId)
                    if activeBuddy.subject == challengeSubject {
                        if let newLevel = self.bondSystem.addPoints(GameConstants.bondSubjectMatchBonus, to: activeBuddy) {
                            bondLevelUp = newLevel
                        }
                    }
                }
            }

            // Apply XP bonus from Great Buddy tier
            let xpMultiplier = self.bondSystem.xpBonusMultiplier(for: activeBuddy)
            let finalXP = Int(Double(result.xpAwarded) * xpMultiplier)
            self.player.addXP(finalXP)

            // Record per-question results for difficulty adaptation
            if let zoneId = self.worldManager.currentZoneId,
               let roundChallenge2 = self.challengeEngine.currentChallenge as? RoundChallenge {
                let subject = self.progressionSystem.subjectForZone(zoneId)
                self.progressionSystem.recordResults(
                    subject: subject,
                    results: roundChallenge2.perQuestionResults
                )
            }

            // Record challenge completion for quest objectives
            if let zoneId = self.worldManager.currentZoneId {
                let challengeSubject = self.progressionSystem.subjectForZone(zoneId)
                self.questSystem.recordChallengeComplete(subject: challengeSubject)
                let currentDiff = self.progressionSystem.subjectDifficulty[challengeSubject] ?? .easy
                self.questSystem.recordDifficultyReached(subject: challengeSubject, level: currentDiff)
            }

            // Buddy reaction (based on overall round result)
            if result.isCorrect {
                self.activeBuddy?.reactCorrect()
            } else {
                self.activeBuddy?.reactIncorrect()
            }

            // Bond level-up celebration
            if let newLevel = bondLevelUp {
                self.showBondLevelUpCelebration(buddyType: activeBuddy, newLevel: newLevel)
                self.activeBuddy?.reactBondLevelUp(level: newLevel)
            }

            // Auto-save after each challenge round
            self.saveGame()

            // Record results in adaptive question bank and trigger background replenishment
            if let zoneId = self.worldManager.currentZoneId,
               let roundChallenge3 = self.challengeEngine.currentChallenge as? RoundChallenge {
                let subject = self.progressionSystem.subjectForZone(zoneId)
                let difficulty = self.progressionSystem.subjectDifficulty[subject] ?? .easy

                // Record results in adaptive bank (MC questions matched; non-MC tracked by subject)
                AdaptiveQuestionBankManager.shared.recordResults(
                    subject: subject,
                    questions: roundChallenge3.allRoundQuestions,
                    results: roundChallenge3.perQuestionResults
                )

                // Background AI replenishment (non-blocking)
                AdaptiveQuestionBankManager.shared.replenishAfterQuiz(
                    subject: subject,
                    difficulty: difficulty,
                    gradeLevel: self.gradeLevel,
                    quizResults: roundChallenge3.perQuestionResults
                )

                // Log per-question history for parent progress reports (universal Question type)
                ChallengeHistoryLog.shared.logChallengeRound(
                    subject: subject,
                    questions: roundChallenge3.allRoundQuestions,
                    results: roundChallenge3.perQuestionResults
                )
            }
        }
        challengeEngine.onChallengeDismissed = { [weak self] in
            self?.stateManager.transition(to: .playing)
        }

        // Set up HUD
        setupHUD()

        // Register zones
        registerAllZones()

        // Load saved game or start fresh
        stateManager.transition(to: .playing)

        if let saveData = SaveSystem.shared.load() {
            // Restore player/progression state from save
            SaveSystem.shared.apply(
                saveData,
                to: player,
                worldManager: worldManager,
                progressionSystem: progressionSystem,
                questSystem: questSystem
            )

            // Restore bond data
            if let savedBonds = saveData.buddyBonds {
                bondSystem.importBonds(savedBonds)
            }
            if let savedBuddyRaw = saveData.activeBuddyType,
               let savedBuddyType = BuddyType(rawValue: savedBuddyRaw) {
                bondSystem.switchBuddy(to: savedBuddyType)
            } else {
                // Saved game but no buddy chosen yet — prompt selection
                needsInitialBuddySelection = true
            }

            // Sync HUD level so restored level doesn't trigger a false level-up celebration
            lastDisplayedLevel = player.level

            // Migrate quest system for saves that predate the quest system
            if saveData.questData == nil {
                migrateQuestsForExistingSave()
            }

            // Resume at saved location
            worldManager.loadRoom(
                zoneId: saveData.currentZoneId,
                roomId: saveData.currentRoomId,
                scene: self
            )
        } else {
            // Fresh game — start at hub, prompt buddy selection
            needsInitialBuddySelection = true
            // Start tutorial quest chain
            questSystem.acceptQuest("tutorial_start")
            worldManager.loadRoom(
                zoneId: "buddy_base",
                roomId: "hub_main",
                scene: self
            )
        }

        // Initialize adaptive question bank for the active profile
        if let profileId = ProfileManager.shared.activeProfileId {
            AdaptiveQuestionBankManager.shared.setActiveProfile(profileId)
            // Pre-seed all subject banks in background so first quiz has no wait
            let difficulty = progressionSystem.subjectDifficulty[.math] ?? .easy
            AdaptiveQuestionBankManager.shared.seedAllSubjectsIfNeeded(
                difficulty: difficulty,
                gradeLevel: gradeLevel
            )
        }

        // Spawn buddy based on bondSystem's active buddy type
        spawnBuddy(type: bondSystem.activeBuddyType)

        // Update HUD to reflect loaded state
        updateHUD()

        // Listen for app background/quit save requests
        NotificationCenter.default.addObserver(
            forName: .buddyQuestShouldSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveGame()
        }
    }

    // MARK: - Save

    /// Save current game state to disk
    public func saveGame() {
        SaveSystem.shared.save(
            player: player,
            worldManager: worldManager,
            progressionSystem: progressionSystem,
            activeBuddyType: bondSystem.activeBuddyType,
            unlockedBuddies: BuddyType.allCases,  // All buddies available from start
            bondSystem: bondSystem,
            questSystem: questSystem
        )
        // Also persist the adaptive question bank
        AdaptiveQuestionBankManager.shared.saveBank()
    }

    // MARK: - Zone Registration

    private func registerAllZones() {
        worldManager.registerZone(BuddyBaseZone.create())
        worldManager.registerZone(WordForestZone.create())
        worldManager.registerZone(NumberPeaksZone.create())
        worldManager.registerZone(ScienceLabZone.create())
        worldManager.registerZone(TeamworkArenaZone.create())
    }

    // MARK: - Buddy Management

    /// Spawn a buddy of the given type, removing any existing buddy
    private func spawnBuddy(type: BuddyType) {
        // Remove existing buddy
        activeBuddy?.node.removeFromParent()
        activeBuddy = nil

        let buddy = BuddyCharacter(type: type)
        worldManager.worldNode.addChild(buddy.node)
        activeBuddy = buddy

        // Position near player
        buddy.position = CGPoint(
            x: player.position.x - GameConstants.buddyFollowDistance,
            y: player.position.y
        )
    }

    /// Switch the active buddy — called from UI (pause menu buddy select)
    public func switchBuddy(to type: BuddyType) {
        bondSystem.switchBuddy(to: type)
        spawnBuddy(type: type)
        saveGame()
    }

    // MARK: - Game Loop

    public override func update(_ currentTime: TimeInterval) {
        // Calculate delta time
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let deltaTime = min(currentTime - lastUpdateTime, GameConstants.maxDeltaTime)
        lastUpdateTime = currentTime

        // Update input state
        inputManager.update()

        // Dispatch update based on game state
        switch stateManager.currentState {
        case .playing:
            updatePlaying(deltaTime: deltaTime)
        case .dialogue:
            updateDialogue(deltaTime: deltaTime)
        case .challenge:
            updateChallenge(deltaTime: deltaTime)
        case .questLog:
            updateQuestLog()
        case .paused:
            break // No updates while paused
        case .transition:
            break // Transition is handled by WorldManager's SKActions
        case .title:
            break
        default:
            break
        }
    }

    // MARK: - Playing State

    private func updatePlaying(deltaTime: TimeInterval) {
        let input = inputManager.state

        // Player movement
        player.update(
            deltaTime: deltaTime,
            input: input,
            collisionSystem: collisionSystem
        )

        // Camera following
        cameraController.target = player.node
        cameraController.update(deltaTime: deltaTime)

        // World updates (includes NPCs)
        worldManager.update(deltaTime: deltaTime)

        // Update buddy
        activeBuddy?.update(deltaTime: deltaTime, playerPosition: player.position)

        // Track walking distance for bond points
        let dist = player.position.distance(to: lastPlayerPosition)
        if dist > 1 {
            let tilesWalked = Double(dist / GameConstants.tileSize)
            if let newLevel = bondSystem.recordWalking(tiles: tilesWalked, for: bondSystem.activeBuddyType) {
                showBondLevelUpCelebration(buddyType: bondSystem.activeBuddyType, newLevel: newLevel)
                activeBuddy?.reactBondLevelUp(level: newLevel)
            }
        }
        lastPlayerPosition = player.position

        // Auto-enter doors when player walks onto them
        if worldManager.checkPlayerOnDoor(scene: self) {
            return  // Door triggered, skip rest of frame
        }

        // Check interactions (E key for NPCs, chests, etc.)
        if input.isPressed(.interact) {
            handleInteraction()
        }

        // Check pause (P key or ESC key)
        if input.isPressed(.pause) || input.isPressed(.cancel) {
            stateManager.transition(to: .paused)
        }

        // Check inventory
        if input.isPressed(.inventory) {
            stateManager.transition(to: .inventory)
        }

        // Check quest log (Q key)
        if input.isPressed(.questLog) {
            stateManager.transition(to: .questLog)
            questLogDisplay.show(on: cameraController.cameraNode, viewSize: size, questSystem: questSystem)
        }

        // Refresh NPC quest markers periodically (~2 seconds)
        questMarkerRefreshTimer += deltaTime
        if questMarkerRefreshTimer >= 2.0 {
            questMarkerRefreshTimer = 0
            worldManager.updateNPCQuestMarkers(questSystem: questSystem, playerLevel: player.level)
        }

        // Update HUD
        updateHUD()
    }

    // MARK: - Interaction

    private func handleInteraction() {
        // Try door first
        if worldManager.tryUseDoor(scene: self) {
            return
        }

        // Try NPC interaction
        if let npc = worldManager.nearestInteractableNPC(),
           let dialogueId = npc.dialogueId,
           let dialogue = DialogueData.dialogue(forId: dialogueId) {
            stateManager.transition(to: .dialogue)
            dialogueSystem.startDialogue(dialogue, on: cameraController.cameraNode, viewSize: size)
            return
        }

        // Try buddy interaction (E key near buddy)
        if let buddy = activeBuddy {
            let distToBuddy = player.position.distance(to: buddy.position)
            if distToBuddy < GameConstants.interactionRange * 1.5 {
                let buddyType = bondSystem.activeBuddyType
                if bondSystem.canInteract(with: buddyType) {
                    let newLevel = bondSystem.recordInteraction(with: buddyType)
                    buddy.reactInteraction()
                    buddy.showBondPointsEarned(GameConstants.bondPointsPerInteraction)

                    if let newLevel = newLevel {
                        showBondLevelUpCelebration(buddyType: buddyType, newLevel: newLevel)
                        buddy.reactBondLevelUp(level: newLevel)
                    }
                    return
                }
            }
        }

        // Try tile interaction (future)
    }

    // MARK: - Dialogue State

    private func updateDialogue(deltaTime: TimeInterval) {
        let input = inputManager.state

        // Update typewriter animation
        dialogueSystem.update(deltaTime: deltaTime)

        // Advance on interact/confirm
        if input.isPressed(.interact) || input.isPressed(.confirm) {
            dialogueSystem.advance()
        }

        // Navigate choices with up/down
        if input.isPressed(.moveUp) {
            dialogueSystem.moveChoice(by: -1)
        }
        if input.isPressed(.moveDown) {
            dialogueSystem.moveChoice(by: 1)
        }

        // Cancel closes dialogue
        if input.isPressed(.cancel) {
            dialogueSystem.endDialogue()
        }
    }

    // MARK: - Challenge Triggering

    private let questionGenerator = QuestionGenerator()

    /// Start a challenge round based on the current zone/NPC context.
    /// Start a challenge from NPC interaction.
    /// Fast path: draws questions instantly from the adaptive question bank (no AI wait).
    /// Fallback: generates via AI + static bank if the adaptive bank is empty (first time).
    private func startChallengeFromNPC(_ npc: NPCCharacter) {
        let zoneId = worldManager.currentZoneId ?? "buddy_base"
        let subject = progressionSystem.subjectForZone(zoneId)
        let difficulty = progressionSystem.subjectDifficulty[subject] ?? .easy

        // 1. Show loading overlay IMMEDIATELY so the player gets instant feedback
        stateManager.transition(to: .challenge)
        challengeEngine.showLoading(
            on: cameraController.cameraNode,
            viewSize: size,
            subject: subject
        )

        // 2. Try drawing from adaptive question bank (instant — no AI wait)
        let bankManager = AdaptiveQuestionBankManager.shared
        let activeBuddyType = self.bondSystem.activeBuddyType
        let showHints = self.bondSystem.hasHintAbility(for: activeBuddyType)
        let hasSecondChance = self.bondSystem.hasSecondChance(for: activeBuddyType)

        // Try mixed questions first (combines MC from bank + new types for variety)
        if let mixedQuestions = bankManager.drawMixedQuestions(
            subject: subject,
            difficulty: difficulty,
            count: GameConstants.challengeRoundSize,
            gradeLevel: gradeLevel
        ) {
            let challenge = MixedRoundChallenge(
                questions: mixedQuestions,
                showBuddyHints: showHints,
                hasSecondChance: hasSecondChance
            )
            challenge.onBuddyHint = { [weak self] hint in
                self?.activeBuddy?.say(hint, duration: 4.0)
            }

            self.challengeEngine.startChallengeAfterLoading(challenge)
            return
        }

        // Fallback: try MC-only from bank
        if let bankQuestions = bankManager.drawQuestions(
            subject: subject,
            difficulty: difficulty,
            count: GameConstants.challengeRoundSize,
            gradeLevel: gradeLevel
        ) {
            let challenge = MultipleChoiceChallenge(
                questions: bankQuestions,
                showBuddyHints: showHints,
                hasSecondChance: hasSecondChance
            )
            challenge.onBuddyHint = { [weak self] hint in
                self?.activeBuddy?.say(hint, duration: 4.0)
            }
            self.challengeEngine.startChallengeAfterLoading(challenge)
            return
        }

        // 3. Bank empty — quick-seed from static questions (instant, no AI)
        bankManager.quickSeedFromStatic(subject: subject)

        // Try drawing again after quick-seed (mixed first, then MC fallback)
        if let mixedQuestions = bankManager.drawMixedQuestions(
            subject: subject,
            difficulty: difficulty,
            count: GameConstants.challengeRoundSize,
            gradeLevel: gradeLevel
        ) {
            let challenge = MixedRoundChallenge(
                questions: mixedQuestions,
                showBuddyHints: showHints,
                hasSecondChance: hasSecondChance
            )
            challenge.onBuddyHint = { [weak self] hint in
                self?.activeBuddy?.say(hint, duration: 4.0)
            }

            self.challengeEngine.startChallengeAfterLoading(challenge)
        } else if let bankQuestions = bankManager.drawQuestions(
            subject: subject,
            difficulty: difficulty,
            count: GameConstants.challengeRoundSize,
            gradeLevel: gradeLevel
        ) {
            let challenge = MultipleChoiceChallenge(
                questions: bankQuestions,
                showBuddyHints: showHints,
                hasSecondChance: hasSecondChance
            )
            challenge.onBuddyHint = { [weak self] hint in
                self?.activeBuddy?.say(hint, duration: 4.0)
            }
            self.challengeEngine.startChallengeAfterLoading(challenge)
        } else {
            // Truly no questions available — cancel
            challengeEngine.cancelChallenge()
            stateManager.transition(to: .playing)
        }
    }

    // MARK: - Challenge State

    private func updateChallenge(deltaTime: TimeInterval) {
        let input = inputManager.state

        // Update challenge engine (timer, animations)
        challengeEngine.update(deltaTime: deltaTime)

        // Pass input to challenge engine
        challengeEngine.handleInput(input)

        // Cancel challenge on escape
        if input.isPressed(.cancel) {
            challengeEngine.cancelChallenge()
        }
    }

    // MARK: - HUD

    private func setupHUD() {
        hudNode = SKNode()
        hudNode.zPosition = ZPositions.hud
        cameraController.cameraNode.addChild(hudNode)

        // ── Layout constants ──
        let badgeSize: CGFloat = 30
        let barWidth: CGFloat = 100
        let barHeight: CGFloat = 10
        let bondBarWidth: CGFloat = 50
        let spacing: CGFloat = 6

        // With .aspectFit, the entire scene is visible (may have letterbox bars).
        // Position HUD relative to the full scene size.
        let visibleWidth = size.width
        let visibleHeight = size.height
        let margin: CGFloat = 16  // from visible left edge

        // Layout: [PlayerBadge] spacing [XP bar] spacing [BuddyBadge]
        let totalWidth = badgeSize + spacing + barWidth + spacing + badgeSize

        // Left edge: player badge center X from visible left edge
        let playerX = -visibleWidth / 2 + margin + badgeSize / 2
        let buddyX = playerX + badgeSize + spacing + barWidth + spacing
        let centerX = (playerX + buddyX) / 2
        let anchorY = -visibleHeight / 2 + 46

        // ── Dark backdrop ──
        let backdropPad: CGFloat = 10
        let backdropW = totalWidth + backdropPad * 2
        let backdropH: CGFloat = 52
        let hudBackdrop = SKShapeNode(rectOf: CGSize(width: backdropW, height: backdropH), cornerRadius: 14)
        hudBackdrop.name = "hudBackdrop"
        hudBackdrop.fillColor = SKColor(red: 0.05, green: 0.05, blue: 0.12, alpha: 0.7)
        hudBackdrop.strokeColor = SKColor(white: 1.0, alpha: 0.1)
        hudBackdrop.lineWidth = 1
        hudBackdrop.position = CGPoint(x: centerX, y: anchorY - 5)
        hudBackdrop.zPosition = -1
        hudNode.addChild(hudBackdrop)

        // ── Player badge (left) — clickable, opens profile ──
        levelBadge = SKShapeNode(circleOfRadius: badgeSize / 2)
        levelBadge.name = "profileBadge"
        levelBadge.fillColor = profileBadgeColor()
        levelBadge.strokeColor = GameColors.xpBarFill.skColor
        levelBadge.lineWidth = 2
        levelBadge.position = CGPoint(x: playerX, y: anchorY)
        hudNode.addChild(levelBadge)

        // Profile initial inside badge
        levelLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        levelLabel.fontSize = 14
        levelLabel.fontColor = .white
        levelLabel.verticalAlignmentMode = .center
        levelLabel.horizontalAlignmentMode = .center
        levelBadge.addChild(levelLabel)

        // ── Center column: Level + XP bar + bond ──
        // Level label at top
        let lvlLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        lvlLabel.name = "levelSubLabel"
        lvlLabel.fontSize = 9
        lvlLabel.fontColor = SKColor(white: 0.95, alpha: 1.0)
        lvlLabel.verticalAlignmentMode = .bottom
        lvlLabel.horizontalAlignmentMode = .center
        lvlLabel.position = CGPoint(x: centerX, y: anchorY + 4)
        hudNode.addChild(lvlLabel)

        // XP Bar background
        xpBarBackground = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight), cornerRadius: 5)
        xpBarBackground.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 0.9)
        xpBarBackground.strokeColor = SKColor(red: 0.4, green: 0.4, blue: 0.5, alpha: 1)
        xpBarBackground.lineWidth = 1
        xpBarBackground.position = CGPoint(x: centerX, y: anchorY - 6)
        hudNode.addChild(xpBarBackground)

        // XP Bar fill
        xpBarFill = SKShapeNode(rectOf: CGSize(width: 0, height: barHeight - 2), cornerRadius: 4)
        xpBarFill.fillColor = GameColors.xpBarFill.skColor
        xpBarFill.strokeColor = .clear
        xpBarFill.position = CGPoint(x: centerX - barWidth / 2, y: anchorY - 6)
        hudNode.addChild(xpBarFill)

        // XP text on bar
        xpLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        xpLabel.fontSize = 7
        xpLabel.fontColor = .white
        xpLabel.position = CGPoint(x: centerX, y: anchorY - 6)
        xpLabel.verticalAlignmentMode = .center
        xpLabel.horizontalAlignmentMode = .center
        xpLabel.zPosition = 1
        hudNode.addChild(xpLabel)

        // Bond row below XP bar: heart + mini progress bar
        let bondY = anchorY - 19
        let bondContainer = SKNode()
        bondContainer.name = "bondHUD"
        bondContainer.position = CGPoint(x: centerX, y: bondY)
        hudNode.addChild(bondContainer)
        bondHUDNode = bondContainer

        let heart = SKLabelNode(text: "❤️")
        heart.fontSize = 8
        heart.position = CGPoint(x: -bondBarWidth / 2 - 8, y: 0)
        heart.verticalAlignmentMode = .center
        bondContainer.addChild(heart)
        bondHeartLabel = heart

        let bondBg = SKShapeNode(rectOf: CGSize(width: bondBarWidth, height: 4), cornerRadius: 2)
        bondBg.fillColor = SKColor(white: 0.3, alpha: 0.7)
        bondBg.strokeColor = .clear
        bondBg.position = .zero
        bondContainer.addChild(bondBg)
        bondHUDProgressBg = bondBg

        let bondFill = SKShapeNode(rectOf: CGSize(width: 1, height: 3), cornerRadius: 1.5)
        bondFill.fillColor = SKColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1)
        bondFill.strokeColor = .clear
        bondFill.position = CGPoint(x: -bondBarWidth / 2, y: 0)
        bondContainer.addChild(bondFill)
        bondHUDProgressFill = bondFill

        // ── Buddy badge (right) ──
        let buddyContainer = SKNode()
        buddyContainer.name = "buddyBadge"
        buddyContainer.position = CGPoint(x: buddyX, y: anchorY)
        hudNode.addChild(buddyContainer)
        buddyBadge = buddyContainer

        // Buddy circle background
        let buddyCircle = SKShapeNode(circleOfRadius: badgeSize / 2)
        buddyCircle.fillColor = buddyBadgeColor()
        buddyCircle.strokeColor = SKColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 0.8)
        buddyCircle.lineWidth = 2
        buddyContainer.addChild(buddyCircle)

        // Buddy face sprite (from asset catalog)
        let faceName = "\(bondSystem.activeBuddyType.rawValue)_face"
        let buddySprite = SKSpriteNode(imageNamed: faceName)
        buddySprite.size = CGSize(width: badgeSize - 4, height: badgeSize - 4)
        let cropNode = SKCropNode()
        let mask = SKShapeNode(circleOfRadius: (badgeSize - 4) / 2)
        mask.fillColor = .white
        cropNode.maskNode = mask
        cropNode.addChild(buddySprite)
        buddyContainer.addChild(cropNode)
        buddyBadgeSprite = buddySprite

        lastDisplayedLevel = player.level
    }

    /// Get the profile badge background color from ProfileManager
    private func profileBadgeColor() -> SKColor {
        if let profile = ProfileManager.shared.activeProfile {
            let rgb = profile.color.rgb
            return SKColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: 0.95)
        }
        return SKColor(red: 0.2, green: 0.15, blue: 0.4, alpha: 0.95)
    }

    /// Get the buddy badge border color
    private func buddyBadgeColor() -> SKColor {
        switch bondSystem.activeBuddyType {
        case .nova: return SKColor(red: 0, green: 0.7, blue: 0.7, alpha: 0.4)
        case .lexie: return SKColor(red: 0.7, green: 0.4, blue: 0.86, alpha: 0.4)
        case .digit: return SKColor(red: 0.3, green: 0.55, blue: 1.0, alpha: 0.4)
        case .harmony: return SKColor(red: 1.0, green: 0.55, blue: 0.7, alpha: 0.4)
        }
    }

    private func updateHUD() {
        let badgeSize: CGFloat = 30
        let barWidth: CGFloat = 100
        let spacing: CGFloat = 6
        let margin: CGFloat = 16

        // With .aspectFit, the entire scene is visible
        let visibleWidth = size.width
        let visibleHeight = size.height

        let playerX = -visibleWidth / 2 + margin + badgeSize / 2
        let buddyX = playerX + badgeSize + spacing + barWidth + spacing
        let centerX = (playerX + buddyX) / 2
        let anchorY = -visibleHeight / 2 + 46

        // Profile avatar inside badge (emoji or initial, or level number if no profile)
        if let profile = ProfileManager.shared.activeProfile {
            levelLabel.text = profile.avatarDisplay
            levelLabel.fontSize = profile.avatarEmoji != nil ? 18 : 14
        } else {
            levelLabel.text = "\(player.level)"
            levelLabel.fontSize = 14
        }

        // Level label above XP bar
        if let subLabel = hudNode?.childNode(withName: "levelSubLabel") as? SKLabelNode {
            subLabel.text = "Lv.\(player.level)  ·  \(player.totalXP) XP"
        }

        // XP numbers on the bar
        let xpInLevel = player.xpForCurrentLevel
        let xpNeeded = GameConstants.xpPerLevel
        xpLabel.text = "\(xpInLevel)/\(xpNeeded)"

        // XP bar fill
        let progress = player.xpProgressFraction
        let fillWidth = barWidth * progress

        xpBarFill.removeFromParent()
        xpBarFill = SKShapeNode(rectOf: CGSize(width: max(fillWidth, 1), height: 8), cornerRadius: 4)
        xpBarFill.fillColor = GameColors.xpBarFill.skColor
        xpBarFill.strokeColor = .clear
        xpBarFill.position = CGPoint(
            x: centerX - barWidth / 2 + fillWidth / 2,
            y: anchorY - 6
        )
        hudNode.addChild(xpBarFill)

        // Detect level-up
        if player.level > lastDisplayedLevel {
            showLevelUpCelebration(newLevel: player.level)
            questSystem.recordLevelReached(player.level)
            lastDisplayedLevel = player.level
        }

        // Update bond HUD
        updateBondHUD()

        // Update buddy face if buddy changed
        updateBuddyBadge()
    }

    private func updateBondHUD() {
        let buddyType = bondSystem.activeBuddyType
        let data = bondSystem.bondData(for: buddyType)

        // Update progress bar
        let barW: CGFloat = 50
        let progress = CGFloat(data.progressToNext)
        let fillW = max(barW * progress, 1)

        bondHUDProgressFill?.removeFromParent()
        let newFill = SKShapeNode(rectOf: CGSize(width: fillW, height: 3), cornerRadius: 1.5)
        newFill.fillColor = SKColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1)
        newFill.strokeColor = .clear
        newFill.position = CGPoint(x: -barW / 2 + fillW / 2, y: 0)
        bondHUDNode?.addChild(newFill)
        bondHUDProgressFill = newFill
    }

    private func updateBuddyBadge() {
        let faceName = "\(bondSystem.activeBuddyType.rawValue)_face"
        buddyBadgeSprite?.texture = SKTexture(imageNamed: faceName)

        // Update buddy circle border color
        if let container = buddyBadge,
           let circle = container.children.first as? SKShapeNode {
            circle.fillColor = buddyBadgeColor()
        }
    }

    // MARK: - Level Up Celebration

    /// Full-screen celebration when the player reaches a new level:
    /// golden sparkle burst + banner with scale-bounce + badge pulse.
    private func showLevelUpCelebration(newLevel: Int) {
        let camera = cameraController.cameraNode

        // Remove any existing celebration
        camera.childNode(withName: "levelUpCelebration")?.removeFromParent()

        let container = SKNode()
        container.name = "levelUpCelebration"
        container.zPosition = ZPositions.hud + 20
        camera.addChild(container)

        // --- 1. Sparkle burst (radial particles) ---
        let sparkleColors: [SKColor] = [
            GameColors.xpBarFill.skColor,                           // Gold
            SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1),   // Bright gold
            SKColor(red: 1.0, green: 1.0, blue: 0.6, alpha: 1),    // Light yellow
            SKColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1),    // Light blue
            .white
        ]
        let particleCount = 24
        for i in 0..<particleCount {
            let angle = CGFloat(i) / CGFloat(particleCount) * .pi * 2
            let spark = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4))
            spark.fillColor = sparkleColors[i % sparkleColors.count]
            spark.strokeColor = .clear
            spark.position = .zero
            spark.alpha = 1
            spark.zPosition = 1
            container.addChild(spark)

            let radius = CGFloat.random(in: 80...160)
            let targetX = cos(angle) * radius
            let targetY = sin(angle) * radius
            let duration = Double.random(in: 0.5...0.9)

            spark.run(.sequence([
                .group([
                    .move(to: CGPoint(x: targetX, y: targetY), duration: duration),
                    .fadeOut(withDuration: duration),
                    .scale(to: 0.2, duration: duration)
                ]),
                .removeFromParent()
            ]))
        }

        // --- 2. Glowing ring expand ---
        let ring = SKShapeNode(circleOfRadius: 10)
        ring.fillColor = .clear
        ring.strokeColor = GameColors.xpBarFill.skColor
        ring.lineWidth = 3
        ring.alpha = 0.8
        ring.zPosition = 0
        container.addChild(ring)

        ring.run(.sequence([
            .group([
                .scale(to: 12, duration: 0.6),
                .fadeOut(withDuration: 0.6)
            ]),
            .removeFromParent()
        ]))

        // --- 3. Banner: "Level Up!" + level number ---
        let banner = SKNode()
        banner.zPosition = 2
        banner.setScale(0)

        // Banner background pill
        let pillWidth: CGFloat = 200
        let pillHeight: CGFloat = 60
        let pill = SKShapeNode(rectOf: CGSize(width: pillWidth, height: pillHeight), cornerRadius: pillHeight / 2)
        pill.fillColor = SKColor(red: 0.1, green: 0.08, blue: 0.2, alpha: 0.92)
        pill.strokeColor = GameColors.xpBarFill.skColor
        pill.lineWidth = 2.5
        banner.addChild(pill)

        // "LEVEL UP!" text
        let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        titleLabel.text = "LEVEL UP!"
        titleLabel.fontSize = 18
        titleLabel.fontColor = GameColors.xpBarFill.skColor
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: 10)
        banner.addChild(titleLabel)

        // Level number text
        let levelText = SKLabelNode(fontNamed: "AvenirNext-Bold")
        levelText.text = "Level \(newLevel)"
        levelText.fontSize = 14
        levelText.fontColor = .white
        levelText.verticalAlignmentMode = .center
        levelText.horizontalAlignmentMode = .center
        levelText.position = CGPoint(x: 0, y: -12)
        banner.addChild(levelText)

        container.addChild(banner)

        // Scale-bounce animation for the banner
        banner.run(.sequence([
            .scale(to: 1.15, duration: 0.25),
            .scale(to: 0.95, duration: 0.1),
            .scale(to: 1.0, duration: 0.08),
            .wait(forDuration: 2.0),
            .fadeOut(withDuration: 0.5),
            .removeFromParent()
        ]))

        // --- 4. Pulse the HUD level badge ---
        levelBadge?.run(.sequence([
            .scale(to: 1.4, duration: 0.2),
            .scale(to: 0.9, duration: 0.15),
            .scale(to: 1.0, duration: 0.1)
        ]))

        // Clean up container after everything finishes
        container.run(.sequence([
            .wait(forDuration: 3.5),
            .removeFromParent()
        ]))
    }

    // MARK: - Bond Level-Up Celebration

    /// Show a celebration when a buddy reaches a new bond level.
    private func showBondLevelUpCelebration(buddyType: BuddyType, newLevel: BondLevel) {
        let camera = cameraController.cameraNode

        // Remove any existing bond celebration
        camera.childNode(withName: "bondLevelUpCelebration")?.removeFromParent()

        let container = SKNode()
        container.name = "bondLevelUpCelebration"
        container.zPosition = ZPositions.hud + 15
        camera.addChild(container)

        // Heart particle burst
        let particleCount = 16
        for i in 0..<particleCount {
            let angle = CGFloat(i) / CGFloat(particleCount) * .pi * 2
            let heart = SKLabelNode(text: "\u{2764}\u{FE0F}")
            heart.fontSize = CGFloat.random(in: 10...18)
            heart.position = .zero
            heart.alpha = 1
            heart.zPosition = 1
            container.addChild(heart)

            let radius = CGFloat.random(in: 60...130)
            let targetX = cos(angle) * radius
            let targetY = sin(angle) * radius
            let duration = Double.random(in: 0.5...0.9)

            heart.run(.sequence([
                .group([
                    .move(to: CGPoint(x: targetX, y: targetY), duration: duration),
                    .fadeOut(withDuration: duration),
                    .scale(to: 0.3, duration: duration)
                ]),
                .removeFromParent()
            ]))
        }

        // Banner
        let banner = SKNode()
        banner.zPosition = 2
        banner.setScale(0)

        let pillWidth: CGFloat = 280
        let pillHeight: CGFloat = 70
        let pill = SKShapeNode(rectOf: CGSize(width: pillWidth, height: pillHeight), cornerRadius: pillHeight / 2)
        pill.fillColor = SKColor(red: 0.15, green: 0.05, blue: 0.15, alpha: 0.92)
        pill.strokeColor = SKColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 0.8)
        pill.lineWidth = 2.5
        banner.addChild(pill)

        let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        titleLabel.text = "\u{2764}\u{FE0F} Bond Level Up!"
        titleLabel.fontSize = 16
        titleLabel.fontColor = SKColor(red: 1.0, green: 0.5, blue: 0.7, alpha: 1)
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: 14)
        banner.addChild(titleLabel)

        let detailLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        detailLabel.text = "\(buddyType.displayName) is now your \(newLevel.displayName)!"
        detailLabel.fontSize = 12
        detailLabel.fontColor = .white
        detailLabel.verticalAlignmentMode = .center
        detailLabel.horizontalAlignmentMode = .center
        detailLabel.position = CGPoint(x: 0, y: -8)
        banner.addChild(detailLabel)

        container.addChild(banner)

        banner.run(.sequence([
            .scale(to: 1.15, duration: 0.25),
            .scale(to: 0.95, duration: 0.1),
            .scale(to: 1.0, duration: 0.08),
            .wait(forDuration: 3.0),
            .fadeOut(withDuration: 0.5),
            .removeFromParent()
        ]))

        container.run(.sequence([
            .wait(forDuration: 4.5),
            .removeFromParent()
        ]))
    }

    // MARK: - Quest System Helpers

    private let questLogDisplay = QuestLogDisplay()

    /// Apply quest rewards: XP, bond points, game flags
    private func applyQuestReward(_ reward: QuestReward) {
        if reward.xpBonus > 0 {
            player.addXP(reward.xpBonus)
        }
        if reward.bondPoints > 0 {
            _ = bondSystem.addPoints(reward.bondPoints, to: bondSystem.activeBuddyType)
        }
        if let flag = reward.unlocksFlag {
            worldManager.gameFlags.insert(flag)
        }
        saveGame()
    }

    /// Show a banner when a quest is accepted
    private func showQuestAcceptBanner(_ quest: QuestDefinition) {
        showQuestBanner(title: "Quest Accepted", detail: quest.name, color: SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1))
    }

    /// Show a banner when a quest is completed
    private func showQuestCompleteBanner(_ quest: QuestDefinition) {
        showQuestBanner(title: "Quest Complete!", detail: "\(quest.name) — +\(quest.reward.xpBonus) XP", color: SKColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 1))
    }

    /// Generic quest banner (similar to room name banner)
    private func showQuestBanner(title: String, detail: String, color: SKColor) {
        let camera = cameraController.cameraNode

        // Remove any existing quest banner
        camera.childNode(withName: "questBanner")?.removeFromParent()

        let banner = SKNode()
        banner.name = "questBanner"
        banner.zPosition = ZPositions.hud + 8
        banner.alpha = 0

        let pillWidth: CGFloat = 280
        let pillHeight: CGFloat = 50

        let pill = SKShapeNode(rectOf: CGSize(width: pillWidth, height: pillHeight), cornerRadius: pillHeight / 2)
        pill.fillColor = SKColor(red: 0.08, green: 0.08, blue: 0.15, alpha: 0.9)
        pill.strokeColor = color.withAlphaComponent(0.8)
        pill.lineWidth = 2
        banner.addChild(pill)

        let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        titleLabel.text = title
        titleLabel.fontSize = 13
        titleLabel.fontColor = color
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: 8)
        pill.addChild(titleLabel)

        let detailLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        detailLabel.text = detail
        detailLabel.fontSize = 10
        detailLabel.fontColor = .white
        detailLabel.verticalAlignmentMode = .center
        detailLabel.horizontalAlignmentMode = .center
        detailLabel.position = CGPoint(x: 0, y: -8)
        pill.addChild(detailLabel)

        let startY: CGFloat = -size.height / 4 - 40
        let endY: CGFloat = -size.height / 4
        banner.position = CGPoint(x: 0, y: startY)
        camera.addChild(banner)

        let slideIn = SKAction.group([
            .fadeAlpha(to: 1.0, duration: 0.35),
            .moveTo(y: endY, duration: 0.35)
        ])
        slideIn.timingMode = .easeOut

        let hold = SKAction.wait(forDuration: 2.5)
        let slideOut = SKAction.group([
            .fadeAlpha(to: 0, duration: 0.4),
            .moveTo(y: endY - 20, duration: 0.4)
        ])
        slideOut.timingMode = .easeIn

        banner.run(.sequence([slideIn, hold, slideOut, .removeFromParent()]))
    }

    /// Handle quest log input (navigate and close)
    private func updateQuestLog() {
        let input = inputManager.state

        if input.isPressed(.cancel) || input.isPressed(.questLog) {
            questLogDisplay.dismiss()
            stateManager.transition(to: .playing)
        }
        if input.isPressed(.moveUp) {
            questLogDisplay.navigate(by: -1)
        }
        if input.isPressed(.moveDown) {
            questLogDisplay.navigate(by: 1)
        }
        if input.isPressed(.moveLeft) || input.isPressed(.moveRight) {
            questLogDisplay.toggleTab()
        }
    }

    // MARK: - Quest Migration for Existing Saves

    /// Called when loading a save that predates the quest system.
    /// Retroactively accepts and completes quests based on the player's
    /// current level and challenge history so doors are properly unlocked.
    private func migrateQuestsForExistingSave() {
        print("[QuestSystem] Migrating quests for existing save (level \(player.level))")

        // --- Tutorial chain ---
        // tutorial_start: talk to Pip (complete immediately — they've already played)
        questSystem.acceptQuest("tutorial_start")
        questSystem.recordNPCTalk(npcId: "guide_pip")
        _ = questSystem.completeQuest("tutorial_start")

        // tutorial_first_challenge: visit forest + 1 LA challenge
        questSystem.acceptQuest("tutorial_first_challenge")
        questSystem.recordRoomVisit(roomId: "forest_entrance")
        questSystem.recordChallengeComplete(subject: .languageArts)
        _ = questSystem.completeQuest("tutorial_first_challenge")

        // tutorial_explore: visit library + courtyard
        questSystem.acceptQuest("tutorial_explore")
        questSystem.recordRoomVisit(roomId: "hub_library")
        questSystem.recordRoomVisit(roomId: "hub_courtyard")
        _ = questSystem.completeQuest("tutorial_explore")

        // --- Zone entry quests ---
        // For each zone: if the player has completed enough challenges in that
        // subject, auto-accept and complete the entry quest so the middle room
        // unlocks immediately.

        // Word Forest — requires tutorial_first_challenge (done above), 3 LA challenges
        let laCount = progressionSystem.subjectCompletedCount[.languageArts] ?? 0
        if laCount >= 3 {
            questSystem.acceptQuest("forest_beginner_path")
            for _ in 0..<3 { questSystem.recordChallengeComplete(subject: .languageArts) }
            if let reward = questSystem.completeQuest("forest_beginner_path") {
                if let flag = reward.unlocksFlag { worldManager.gameFlags.insert(flag) }
            }
        } else {
            // Accept but don't complete — let them continue from where they are
            questSystem.acceptQuest("forest_beginner_path")
            for _ in 0..<laCount { questSystem.recordChallengeComplete(subject: .languageArts) }
        }

        // Number Peaks — requires level 3, 3 math challenges
        let mathCount = progressionSystem.subjectCompletedCount[.math] ?? 0
        if player.level >= 3 {
            if mathCount >= 3 {
                questSystem.acceptQuest("peaks_beginner_climb")
                for _ in 0..<3 { questSystem.recordChallengeComplete(subject: .math) }
                if let reward = questSystem.completeQuest("peaks_beginner_climb") {
                    if let flag = reward.unlocksFlag { worldManager.gameFlags.insert(flag) }
                }
            } else {
                questSystem.acceptQuest("peaks_beginner_climb")
                for _ in 0..<mathCount { questSystem.recordChallengeComplete(subject: .math) }
            }
        }

        // Science Lab — requires level 5, 3 science challenges
        let sciCount = progressionSystem.subjectCompletedCount[.science] ?? 0
        if player.level >= 5 {
            if sciCount >= 3 {
                questSystem.acceptQuest("lab_first_experiment")
                for _ in 0..<3 { questSystem.recordChallengeComplete(subject: .science) }
                if let reward = questSystem.completeQuest("lab_first_experiment") {
                    if let flag = reward.unlocksFlag { worldManager.gameFlags.insert(flag) }
                }
            } else {
                questSystem.acceptQuest("lab_first_experiment")
                for _ in 0..<sciCount { questSystem.recordChallengeComplete(subject: .science) }
            }
        }

        // Teamwork Arena — requires level 2, 3 social challenges
        let socialCount = progressionSystem.subjectCompletedCount[.social] ?? 0
        if player.level >= 2 {
            if socialCount >= 3 {
                questSystem.acceptQuest("arena_first_teamup")
                for _ in 0..<3 { questSystem.recordChallengeComplete(subject: .social) }
                if let reward = questSystem.completeQuest("arena_first_teamup") {
                    if let flag = reward.unlocksFlag { worldManager.gameFlags.insert(flag) }
                }
            } else {
                questSystem.acceptQuest("arena_first_teamup")
                for _ in 0..<socialCount { questSystem.recordChallengeComplete(subject: .social) }
            }
        }

        // Save immediately so migration persists
        saveGame()
        print("[QuestSystem] Migration complete — flags: \(worldManager.gameFlags)")
    }

    // MARK: - Room Name Banner (Animated)

    /// Shows a cinematic-style room name banner that slides in, pauses, then fades out.
    /// Called automatically when the player enters a new room.
    private func showRoomNameBanner(_ name: String) {
        guard !name.isEmpty else { return }

        // Remove any existing banner
        cameraController.cameraNode.childNode(withName: "roomBanner")?.removeFromParent()

        // Container node
        let banner = SKNode()
        banner.name = "roomBanner"
        banner.zPosition = ZPositions.hud + 5
        banner.alpha = 0

        // Background pill
        let padding: CGFloat = 24
        let labelNode = SKLabelNode(fontNamed: "AvenirNext-Bold")
        labelNode.text = name
        labelNode.fontSize = 16
        labelNode.fontColor = .white
        labelNode.verticalAlignmentMode = .center
        labelNode.horizontalAlignmentMode = .center

        let pillWidth = labelNode.frame.width + padding * 2
        let pillHeight: CGFloat = 36

        let pill = SKShapeNode(rectOf: CGSize(width: pillWidth, height: pillHeight), cornerRadius: pillHeight / 2)
        pill.fillColor = SKColor(red: 0.08, green: 0.08, blue: 0.15, alpha: 0.85)
        pill.strokeColor = SKColor(red: 0.5, green: 0.45, blue: 0.7, alpha: 0.8)
        pill.lineWidth = 1.5
        pill.addChild(labelNode)

        banner.addChild(pill)

        // Start slightly above center, settle to center
        let startY: CGFloat = size.height / 4 + 40
        let endY: CGFloat = size.height / 4
        banner.position = CGPoint(x: 0, y: startY)

        cameraController.cameraNode.addChild(banner)

        // Animate: fade in + slide down → hold → fade out + slide up
        let slideIn = SKAction.group([
            .fadeAlpha(to: 1.0, duration: 0.4),
            .moveTo(y: endY, duration: 0.4)
        ])
        slideIn.timingMode = .easeOut

        let hold = SKAction.wait(forDuration: 1.8)

        let slideOut = SKAction.group([
            .fadeAlpha(to: 0, duration: 0.5),
            .moveTo(y: endY + 20, duration: 0.5)
        ])
        slideOut.timingMode = .easeIn

        banner.run(.sequence([slideIn, hold, slideOut, .removeFromParent()]))
    }

    // MARK: - Input Event Forwarding

    #if os(macOS)
    public override func keyDown(with event: NSEvent) {
        inputManager.keyDown(keyCode: event.keyCode)
    }

    public override func keyUp(with event: NSEvent) {
        inputManager.keyUp(keyCode: event.keyCode)
    }

    public override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        let cameraLocation = cameraController.cameraNode.convert(location, from: self)

        // Check if click is on profile badge — opens pause/profile menu
        if let badge = hudNode?.childNode(withName: "profileBadge"),
           badge.frame.insetBy(dx: -12, dy: -12).contains(cameraLocation) {
            if stateManager.isPlaying {
                stateManager.transition(to: .paused)
            }
            return
        }

        // Check if click is on buddy badge — opens buddy select
        if let badge = hudNode?.childNode(withName: "buddyBadge"),
           badge.frame.insetBy(dx: -12, dy: -12).contains(cameraLocation) {
            if stateManager.isPlaying {
                stateManager.transition(to: .paused)
                buddySelectRequested = true
            }
            return
        }
    }
    #endif

    #if os(iOS)
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Check if tap is on profile badge (opens pause menu)
        let cameraLocation = cameraController.cameraNode.convert(location, from: self)
        if let badge = hudNode?.childNode(withName: "profileBadge"),
           badge.frame.insetBy(dx: -12, dy: -12).contains(cameraLocation) {
            if stateManager.isPlaying {
                stateManager.transition(to: .paused)
            }
            return
        }

        // Check if tap is on buddy badge (opens buddy select)
        if let badge = hudNode?.childNode(withName: "buddyBadge"),
           badge.frame.insetBy(dx: -12, dy: -12).contains(cameraLocation) {
            if stateManager.isPlaying {
                stateManager.transition(to: .paused)
                buddySelectRequested = true
            }
            return
        }

        handleTouch(at: location, phase: .began)
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        handleTouch(at: location, phase: .moved)
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputManager.setVirtualJoystick(direction: .zero)
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputManager.setVirtualJoystick(direction: .zero)
    }

    private enum TouchPhase { case began, moved }

    private func handleTouch(at location: CGPoint, phase: TouchPhase) {
        // Left half of screen: joystick
        // Right half of screen: interact button
        let screenCenter = CGPoint.zero // Camera-relative

        if location.x < screenCenter.x {
            // Virtual joystick - calculate direction from bottom-left area
            let joystickCenter = CGPoint(
                x: -size.width / 2 + 80,
                y: -size.height / 2 + 80
            )
            let diff = location - joystickCenter
            let maxDist: CGFloat = 60
            let clamped = CGPoint(
                x: max(-1, min(1, diff.x / maxDist)),
                y: max(-1, min(1, diff.y / maxDist))
            )
            inputManager.setVirtualJoystick(direction: clamped)
        } else if phase == .began {
            // Tap right side = interact
            inputManager.pressVirtualButton(.interact)
        }
    }
    #endif

    // MARK: - Window Resize

    public override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard isInitialized else { return }
        cameraController.viewportSize = size
        repositionHUD()
    }

    private func repositionHUD() {
        let badgeSize: CGFloat = 30
        let barWidth: CGFloat = 100
        let spacing: CGFloat = 6
        let margin: CGFloat = 16

        // With .aspectFit, the entire scene is visible
        let visibleWidth = size.width
        let visibleHeight = size.height

        let playerX = -visibleWidth / 2 + margin + badgeSize / 2
        let buddyX = playerX + badgeSize + spacing + barWidth + spacing
        let centerX = (playerX + buddyX) / 2
        let anchorY = -visibleHeight / 2 + 46
        let bondY = anchorY - 19

        // Player badge
        levelBadge?.position = CGPoint(x: playerX, y: anchorY)

        // Level label
        if let subLabel = hudNode?.childNode(withName: "levelSubLabel") as? SKLabelNode {
            subLabel.position = CGPoint(x: centerX, y: anchorY + 4)
        }

        // XP bar
        xpBarBackground?.position = CGPoint(x: centerX, y: anchorY - 6)
        xpLabel?.position = CGPoint(x: centerX, y: anchorY - 6)

        // Bond HUD
        bondHUDNode?.position = CGPoint(x: centerX, y: bondY)

        // Buddy badge
        buddyBadge?.position = CGPoint(x: buddyX, y: anchorY)

        // Backdrop
        if let backdrop = hudNode?.childNode(withName: "hudBackdrop") as? SKShapeNode {
            backdrop.position = CGPoint(x: centerX, y: anchorY - 5)
        }
    }

    // MARK: - Scene Configuration

    public static func createScene(size: CGSize, gradeLevel: GradeLevel = .third) -> GameEngine {
        // Use the room's pixel dimensions so tiles fill the viewport
        let roomW = CGFloat(GameConstants.tilesPerScreenWidth) * GameConstants.tileSize
        let roomH = CGFloat(GameConstants.tilesPerScreenHeight) * GameConstants.tileSize
        let scene = GameEngine(size: CGSize(width: roomW, height: roomH))
        scene.scaleMode = .aspectFit
        scene.gradeLevel = gradeLevel
        return scene
    }
}
