import SwiftUI
import BuddyQuestKit

/// Renders a full progress report with overall stats, per-subject cards, domain breakdowns,
/// and personalized recommendations based on California education standards.
struct ProgressReportView: View {
    let report: ProgressReport

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Report header
                reportHeader

                // Overall stats
                overallStatsCard

                // Per-subject reports
                ForEach(report.subjectReports) { subjectReport in
                    SubjectReportCard(subjectReport: subjectReport)
                }

                // Top recommendations
                if !report.topRecommendations.isEmpty {
                    topRecommendationsCard
                }

                // Footer
                reportFooter
            }
            .padding(20)
        }
    }

    // MARK: - Report Header

    private var reportHeader: some View {
        VStack(spacing: 6) {
            Text(report.profileName)
                .font(.system(size: 24, weight: .bold, design: .rounded))

            HStack(spacing: 16) {
                Label(report.enrolledGrade.displayName, systemImage: "graduationcap")
                Label("Playing since \(report.playingSince.formatted(.dateTime.month(.wide).year()))",
                      systemImage: "calendar")
            }
            .font(.system(size: 12, design: .rounded))
            .foregroundColor(.secondary)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Overall Stats

    private var overallStatsCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                statBubble(
                    value: "\(report.playerLevel)",
                    label: "Level",
                    icon: "star.fill",
                    color: .yellow
                )
                statBubble(
                    value: "\(report.totalXP)",
                    label: "Total XP",
                    icon: "bolt.fill",
                    color: .orange
                )
                statBubble(
                    value: "\(report.totalQuestionsAnswered)",
                    label: "Questions",
                    icon: "questionmark.circle.fill",
                    color: .blue
                )
                statBubble(
                    value: "\(Int(report.overallAccuracy * 100))%",
                    label: "Accuracy",
                    icon: "target",
                    color: accuracyColor(report.overallAccuracy)
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        )
    }

    private func statBubble(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Top Recommendations

    private var topRecommendationsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Top Recommendations", systemImage: "lightbulb.fill")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.orange)

            ForEach(Array(report.topRecommendations.enumerated()), id: \.offset) { _, rec in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                        .padding(.top, 2)
                    Text(rec)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Footer

    private var reportFooter: some View {
        Text("Report generated \(report.generatedDate.formatted(.dateTime.month(.wide).day().year().hour().minute()))")
            .font(.system(size: 10, design: .rounded))
            .foregroundColor(.secondary)
            .padding(.top, 8)
    }

    // MARK: - Helpers

    private var cardBackground: Color {
        #if os(macOS)
        Color(.windowBackgroundColor).opacity(0.5)
        #else
        Color(.systemBackground).opacity(0.5)
        #endif
    }

    private func accuracyColor(_ accuracy: Double) -> Color {
        if accuracy >= 0.8 { return .green }
        if accuracy >= 0.5 { return .yellow }
        return .red
    }
}

// MARK: - Subject Report Card

private struct SubjectReportCard: View {
    let subjectReport: SubjectReport
    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            // Header — always visible
            Button { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } } label: {
                subjectHeader
            }
            .buttonStyle(.plain)

            // Expandable content
            if isExpanded {
                VStack(spacing: 12) {
                    Divider()

                    // Working level
                    workingLevelRow

                    // Domain grid
                    domainGrid

                    // Subject recommendations
                    if !subjectReport.recommendations.isEmpty {
                        subjectRecommendations
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Subject Header

    private var subjectHeader: some View {
        HStack(spacing: 12) {
            // Subject icon
            Image(systemName: iconForSubject(subjectReport.subject))
                .font(.system(size: 20))
                .foregroundColor(colorForSubject(subjectReport.subject))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(colorForSubject(subjectReport.subject).opacity(0.15))
                )

            // Name + question count
            VStack(alignment: .leading, spacing: 2) {
                Text(subjectReport.subject.rawValue)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text("\(subjectReport.totalAttempted) questions attempted")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Accuracy + trend
            if subjectReport.totalAttempted > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(subjectReport.accuracy * 100))%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(accuracyColor(subjectReport.accuracy))

                    HStack(spacing: 3) {
                        Image(systemName: subjectReport.trend.symbolName)
                            .font(.system(size: 10))
                        Text(subjectReport.trend.rawValue)
                            .font(.system(size: 10, design: .rounded))
                    }
                    .foregroundColor(.secondary)
                }
            }

            // Chevron
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(14)
    }

    // MARK: - Working Level

    private var workingLevelRow: some View {
        HStack {
            Label("Working Level", systemImage: "chart.line.uptrend.xyaxis")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)
            Spacer()

            let enrolled = subjectReport.workingGradeLevel == subjectReport.workingGradeLevel // always true, we compare against enrolled
            let workingName = subjectReport.workingGradeLevel.displayName
            let difficultyName = difficultyDisplayName(subjectReport.currentDifficulty)

            Text("\(workingName) • \(difficultyName)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
        }
    }

    // MARK: - Domain Grid

    private var domainGrid: some View {
        VStack(spacing: 6) {
            ForEach(subjectReport.domains) { domain in
                DomainRow(domain: domain)
            }
        }
    }

    // MARK: - Recommendations

    private var subjectRecommendations: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(subjectReport.recommendations.enumerated()), id: \.offset) { _, rec in
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(rec)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private var cardBackground: Color {
        #if os(macOS)
        Color(.windowBackgroundColor).opacity(0.5)
        #else
        Color(.systemBackground).opacity(0.5)
        #endif
    }

    private func accuracyColor(_ accuracy: Double) -> Color {
        if accuracy >= 0.8 { return .green }
        if accuracy >= 0.5 { return .orange }
        return .red
    }

    private func iconForSubject(_ subject: Subject) -> String {
        switch subject {
        case .math: return "function"
        case .languageArts: return "book.fill"
        case .science: return "flask.fill"
        case .social: return "person.3.fill"
        }
    }

    private func colorForSubject(_ subject: Subject) -> Color {
        switch subject {
        case .math: return .blue
        case .languageArts: return .green
        case .science: return .purple
        case .social: return .orange
        }
    }

    private func difficultyDisplayName(_ difficulty: DifficultyLevel) -> String {
        switch difficulty {
        case .beginner: return "Beginner"
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .advanced: return "Advanced"
        }
    }
}

// MARK: - Domain Row

private struct DomainRow: View {
    let domain: DomainReport

    var body: some View {
        HStack(spacing: 8) {
            // Mastery badge
            Image(systemName: domain.masteryLevel.symbolName)
                .font(.system(size: 13))
                .foregroundColor(masteryColor)
                .frame(width: 18)

            // Domain name
            Text(domain.domain.shortName)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .frame(width: 100, alignment: .leading)

            // Accuracy bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.15))

                    // Fill
                    if domain.questionsAttempted > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(masteryColor.opacity(0.7))
                            .frame(width: geo.size.width * domain.accuracy)
                    }
                }
            }
            .frame(height: 8)

            // Stats
            if domain.questionsAttempted > 0 {
                Text("\(domain.questionsCorrect)/\(domain.questionsAttempted)")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
            } else {
                Text("—")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }

            // Trend arrow
            Image(systemName: domain.trend.symbolName)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .frame(width: 14)
        }
        .frame(height: 20)
    }

    private var masteryColor: Color {
        switch domain.masteryLevel {
        case .mastered: return .green
        case .inProgress: return .yellow
        case .needsWork: return .red
        case .notStarted: return .gray
        }
    }
}
