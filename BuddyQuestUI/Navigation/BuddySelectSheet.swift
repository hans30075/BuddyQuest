import SwiftUI
import BuddyQuestKit

/// A sheet that lets the player choose their active buddy.
/// Shows all 4 buddies with bond levels, progress bars, and unlocked abilities.
struct BuddySelectSheet: View {
    @Environment(\.dismiss) private var dismiss
    let bondSystem: BuddyBondSystem
    let onSelect: (BuddyType) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Choose Your Buddy")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Spacer()
                Button("Done") { dismiss() }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                // 2x2 grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(BuddyType.allCases, id: \.rawValue) { buddy in
                        BuddyCard(
                            buddyType: buddy,
                            bondData: bondSystem.bondData(for: buddy),
                            isActive: buddy == bondSystem.activeBuddyType,
                            onSelect: {
                                onSelect(buddy)
                                dismiss()
                            }
                        )
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 440, minHeight: 400)
    }
}

// MARK: - Buddy Card

private struct BuddyCard: View {
    let buddyType: BuddyType
    let bondData: BuddyBondData
    let isActive: Bool
    let onSelect: () -> Void

    private var bondLevel: BondLevel { bondData.bondLevel }
    private var buddyColor: Color { buddyColorFor(buddyType) }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 10) {
                // Face image + name
                ZStack {
                    Circle()
                        .fill(buddyColor.opacity(0.3))
                        .frame(width: 64, height: 64)

                    Image("\(buddyType.rawValue)_face")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())

                    if isActive {
                        Circle()
                            .strokeBorder(Color.yellow, lineWidth: 3)
                            .frame(width: 68, height: 68)
                    } else {
                        Circle()
                            .strokeBorder(buddyColor.opacity(0.5), lineWidth: 2)
                            .frame(width: 64, height: 64)
                    }
                }

                // Name
                Text(buddyType.displayName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                // Subject specialty
                Text(buddyType.subject.rawValue)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)

                // Bond level badge
                HStack(spacing: 4) {
                    Text("\u{2764}\u{FE0F}")
                        .font(.system(size: 10))
                    Text(bondLevel.displayName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(bondLevelColor)
                }

                // Progress bar to next level
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(bondProgressColor)
                                .frame(width: geo.size.width * CGFloat(bondData.progressToNext), height: 6)
                        }
                    }
                    .frame(height: 6)

                    // Points display
                    if let nextThreshold = bondLevel.pointsToNext {
                        Text("\(bondData.totalPoints) / \(nextThreshold) pts")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(bondData.totalPoints) pts — MAX")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.yellow)
                    }
                }

                // Unlocked abilities
                VStack(alignment: .leading, spacing: 2) {
                    abilityRow("Hints", unlocked: bondLevel >= .goodBuddy)
                    abilityRow("+10% XP", unlocked: bondLevel >= .greatBuddy)
                    abilityRow("2nd Chance", unlocked: bondLevel >= .bestBuddy)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)

                // Active badge
                if isActive {
                    Text("ACTIVE")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.yellow))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isActive
                        ? buddyColor.opacity(0.08)
                        : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isActive ? Color.yellow.opacity(0.6) : buddyColor.opacity(0.2),
                        lineWidth: isActive ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func abilityRow(_ name: String, unlocked: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: unlocked ? "checkmark.circle.fill" : "lock.fill")
                .font(.system(size: 9))
                .foregroundColor(unlocked ? .green : .gray)
            Text(name)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(unlocked ? .primary : .secondary)
        }
    }

    private var bondLevelColor: Color {
        switch bondLevel {
        case .newFriend: return .secondary
        case .goodBuddy: return .blue
        case .greatBuddy: return .purple
        case .bestBuddy: return .yellow
        }
    }

    private var bondProgressColor: Color {
        switch bondLevel {
        case .newFriend: return .blue
        case .goodBuddy: return .purple
        case .greatBuddy: return .orange
        case .bestBuddy: return .yellow
        }
    }
}

// MARK: - Color Helper

private func buddyColorFor(_ type: BuddyType) -> Color {
    switch type {
    case .nova: return Color(red: 0, green: 0.7, blue: 0.7)
    case .lexie: return Color(red: 0.7, green: 0.4, blue: 0.86)
    case .digit: return Color(red: 0.3, green: 0.55, blue: 1.0)
    case .harmony: return Color(red: 1.0, green: 0.55, blue: 0.7)
    }
}
