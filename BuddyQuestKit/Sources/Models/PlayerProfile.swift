import Foundation

// MARK: - Profile Color

/// A fixed palette of kid-friendly avatar colors.
public enum ProfileColor: String, CaseIterable, Codable, Sendable {
    case red, orange, yellow, green, blue, purple, pink, teal

    /// Hex color value for rendering
    public var hex: String {
        switch self {
        case .red:    return "#E74C3C"
        case .orange: return "#F39C12"
        case .yellow: return "#F1C40F"
        case .green:  return "#2ECC71"
        case .blue:   return "#3498DB"
        case .purple: return "#9B59B6"
        case .pink:   return "#E91E8B"
        case .teal:   return "#1ABC9C"
        }
    }

    /// RGB components (0-1 range) for cross-platform rendering
    public var rgb: (r: Double, g: Double, b: Double) {
        let hex = self.hex.dropFirst()  // remove '#'
        let scanner = Scanner(string: String(hex))
        var val: UInt64 = 0
        scanner.scanHexInt64(&val)
        return (
            r: Double((val >> 16) & 0xFF) / 255.0,
            g: Double((val >> 8) & 0xFF) / 255.0,
            b: Double(val & 0xFF) / 255.0
        )
    }
}

// MARK: - Player Profile

/// A kid's profile — contains their name, avatar, grade level, and links to their save data.
public struct PlayerProfile: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var color: ProfileColor
    public var gradeLevel: GradeLevel
    public var createdDate: Date

    public init(
        id: UUID = UUID(),
        name: String,
        color: ProfileColor,
        gradeLevel: GradeLevel,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.gradeLevel = gradeLevel
        self.createdDate = createdDate
    }

    /// The first letter of the name, uppercased, for the avatar circle
    public var initial: String {
        String(name.prefix(1)).uppercased()
    }
}
