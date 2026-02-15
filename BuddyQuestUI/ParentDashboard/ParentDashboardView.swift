import SwiftUI
import BuddyQuestKit

/// Main parent dashboard — profile picker + progress report display.
struct ParentDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var profileManager = ProfileManager.shared

    @State private var selectedProfileId: UUID?
    @State private var report: ProgressReport?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            headerBar

            Divider()

            if profileManager.profiles.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    // Profile picker
                    profilePicker
                        .padding(.vertical, 12)

                    Divider()

                    // Report content
                    if isLoading {
                        Spacer()
                        ProgressView("Generating report…")
                            .font(.system(size: 14, design: .rounded))
                        Spacer()
                    } else if let report = report {
                        ProgressReportView(report: report)
                    } else {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("Select a profile to view their progress report")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
        .onAppear {
            // Auto-select first profile if none selected
            if selectedProfileId == nil, let first = profileManager.profiles.first {
                selectProfile(first)
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Text("Back")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)

            Spacer()

            Text("Progress Report")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Spacer()

            // Invisible spacer to balance the back button
            Text("Back")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .hidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Profile Picker

    private var profilePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(profileManager.profiles) { profile in
                    profileChip(profile)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func profileChip(_ profile: PlayerProfile) -> some View {
        let isSelected = selectedProfileId == profile.id
        return Button {
            selectProfile(profile)
        } label: {
            VStack(spacing: 6) {
                // Avatar circle
                ZStack {
                    Circle()
                        .fill(colorForProfile(profile))
                        .frame(width: 50, height: 50)

                    Text(profile.name.prefix(1).uppercased())
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                )

                Text(profile.name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundColor(isSelected ? .primary : .secondary)

                Text(profile.gradeLevel.displayName)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No profiles yet")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
            Text("Create a player profile to start tracking progress.")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Logic

    private func selectProfile(_ profile: PlayerProfile) {
        selectedProfileId = profile.id
        isLoading = true
        report = nil

        // Generate report on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let saveData = SaveSystem.shared.loadSaveData(for: profile.id)
            let history = ChallengeHistoryLog.shared.loadEntries(for: profile.id)
            let generated = ProgressReportGenerator.generate(
                profile: profile,
                saveData: saveData,
                history: history
            )
            DispatchQueue.main.async {
                self.report = generated
                self.isLoading = false
            }
        }
    }

    private func colorForProfile(_ profile: PlayerProfile) -> Color {
        let colors: [Color] = [
            .blue, .purple, .green, .orange, .pink, .teal
        ]
        let index = abs(profile.name.hashValue) % colors.count
        return colors[index]
    }
}
