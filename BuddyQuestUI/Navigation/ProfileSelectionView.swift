import SwiftUI
import BuddyQuestKit

/// First screen on app launch — "Who's Playing?"
/// Shows existing profiles (up to 3) and lets kids select or create profiles.
struct ProfileSelectionView: View {
    @ObservedObject private var profileManager = ProfileManager.shared

    let onProfileSelected: (UUID) -> Void

    @State private var showCreateProfile = false
    @State private var editingProfile: PlayerProfile? = nil
    @State private var deletingProfile: PlayerProfile? = nil
    @State private var showDeleteConfirm = false
    @State private var hasCheckedAutoShow = false

    var body: some View {
        ZStack {
            // Background gradient (matches MainMenuView style)
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.18),
                    Color(red: 0.15, green: 0.10, blue: 0.30),
                    Color(red: 0.10, green: 0.08, blue: 0.22)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Decorative stars
            decorativeStars

            VStack(spacing: 30) {
                Spacer()

                // Title
                Text("Who's Playing?")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .orange.opacity(0.3), radius: 8, y: 4)

                Text("Choose your profile to continue your adventure")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))

                // Profile cards
                HStack(spacing: 20) {
                    ForEach(profileManager.profiles) { profile in
                        profileCard(profile)
                    }

                    // "Add" slot (if under max)
                    if profileManager.canCreateProfile {
                        addProfileCard
                    }
                }
                .padding(.horizontal, 40)

                Spacer()

                // Subtitle
                Text("Up to \(ProfileManager.maxProfiles) players can share this device")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.bottom, 30)
            }
        }
        .onAppear {
            // Auto-show creation sheet if no profiles exist
            if !hasCheckedAutoShow {
                hasCheckedAutoShow = true
                if profileManager.profiles.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCreateProfile = true
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateProfile) {
            ProfileCreateEditView(existingProfile: nil)
        }
        .sheet(item: $editingProfile) { profile in
            ProfileCreateEditView(existingProfile: profile)
        }
        .alert("Delete Profile?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {
                deletingProfile = nil
            }
            Button("Delete", role: .destructive) {
                if let profile = deletingProfile {
                    profileManager.deleteProfile(id: profile.id)
                }
                deletingProfile = nil
            }
        } message: {
            if let profile = deletingProfile {
                Text("This will erase \(profile.name)'s adventure and all their progress. This cannot be undone.")
            }
        }
    }

    // MARK: - Profile Card

    @ViewBuilder
    private func profileCard(_ profile: PlayerProfile) -> some View {
        let color = profileSwiftUIColor(profile.color)
        Button {
            onProfileSelected(profile.id)
        } label: {
            VStack(spacing: 10) {
                // Avatar circle
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 80, height: 80)
                        .shadow(color: color.opacity(0.4), radius: 8)

                    Text(profile.initial)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                // Name
                Text(profile.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Grade
                Text(profile.gradeLevel.displayName)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(width: 120, height: 160)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(color.opacity(0.4), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                editingProfile = profile
            } label: {
                Label("Edit Profile", systemImage: "pencil")
            }
            Button(role: .destructive) {
                deletingProfile = profile
                showDeleteConfirm = true
            } label: {
                Label("Delete Profile", systemImage: "trash")
            }
        }
    }

    // MARK: - Add Profile Card

    private var addProfileCard: some View {
        Button {
            showCreateProfile = true
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 80, height: 80)

                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                Text("Add Player")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))

                Text(" ")
                    .font(.system(size: 12))
            }
            .frame(width: 120, height: 160)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Decorative Stars

    private var decorativeStars: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            ForEach(0..<20, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.1...0.5)))
                    .frame(width: CGFloat.random(in: 2...5))
                    .position(
                        x: CGFloat.random(in: 0...width),
                        y: CGFloat.random(in: 0...height)
                    )
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Color Helper

    private func profileSwiftUIColor(_ color: ProfileColor) -> Color {
        let rgb = color.rgb
        return Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }
}
