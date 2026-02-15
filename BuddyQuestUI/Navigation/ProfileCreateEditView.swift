import SwiftUI
import BuddyQuestKit

/// Sheet for creating or editing a player profile.
struct ProfileCreateEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var profileManager = ProfileManager.shared

    /// If non-nil, we're editing this profile. Otherwise creating a new one.
    let existingProfile: PlayerProfile?
    var onSaved: (() -> Void)?

    @State private var name: String = ""
    @State private var selectedColor: ProfileColor = .blue
    @State private var selectedGrade: GradeLevel = .third

    private var isEditing: Bool { existingProfile != nil }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Profile" : "New Player")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // ── Name ──
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NAME")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .tracking(0.5)

                        TextField("Enter your name", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 16, design: .rounded))
                            .onChange(of: name) { _, newValue in
                                if newValue.count > 12 {
                                    name = String(newValue.prefix(12))
                                }
                            }
                    }

                    // ── Avatar Color ──
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AVATAR COLOR")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .tracking(0.5)

                        HStack(spacing: 12) {
                            ForEach(ProfileColor.allCases, id: \.self) { color in
                                colorCircle(color)
                            }
                        }
                    }

                    // ── Grade Level ──
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GRADE LEVEL")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .tracking(0.5)

                        Text("Questions will match this grade. The app adjusts further based on performance.")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: [
                            GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(GradeLevel.allCases, id: \.rawValue) { grade in
                                gradeButton(grade)
                            }
                        }
                    }

                    // ── Preview ──
                    if isValid {
                        HStack(spacing: 12) {
                            profileAvatar(name: name, color: selectedColor, size: 50)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(name.trimmingCharacters(in: .whitespaces))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                Text(selectedGrade.displayName)
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.primary.opacity(0.05))
                        )
                    }
                }
                .padding(24)
            }

            Divider()

            // Save/Create button
            Button {
                saveProfile()
            } label: {
                Text(isEditing ? "Save Changes" : "Create Player")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isValid ? profileSwiftUIColor(selectedColor) : Color.gray)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isValid)
            .padding(20)
        }
        .frame(minWidth: 380, minHeight: 500)
        .onAppear {
            if let profile = existingProfile {
                name = profile.name
                selectedColor = profile.color
                selectedGrade = profile.gradeLevel
            }
        }
    }

    // MARK: - Color Circle

    @ViewBuilder
    private func colorCircle(_ color: ProfileColor) -> some View {
        let isSelected = selectedColor == color
        Circle()
            .fill(profileSwiftUIColor(color))
            .frame(width: 36, height: 36)
            .overlay(
                Circle().strokeBorder(Color.white, lineWidth: isSelected ? 3 : 0)
            )
            .overlay(
                Group {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            )
            .shadow(color: isSelected ? profileSwiftUIColor(color).opacity(0.5) : .clear, radius: 4)
            .onTapGesture {
                selectedColor = color
            }
    }

    // MARK: - Grade Button

    @ViewBuilder
    private func gradeButton(_ grade: GradeLevel) -> some View {
        let isSelected = selectedGrade == grade
        Button {
            selectedGrade = grade
        } label: {
            Text(grade.displayName)
                .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? profileSwiftUIColor(selectedColor) : Color.primary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Avatar Preview

    @ViewBuilder
    private func profileAvatar(name: String, color: ProfileColor, size: CGFloat) -> some View {
        let initial = String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
        ZStack {
            Circle()
                .fill(profileSwiftUIColor(color))
                .frame(width: size, height: size)
            Text(initial.isEmpty ? "?" : initial)
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }

    // MARK: - Actions

    private func saveProfile() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let existing = existingProfile {
            var updated = existing
            updated.name = trimmedName
            updated.color = selectedColor
            updated.gradeLevel = selectedGrade
            profileManager.updateProfile(updated)
        } else {
            let profile = PlayerProfile(
                name: trimmedName,
                color: selectedColor,
                gradeLevel: selectedGrade
            )
            profileManager.createProfile(profile)
        }
        onSaved?()
        dismiss()
    }

    // MARK: - Color Helper

    private func profileSwiftUIColor(_ color: ProfileColor) -> Color {
        let rgb = color.rgb
        return Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }
}
