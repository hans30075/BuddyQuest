import Foundation
import SpriteKit

/// SpriteKit overlay for viewing active and completed quests.
/// Shown when the player presses Q. Supports tab switching and scrolling.
public final class QuestLogDisplay {

    private var containerNode: SKNode?
    private var questSystem: QuestSystem?
    private var viewSize: CGSize = .zero

    // UI state
    private var showingCompleted: Bool = false
    private var selectedIndex: Int = 0
    private var questListNodes: [SKNode] = []

    // Layout constants
    private let panelWidth: CGFloat = 380
    private let panelHeight: CGFloat = 420
    private let rowHeight: CGFloat = 48
    private let headerHeight: CGFloat = 60

    public init() {}

    // MARK: - Show / Dismiss

    public func show(on parent: SKNode, viewSize: CGSize, questSystem: QuestSystem) {
        dismiss()
        self.questSystem = questSystem
        self.viewSize = viewSize
        self.showingCompleted = false
        self.selectedIndex = 0

        let container = SKNode()
        container.name = "questLogOverlay"
        container.zPosition = ZPositions.hud + 30
        parent.addChild(container)
        containerNode = container

        buildUI()
    }

    public func dismiss() {
        containerNode?.removeFromParent()
        containerNode = nil
        questListNodes.removeAll()
    }

    // MARK: - Navigation

    public func navigate(by delta: Int) {
        let count = questListNodes.count
        guard count > 0 else { return }
        selectedIndex = max(0, min(count - 1, selectedIndex + delta))
        updateSelection()
    }

    public func toggleTab() {
        showingCompleted.toggle()
        selectedIndex = 0
        buildUI()
    }

    // MARK: - Build UI

    private func buildUI() {
        guard let container = containerNode, let qs = questSystem else { return }

        // Clear existing children
        container.removeAllChildren()
        questListNodes.removeAll()

        // Semi-transparent backdrop
        let backdrop = SKShapeNode(rectOf: CGSize(width: viewSize.width * 2, height: viewSize.height * 2))
        backdrop.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        backdrop.strokeColor = .clear
        backdrop.zPosition = -1
        container.addChild(backdrop)

        // Main panel
        let panel = SKShapeNode(rectOf: CGSize(width: panelWidth, height: panelHeight), cornerRadius: 16)
        panel.fillColor = SKColor(red: 0.08, green: 0.08, blue: 0.15, alpha: 0.95)
        panel.strokeColor = SKColor(red: 0.5, green: 0.4, blue: 0.7, alpha: 0.8)
        panel.lineWidth = 2
        container.addChild(panel)

        // Title
        let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        titleLabel.text = "Quest Journal"
        titleLabel.fontSize = 18
        titleLabel.fontColor = SKColor(red: 0.9, green: 0.85, blue: 1.0, alpha: 1)
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: panelHeight / 2 - 24)
        container.addChild(titleLabel)

        // Tab indicators
        let tabY = panelHeight / 2 - 50
        let activeTabColor = SKColor(red: 0.7, green: 0.6, blue: 1.0, alpha: 1)
        let inactiveTabColor = SKColor(white: 0.5, alpha: 1)

        let activeTab = SKLabelNode(fontNamed: "AvenirNext-Bold")
        activeTab.text = "Active"
        activeTab.fontSize = 13
        activeTab.fontColor = showingCompleted ? inactiveTabColor : activeTabColor
        activeTab.verticalAlignmentMode = .center
        activeTab.horizontalAlignmentMode = .center
        activeTab.position = CGPoint(x: -60, y: tabY)
        container.addChild(activeTab)

        let completedTab = SKLabelNode(fontNamed: "AvenirNext-Bold")
        completedTab.text = "Completed"
        completedTab.fontSize = 13
        completedTab.fontColor = showingCompleted ? activeTabColor : inactiveTabColor
        completedTab.verticalAlignmentMode = .center
        completedTab.horizontalAlignmentMode = .center
        completedTab.position = CGPoint(x: 60, y: tabY)
        container.addChild(completedTab)

        // Underline for active tab
        let underline = SKShapeNode(rectOf: CGSize(width: 70, height: 2), cornerRadius: 1)
        underline.fillColor = activeTabColor
        underline.strokeColor = .clear
        underline.position = CGPoint(x: showingCompleted ? 60 : -60, y: tabY - 12)
        container.addChild(underline)

        // Quest list
        let quests: [QuestDefinition] = showingCompleted ? qs.completedQuests : qs.activeQuests
        let listStartY = tabY - 36
        let maxVisible = Int((panelHeight - headerHeight - 40) / rowHeight)

        if quests.isEmpty {
            let emptyLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            emptyLabel.text = showingCompleted ? "No completed quests yet." : "No active quests."
            emptyLabel.fontSize = 12
            emptyLabel.fontColor = SKColor(white: 0.5, alpha: 1)
            emptyLabel.verticalAlignmentMode = .center
            emptyLabel.horizontalAlignmentMode = .center
            emptyLabel.position = CGPoint(x: 0, y: listStartY - 40)
            container.addChild(emptyLabel)
        } else {
            for (i, quest) in quests.prefix(maxVisible).enumerated() {
                let row = createQuestRow(quest: quest, index: i, y: listStartY - CGFloat(i) * rowHeight, isSelected: i == selectedIndex)
                container.addChild(row)
                questListNodes.append(row)
            }
        }

        // Footer hint
        let hintLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        hintLabel.text = "← → Switch Tab  |  ↑ ↓ Navigate  |  Q/Esc Close"
        hintLabel.fontSize = 9
        hintLabel.fontColor = SKColor(white: 0.4, alpha: 1)
        hintLabel.verticalAlignmentMode = .center
        hintLabel.horizontalAlignmentMode = .center
        hintLabel.position = CGPoint(x: 0, y: -panelHeight / 2 + 16)
        container.addChild(hintLabel)
    }

    private func createQuestRow(quest: QuestDefinition, index: Int, y: CGFloat, isSelected: Bool) -> SKNode {
        let row = SKNode()
        row.position = CGPoint(x: 0, y: y)

        let rowWidth = panelWidth - 30
        let bg = SKShapeNode(rectOf: CGSize(width: rowWidth, height: rowHeight - 6), cornerRadius: 8)
        bg.fillColor = isSelected
            ? SKColor(red: 0.2, green: 0.15, blue: 0.35, alpha: 0.8)
            : SKColor(red: 0.12, green: 0.12, blue: 0.2, alpha: 0.5)
        bg.strokeColor = isSelected
            ? SKColor(red: 0.6, green: 0.5, blue: 0.9, alpha: 0.6)
            : .clear
        bg.lineWidth = 1
        row.addChild(bg)

        // Quest name
        let nameLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        nameLabel.text = quest.name
        nameLabel.fontSize = 12
        nameLabel.fontColor = .white
        nameLabel.verticalAlignmentMode = .center
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.position = CGPoint(x: -rowWidth / 2 + 12, y: 7)
        row.addChild(nameLabel)

        // Progress or status
        let statusLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        if showingCompleted {
            statusLabel.text = "Completed"
            statusLabel.fontColor = SKColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 1)
        } else {
            let progress = questSystem?.progressDescription(for: quest.id) ?? ""
            statusLabel.text = progress.isEmpty ? quest.description : progress
            statusLabel.fontColor = SKColor(white: 0.7, alpha: 1)
        }
        statusLabel.fontSize = 9
        statusLabel.verticalAlignmentMode = .center
        statusLabel.horizontalAlignmentMode = .left
        statusLabel.position = CGPoint(x: -rowWidth / 2 + 12, y: -8)
        row.addChild(statusLabel)

        return row
    }

    // MARK: - Selection Update

    private func updateSelection() {
        // Rebuild is simpler than surgically updating colors
        buildUI()
    }
}
