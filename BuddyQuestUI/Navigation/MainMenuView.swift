import SwiftUI
import BuddyQuestKit

/// The main menu / title screen
public struct MainMenuView: View {
    @Binding var showGame: Bool
    @State private var showSettings = false
    @State private var showProfile = false
    @State private var animateTitle = false
    @State private var selectedBuddy: BuddyType = .lexie
    @State private var hoveredBuddy: BuddyType? = nil
    @ObservedObject private var profileManager = ProfileManager.shared

    let onSwitchProfile: () -> Void

    public init(showGame: Binding<Bool>, onSwitchProfile: @escaping () -> Void) {
        self._showGame = showGame
        self.onSwitchProfile = onSwitchProfile
    }

    public var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.15, green: 0.2, blue: 0.4),
                    Color(red: 0.25, green: 0.15, blue: 0.45),
                    Color(red: 0.1, green: 0.1, blue: 0.3)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Stars (decorative circles)
            StarFieldView()

            VStack(spacing: 0) {
                Spacer()

                // Title
                VStack(spacing: 8) {
                    Text("BuddyQuest")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .orange.opacity(0.5), radius: 10)
                        .scaleEffect(animateTitle ? 1.0 : 0.8)
                        .opacity(animateTitle ? 1.0 : 0)

                    Text("Learn Together, Grow Together")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .opacity(animateTitle ? 1.0 : 0)
                }
                .padding(.bottom, 16)

                // Active profile banner (tappable to show profile)
                if let profile = profileManager.activeProfile {
                    let rgb = profile.color.rgb
                    let profileColor = Color(red: rgb.r, green: rgb.g, blue: rgb.b)

                    Button {
                        showProfile = true
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(profileColor)
                                    .frame(width: 32, height: 32)
                                    .shadow(color: profileColor.opacity(0.5), radius: 4)
                                Text(profile.initial)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            Text("Playing as \(profile.name)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                            Text("· \(profile.gradeLevel.displayName)")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 24)
                }

                // Buddy character portraits (interactive)
                HStack(spacing: 16) {
                    ForEach(BuddyType.allCases, id: \.rawValue) { buddy in
                        BuddyPreviewCircle(
                            buddyType: buddy,
                            isSelected: selectedBuddy == buddy,
                            isHovered: hoveredBuddy == buddy
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedBuddy = buddy
                            }
                            // Persist selection
                            SaveSystem.shared.saveActiveBuddyType(buddy)
                        }
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                hoveredBuddy = hovering ? buddy : nil
                            }
                        }
                    }
                }
                .padding(.bottom, 12)

                // Buddy info card (shows on hover or for selected buddy)
                BuddyInfoCard(buddy: hoveredBuddy ?? selectedBuddy, isSelected: hoveredBuddy == nil || hoveredBuddy == selectedBuddy)
                    .animation(.easeInOut(duration: 0.2), value: hoveredBuddy)
                    .padding(.bottom, 32)

                // Buttons
                VStack(spacing: 16) {
                    Button {
                        showGame = true
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Adventure")
                        }
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 260, height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.3, green: 0.7, blue: 0.3),
                                            Color(red: 0.2, green: 0.55, blue: 0.2)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: .green.opacity(0.4), radius: 8, y: 4)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text("Settings")
                        }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 200, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.15))
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        onSwitchProfile()
                    } label: {
                        HStack {
                            Image(systemName: "person.2.fill")
                            Text("Switch Player")
                        }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 200, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.15))
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Version
                Text("v0.1.0 - Phase 1")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.bottom, 16)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animateTitle = true
            }
            // Load saved buddy selection
            if let saved = SaveSystem.shared.loadActiveBuddyType() {
                selectedBuddy = saved
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsPlaceholderView()
        }
        .sheet(isPresented: $showProfile) {
            MainMenuProfileSheet()
        }
    }
}

// MARK: - Buddy Preview Circle

struct BuddyPreviewCircle: View {
    let buddyType: BuddyType
    var isSelected: Bool = false
    var isHovered: Bool = false

    private var color: Color { menuBuddyColor(buddyType) }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Glow ring for selected buddy
                if isSelected {
                    Circle()
                        .fill(Color.yellow.opacity(0.15))
                        .frame(width: 78, height: 78)

                    Circle()
                        .strokeBorder(Color.yellow, lineWidth: 3)
                        .frame(width: 74, height: 74)
                }

                // Fallback colored circle (always rendered behind)
                Circle()
                    .fill(color)
                    .frame(width: 64, height: 64)

                // Character face image
                Image("\(buddyType.rawValue)_face")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())

                // Border ring
                if !isSelected {
                    Circle()
                        .strokeBorder(color.opacity(isHovered ? 0.9 : 0.6), lineWidth: isHovered ? 2.5 : 2)
                        .frame(width: 64, height: 64)
                }
            }
            .shadow(color: isSelected ? Color.yellow.opacity(0.5) : color.opacity(0.5), radius: isSelected ? 10 : 6)
            .scaleEffect(isHovered ? 1.1 : 1.0)

            Text(buddyType.displayName)
                .font(.system(size: 12, weight: isSelected ? .bold : .semibold, design: .rounded))
                .foregroundColor(isSelected ? .yellow : .white.opacity(0.8))
        }
        .contentShape(Circle())
    }
}

// MARK: - Buddy Info Card (shown below portraits)

struct BuddyInfoCard: View {
    let buddy: BuddyType
    var isSelected: Bool

    private var color: Color { menuBuddyColor(buddy) }

    private var personalityShort: String {
        switch buddy {
        case .nova: return "Curious & analytical — loves asking \"why?\" and \"how?\""
        case .lexie: return "Creative & expressive — loves words, stories, and poetry"
        case .digit: return "Logical & patient — loves numbers, patterns, and puzzles"
        case .harmony: return "Empathetic & warm — loves teamwork and helping others"
        }
    }

    private var catchphrase: String {
        switch buddy {
        case .nova: return "\"Fascinating! Let's experiment!\""
        case .lexie: return "\"Once upon a time...\""
        case .digit: return "\"Let me calculate...\""
        case .harmony: return "\"We're better together!\""
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Subject icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: subjectIcon(buddy))
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(buddy.displayName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("·")
                        .foregroundColor(.white.opacity(0.4))
                    Text(buddy.subject.rawValue)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(color)
                    if isSelected {
                        Text("SELECTED")
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.yellow.opacity(0.2)))
                    }
                }

                Text(personalityShort)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)

                Text(catchphrase)
                    .font(.system(size: 11, weight: .medium, design: .rounded).italic())
                    .foregroundColor(.white.opacity(0.45))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: 420)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(color.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func subjectIcon(_ buddy: BuddyType) -> String {
        switch buddy {
        case .nova: return "flask.fill"
        case .lexie: return "book.fill"
        case .digit: return "number"
        case .harmony: return "heart.fill"
        }
    }
}

// MARK: - Buddy Color Helper (Main Menu)

private func menuBuddyColor(_ type: BuddyType) -> Color {
    switch type {
    case .nova: return Color(red: 0, green: 0.7, blue: 0.7)
    case .lexie: return Color(red: 0.7, green: 0.4, blue: 0.86)
    case .digit: return Color(red: 0.3, green: 0.55, blue: 1.0)
    case .harmony: return Color(red: 1.0, green: 0.55, blue: 0.7)
    }
}

// MARK: - Star Field

struct StarFieldView: View {
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<30, id: \.self) { i in
                Circle()
                    .fill(Color.white)
                    .frame(width: CGFloat.random(in: 1...3), height: CGFloat.random(in: 1...3))
                    .position(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: 0...geometry.size.height)
                    )
                    .opacity(Double.random(in: 0.3...0.8))
            }
        }
    }
}

// MARK: - Main Menu Profile Sheet

struct MainMenuProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var profileManager = ProfileManager.shared
    @State private var showEditSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("My Profile")
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
                VStack(spacing: 20) {
                    // Profile card
                    if let profile = profileManager.activeProfile {
                        let rgb = profile.color.rgb
                        let profileColor = Color(red: rgb.r, green: rgb.g, blue: rgb.b)

                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(profileColor)
                                    .frame(width: 72, height: 72)
                                    .shadow(color: profileColor.opacity(0.5), radius: 8)
                                Text(profile.initial)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            Text(profile.name)
                                .font(.system(size: 24, weight: .bold, design: .rounded))

                            // Grade level with edit button
                            HStack(spacing: 8) {
                                Text(profile.gradeLevel.displayName)
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundColor(.secondary)

                                Button {
                                    showEditSheet = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "pencil.circle.fill")
                                        Text("Edit Profile")
                                    }
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(.top, 12)

                        // Info section
                        VStack(spacing: 12) {
                            profileInfoRow(
                                icon: "calendar",
                                label: "Playing Since",
                                value: profile.createdDate.formatted(date: .abbreviated, time: .omitted)
                            )
                            profileInfoRow(
                                icon: "graduationcap.fill",
                                label: "Grade Level",
                                value: profile.gradeLevel.displayName
                            )
                        }
                        .padding(.top, 8)

                        // Tip about grade changes
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 14))
                            Text("Moving up a grade? Tap \"Edit Profile\" to update your grade level. Questions will adjust to match!")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.yellow.opacity(0.08))
                        )
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 400, minHeight: 380)
        .sheet(isPresented: $showEditSheet) {
            if let profile = profileManager.activeProfile {
                ProfileCreateEditView(existingProfile: profile)
            }
        }
    }

    @ViewBuilder
    private func profileInfoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

// MARK: - Settings View

struct SettingsPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var aiManager = AIServiceManager.shared

    @State private var openAIKey: String = ""
    @State private var anthropicKey: String = ""
    @State private var testResult: String?
    @State private var isTesting = false
    @State private var refreshTimer: Timer?
    @State private var isCheckingAppleAI = false
    @State private var openAIKeySaved = false
    @State private var anthropicKeySaved = false
    @State private var showParentDashboard = false

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Text("Settings")
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

            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    // 1. CURRENT ACTIVE PROVIDER (big, clear)
                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    settingsSection(title: "Currently Active") {
                        HStack(spacing: 12) {
                            providerStatusIcon
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(aiManager.activeProvider.displayName)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                    statusBadge
                                }
                                Text(providerStatusDescription)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(activeProviderBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(activeProviderBorder, lineWidth: 1.5)
                        )
                    }

                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    // 2. SELECT AI PROVIDER
                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    settingsSection(title: "Select AI Provider") {
                        // Auto-select option
                        providerRow(
                            icon: "sparkles",
                            iconColor: .purple,
                            title: "Auto (Recommended)",
                            subtitle: "Automatically picks the best available provider",
                            isSelected: !aiManager.isManualOverride,
                            isAvailable: true
                        ) {
                            aiManager.selectProvider(nil)
                        }

                        // Provider list
                        ForEach(aiManager.availableProviders) { item in
                            providerRow(
                                icon: iconName(for: item.provider),
                                iconColor: iconColor(for: item.provider),
                                title: item.label,
                                subtitle: providerSubtitle(for: item.provider, available: item.available),
                                isSelected: aiManager.isManualOverride && aiManager.manualProvider == item.provider,
                                isAvailable: item.available || item.provider == .offline
                            ) {
                                if item.available || item.provider == .offline {
                                    aiManager.selectProvider(item.provider)
                                }
                            }
                        }
                    }

                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    // 3. APPLE INTELLIGENCE STATUS
                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    settingsSection(title: "Apple Intelligence Status") {
                        HStack(spacing: 10) {
                            Image(systemName: "apple.logo")
                                .font(.title3)
                                .foregroundColor(.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                if aiManager.appleIntelligenceAvailable {
                                    Text("Ready — Free, on-device, private")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(.green)
                                } else if aiManager.isAppleIntelligenceDownloading {
                                    HStack(spacing: 4) {
                                        ProgressView()
                                            .controlSize(.mini)
                                        Text("Model downloading — automatic, no action needed")
                                            .font(.system(size: 13, design: .rounded))
                                            .foregroundColor(.orange)
                                    }
                                } else {
                                    Text(aiManager.appleIntelligenceReason ?? "Not available on this device")
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundColor(.orange)
                                }
                            }
                            Spacer()
                            if aiManager.appleIntelligenceAvailable {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else if aiManager.isAppleIntelligenceDownloading {
                                Image(systemName: "arrow.down.circle")
                                    .foregroundColor(.orange)
                                    .symbolEffect(.pulse)
                            } else {
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))

                        if !aiManager.appleIntelligenceAvailable {
                            HStack(spacing: 8) {
                                Button {
                                    checkAppleIntelligence()
                                } label: {
                                    HStack(spacing: 4) {
                                        if isCheckingAppleAI {
                                            ProgressView()
                                                .controlSize(.mini)
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                        }
                                        Text("Check Again")
                                    }
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(isCheckingAppleAI)

                                if aiManager.isAppleIntelligenceDownloading {
                                    Text("macOS downloads the model automatically. Usually takes a few minutes.")
                                        .font(.system(size: 10, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        Text("Requires iPhone 15 Pro+ or M1+ Mac with iOS 26+ / macOS 26+ and Apple Intelligence enabled in System Settings.")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    // 4. CLOUD API KEYS
                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    settingsSection(title: "Cloud API Keys") {
                        // OpenAI
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "cloud.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("OpenAI API Key")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                Spacer()
                                if aiManager.hasOpenAIKey {
                                    Label("Saved", systemImage: "checkmark.circle.fill")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundColor(.green)
                                }
                            }
                            HStack(spacing: 8) {
                                SecureField("sk-...", text: $openAIKey)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12, design: .monospaced))
                                    .onSubmit { saveOpenAIKey() }
                                Button {
                                    saveOpenAIKey()
                                } label: {
                                    Text(openAIKeySaved ? "Saved ✓" : "Save")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .tint(openAIKeySaved ? .green : .blue)
                                .disabled(openAIKey.isEmpty)
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))

                        // Anthropic
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "cloud.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Anthropic API Key")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                Spacer()
                                if aiManager.hasAnthropicKey {
                                    Label("Saved", systemImage: "checkmark.circle.fill")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundColor(.green)
                                }
                            }
                            HStack(spacing: 8) {
                                SecureField("sk-ant-...", text: $anthropicKey)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12, design: .monospaced))
                                    .onSubmit { saveAnthropicKey() }
                                Button {
                                    saveAnthropicKey()
                                } label: {
                                    Text(anthropicKeySaved ? "Saved ✓" : "Save")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .tint(anthropicKeySaved ? .green : .blue)
                                .disabled(anthropicKey.isEmpty)
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))

                        Text("Keys are stored securely in your device Keychain. They never leave your device. No data is collected by BuddyQuest.")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    // 5. TEST CONNECTION
                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    if aiManager.isAIEnabled {
                        settingsSection(title: "Test Connection") {
                            HStack {
                                Button {
                                    testConnection()
                                } label: {
                                    HStack(spacing: 6) {
                                        if isTesting {
                                            ProgressView()
                                                .controlSize(.small)
                                        } else {
                                            Image(systemName: "antenna.radiowaves.left.and.right")
                                        }
                                        Text("Test \(aiManager.activeProvider.displayName)")
                                    }
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                }
                                .buttonStyle(.bordered)
                                .disabled(isTesting)

                                if let result = testResult {
                                    Text(result)
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundColor(result.contains("✓") ? .green : .red)
                                }
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
                        }
                    }

                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    // 6. USAGE STATS
                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    settingsSection(title: "Usage This Session") {
                        HStack {
                            Label("AI Calls", systemImage: "bubble.left.and.bubble.right")
                                .font(.system(size: 13, design: .rounded))
                            Spacer()
                            Text("\(aiManager.totalCallsThisSession)")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)

                        HStack {
                            Label("Cost", systemImage: "dollarsign.circle")
                                .font(.system(size: 13, design: .rounded))
                            Spacer()
                            if aiManager.activeProvider == .appleIntelligence {
                                Text("$0 — On-device")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.green)
                            } else if aiManager.activeProvider == .offline {
                                Text("$0 — Offline")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            } else {
                                Text(String(format: "$%.4f", aiManager.estimatedCostThisSession))
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                    }

                    // ── Phase 6 Placeholders ──
                    settingsSection(title: "Coming Soon") {
                        HStack {
                            Label("Audio & Music", systemImage: "speaker.wave.2")
                            Spacer()
                            Text("Phase 6")
                                .foregroundColor(.secondary)
                        }
                        .font(.system(size: 13, design: .rounded))
                        .padding(.horizontal, 12).padding(.vertical, 8)

                        Button { showParentDashboard = true } label: {
                            HStack {
                                Label("Parent Dashboard", systemImage: "lock.shield")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .font(.system(size: 13, design: .rounded))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showParentDashboard) {
                            ParentGateView()
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 460, minHeight: 580)
        .onAppear {
            startAutoRefreshIfNeeded()
        }
        .onDisappear {
            stopAutoRefresh()
        }
    }

    // MARK: - Provider Row

    @ViewBuilder
    private func providerRow(
        icon: String, iconColor: Color,
        title: String, subtitle: String,
        isSelected: Bool, isAvailable: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isAvailable ? iconColor : .secondary.opacity(0.5))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundColor(isAvailable ? .primary : .secondary)
                    Text(subtitle)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                } else if !isAvailable {
                    Text("Unavailable")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.6))
                } else {
                    Circle()
                        .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable && icon != "internaldrive") // Offline is always available
    }

    // MARK: - Reusable Section

    @ViewBuilder
    private func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(0.5)
            content()
        }
    }

    // MARK: - Helpers

    private func iconName(for provider: AIProvider) -> String {
        switch provider {
        case .appleIntelligence: return "apple.logo"
        case .openAI: return "cloud.fill"
        case .anthropic: return "cloud.fill"
        case .offline: return "internaldrive"
        }
    }

    private func iconColor(for provider: AIProvider) -> Color {
        switch provider {
        case .appleIntelligence: return .blue
        case .openAI: return .green
        case .anthropic: return .orange
        case .offline: return .secondary
        }
    }

    private func providerSubtitle(for provider: AIProvider, available: Bool) -> String {
        switch provider {
        case .appleIntelligence:
            if available { return "Free, private, no internet needed" }
            return aiManager.appleIntelligenceReason ?? "Not available"
        case .openAI:
            if available { return "GPT-4o-mini · Uses your API key" }
            return "Enter API key below to enable"
        case .anthropic:
            if available { return "Claude 3.5 Haiku · Uses your API key" }
            return "Enter API key below to enable"
        case .offline:
            return "Built-in question bank · Always works"
        }
    }

    private var providerStatusIcon: some View {
        Group {
            switch aiManager.activeProvider {
            case .appleIntelligence:
                Image(systemName: "apple.logo")
                    .foregroundColor(.blue)
            case .openAI:
                Image(systemName: "cloud.fill")
                    .foregroundColor(.green)
            case .anthropic:
                Image(systemName: "cloud.fill")
                    .foregroundColor(.orange)
            case .offline:
                Image(systemName: "internaldrive")
                    .foregroundColor(.secondary)
            }
        }
        .font(.title2)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch aiManager.activeProvider {
        case .appleIntelligence:
            Text("ON-DEVICE")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(.blue))
        case .openAI, .anthropic:
            Text("CLOUD")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(.green))
        case .offline:
            Text("OFFLINE")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(.gray))
        }
    }

    private var activeProviderBackground: Color {
        switch aiManager.activeProvider {
        case .appleIntelligence: return Color.blue.opacity(0.08)
        case .openAI: return Color.green.opacity(0.08)
        case .anthropic: return Color.orange.opacity(0.08)
        case .offline: return Color.primary.opacity(0.04)
        }
    }

    private var activeProviderBorder: Color {
        switch aiManager.activeProvider {
        case .appleIntelligence: return Color.blue.opacity(0.3)
        case .openAI: return Color.green.opacity(0.3)
        case .anthropic: return Color.orange.opacity(0.3)
        case .offline: return Color.primary.opacity(0.1)
        }
    }

    private var providerStatusDescription: String {
        let modeLabel = aiManager.isManualOverride ? "(Manual)" : "(Auto-selected)"
        switch aiManager.activeProvider {
        case .appleIntelligence: return "Free, on-device AI \(modeLabel)"
        case .openAI: return "Using your OpenAI API key \(modeLabel)"
        case .anthropic: return "Using your Anthropic API key \(modeLabel)"
        case .offline: return "Using built-in question bank \(modeLabel)"
        }
    }

    // MARK: - Actions

    private func saveOpenAIKey() {
        guard !openAIKey.isEmpty else { return }
        aiManager.setOpenAIKey(openAIKey)
        openAIKeySaved = true
        openAIKey = "" // Clear from field after saving
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            openAIKeySaved = false
        }
    }

    private func saveAnthropicKey() {
        guard !anthropicKey.isEmpty else { return }
        aiManager.setAnthropicKey(anthropicKey)
        anthropicKeySaved = true
        anthropicKey = "" // Clear from field after saving
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            anthropicKeySaved = false
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        Task {
            let result = await aiManager.testConnection()
            await MainActor.run {
                testResult = result.success ? "✓ \(result.message)" : "✗ \(result.message)"
                isTesting = false
            }
        }
    }

    private func checkAppleIntelligence() {
        isCheckingAppleAI = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            aiManager.refreshAppleIntelligenceStatus()
            isCheckingAppleAI = false
        }
    }

    private func startAutoRefreshIfNeeded() {
        guard aiManager.isAppleIntelligenceDownloading else {
            stopAutoRefresh()
            return
        }
        guard refreshTimer == nil else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
            aiManager.refreshAppleIntelligenceStatus()
            if aiManager.appleIntelligenceAvailable {
                stopAutoRefresh()
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
