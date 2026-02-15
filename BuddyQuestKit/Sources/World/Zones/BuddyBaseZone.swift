import Foundation

/// The hub world - Buddy Base
/// Central area with portals to each subject zone
public enum BuddyBaseZone {

    public static func create() -> Zone {
        let zone = Zone(
            id: "buddy_base",
            name: "Buddy Base",
            subject: nil,
            musicTrack: "hub_theme",
            requiredLevel: 0
        )

        zone.registerRoom(id: "hub_main") { createHubMain() }
        zone.registerRoom(id: "hub_courtyard") { createHubCourtyard() }
        zone.registerRoom(id: "hub_library") { createHubLibrary() }

        return zone
    }

    // MARK: - Hub Main Room

    private static func createHubMain() -> Room {
        let w = 20
        let h = 15

        // ───────────────────────────────────────────────
        // Layout sketch (data-space, row 0 = top):
        //
        //  Row 0  (north wall):  Word Forest portal at col 4
        //                        Courtyard door at col 15
        //  Col 0  (west wall):   Teamwork Arena portal at row 4
        //  Col 19 (east wall):   Number Peaks portal at row 4
        //                        Library door at row 11
        //  Row 14 (south wall):  Science Lab portal at col 13
        //
        // The idea: doors are spread out like a real hall —
        // not centered, not symmetric. Each doorway has floor
        // tiles underneath so you can see where to walk.
        // ───────────────────────────────────────────────

        // Floor layer — warm wooden floor with stone borders
        var floor = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)
        for row in 0..<h {
            for col in 0..<w {
                if row == 0 || row == h-1 || col == 0 || col == w-1 {
                    floor[row][col] = .stoneFloor
                } else {
                    floor[row][col] = .woodFloor
                }
            }
        }

        // Stone paths from center toward each door (helps guide the player)
        // Path to Word Forest (north-left, col 4): vertical from row 1 down to row 4
        for row in 1..<5 { floor[row][4] = .stoneFloor }
        // Path to Courtyard (north-right, col 15): vertical from row 1 down to row 4
        for row in 1..<5 { floor[row][15] = .stoneFloor }
        // Path to Teamwork Arena (west, row 4): horizontal from col 1 across to col 4
        for col in 1..<5 { floor[4][col] = .stoneFloor }
        // Path to Number Peaks (east-upper, row 4): horizontal from col 15 across to east wall
        for col in 15..<w { floor[4][col] = .stoneFloor }
        // Horizontal connector along row 4 between left and right paths
        for col in 4..<16 { floor[4][col] = .stoneFloor }
        // Path to Library (east-lower, row 11): horizontal from col 13 across to east wall
        for col in 13..<w { floor[11][col] = .stoneFloor }
        // Path to Science Lab (south, col 13): vertical from row 11 down to south wall
        for row in 11..<h { floor[row][13] = .stoneFloor }
        // Vertical connector along col 13 from row 4 down to row 11
        for row in 4..<12 { floor[row][13] = .stoneFloor }

        // Wall layer — solid walls with openings for doors
        var walls = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)
        for col in 0..<w {
            walls[0][col] = .wall       // North wall
            walls[h-1][col] = .wall     // South wall
        }
        for row in 0..<h {
            walls[row][0] = .wall       // West wall
            walls[row][w-1] = .wall     // East wall
        }

        // --- Portal openings (magical portals with portal tile) ---

        // Word Forest portal — north wall, left side (col 4)
        walls[0][4] = .portal

        // Teamwork Arena portal — west wall, upper area (row 4)
        walls[4][0] = .portal

        // Number Peaks portal — east wall, upper area (row 4)
        walls[4][w-1] = .portal

        // Science Lab portal — south wall, right-of-center (col 13)
        walls[h-1][13] = .portal

        // --- Regular door openings (gap in wall, no portal tile) ---

        // Courtyard — north wall, right side (col 15), 2-tile wide gap
        walls[0][15] = .empty
        walls[0][16] = .empty

        // Library — east wall, lower area (row 11), 2-tile wide gap
        walls[11][w-1] = .empty
        walls[12][w-1] = .empty

        // Decorations — bookshelves, tables, flowers
        var decorations = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)
        // Bookshelves along north wall (between the two north doors)
        decorations[1][8] = .bookshelf
        decorations[1][9] = .bookshelf
        decorations[1][10] = .bookshelf
        decorations[1][11] = .bookshelf
        // Tables in the central area
        decorations[7][9] = .table
        decorations[7][10] = .table
        // Decorative elements
        decorations[10][3] = .flower
        decorations[3][16] = .flower
        decorations[12][6] = .flower

        // Door definitions
        let doors = [
            // --- Zone portals (magical, require levels) ---
            DoorDefinition(
                id: "portal_word_forest",
                position: (col: 4, row: 0),
                targetRoomId: "forest_entrance",
                targetZoneId: "word_forest",
                spawnPosition: (col: 7, row: 13),
                requiredLevel: 1,
                lockedMessage: "The Word Forest awaits when you're ready!",
                label: "Word Forest"
            ),
            DoorDefinition(
                id: "portal_number_peaks",
                position: (col: w-1, row: 4),
                targetRoomId: "peaks_base",
                targetZoneId: "number_peaks",
                spawnPosition: (col: 1, row: 7),
                requiredLevel: 3,
                lockedMessage: "Reach level 3 to explore Number Peaks!",
                label: "Number Peaks"
            ),
            DoorDefinition(
                id: "portal_science_lab",
                position: (col: 13, row: h-1),
                targetRoomId: "lab_lobby",
                targetZoneId: "science_lab",
                spawnPosition: (col: 7, row: 1),
                requiredLevel: 5,
                lockedMessage: "Reach level 5 to enter the Science Lab!",
                label: "Science Lab"
            ),
            DoorDefinition(
                id: "portal_teamwork",
                position: (col: 0, row: 4),
                targetRoomId: "arena_entrance",
                targetZoneId: "teamwork_arena",
                spawnPosition: (col: 13, row: 7),
                requiredLevel: 2,
                lockedMessage: "Unlock a second buddy to enter the Teamwork Arena!",
                label: "Teamwork Arena"
            ),
            // --- Local doors (no level requirement, just openings) ---
            DoorDefinition(
                id: "door_courtyard",
                position: (col: 15, row: 0),
                targetRoomId: "hub_courtyard",
                spawnPosition: (col: 7, row: 13),
                label: "Courtyard"
            ),
            DoorDefinition(
                id: "door_courtyard_2",
                position: (col: 16, row: 0),
                targetRoomId: "hub_courtyard",
                spawnPosition: (col: 7, row: 13),
                label: "Courtyard"
            ),
            DoorDefinition(
                id: "door_library",
                position: (col: w-1, row: 11),
                targetRoomId: "hub_library",
                spawnPosition: (col: 1, row: 5),
                label: "Library"
            ),
            DoorDefinition(
                id: "door_library_2",
                position: (col: w-1, row: 12),
                targetRoomId: "hub_library",
                spawnPosition: (col: 1, row: 5),
                label: "Library"
            ),
        ]

        // NPC — guide character near center
        let npcs = [
            NPCSpawnDefinition(
                id: "guide_pip",
                name: "Pip the Guide",
                position: (col: 9, row: 8),
                dialogueId: "guide_intro"
            )
        ]

        return Room(
            id: "hub_main",
            name: "Buddy Base - Main Hall",
            width: w,
            height: h,
            floorLayer: floor,
            wallLayer: walls,
            decorationLayer: decorations,
            doors: doors,
            npcSpawns: npcs,
            playerSpawn: (col: 10, row: 10),
            musicTrack: "hub_theme"
        )
    }

    // MARK: - Hub Courtyard

    private static func createHubCourtyard() -> Room {
        let w = 15
        let h = 15

        // Open grassy area
        var floor = Array(repeating: Array(repeating: TileType.grass, count: w), count: h)
        // Stone path down the center
        for row in 0..<h {
            floor[row][w/2] = .path
            floor[row][w/2 - 1] = .path
        }
        // Small pond
        for row in 4..<7 {
            for col in 9..<12 {
                floor[row][col] = .water
            }
        }

        // Walls around edges with an opening south
        var walls = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)
        for col in 0..<w {
            walls[0][col] = .tree
        }
        for row in 0..<h {
            walls[row][0] = .tree
            walls[row][w-1] = .tree
        }
        // South wall with door back
        for col in 0..<w {
            if col != w/2 {
                walls[h-1][col] = .tree
            }
        }

        // Flowers as decoration
        var decorations = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)
        decorations[3][3] = .flower
        decorations[5][2] = .flower
        decorations[7][4] = .flower
        decorations[10][11] = .flower
        decorations[8][12] = .flower

        let doors = [
            DoorDefinition(
                id: "door_back_to_hub",
                position: (col: w/2, row: h-1),
                targetRoomId: "hub_main",
                spawnPosition: (col: 15, row: 1),
                label: "Main Hall"
            )
        ]

        return Room(
            id: "hub_courtyard",
            name: "Buddy Base - Courtyard",
            width: w,
            height: h,
            floorLayer: floor,
            wallLayer: walls,
            decorationLayer: decorations,
            doors: doors,
            playerSpawn: (col: w/2, row: h - 3),
            musicTrack: "hub_theme"
        )
    }

    // MARK: - Hub Library

    private static func createHubLibrary() -> Room {
        let w = 12
        let h = 10

        // Floor layer - lab/stone floor throughout
        var floor = Array(repeating: Array(repeating: TileType.labFloor, count: w), count: h)
        // Warm wood floor center area (reading nook)
        for row in 3..<7 {
            for col in 4..<8 {
                floor[row][col] = .woodFloor
            }
        }

        // Wall layer
        var walls = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)
        for col in 0..<w {
            walls[0][col] = .wall       // North wall
            walls[h-1][col] = .wall     // South wall
        }
        for row in 0..<h {
            walls[row][0] = .wall       // West wall (entrance)
            walls[row][w-1] = .wall     // East wall
        }

        // Door opening on west wall (entrance from hub_main)
        walls[h/2][0] = .empty         // Gap in the wall for entrance

        // Bookshelves along north and east walls
        for col in 1..<(w-1) {
            walls[1][col] = .bookshelf  // Row of bookshelves along north
        }
        walls[3][w-2] = .bookshelf     // East wall shelves
        walls[4][w-2] = .bookshelf
        walls[5][w-2] = .bookshelf
        walls[6][w-2] = .bookshelf

        // Decoration layer - tables and a sign
        var decorations = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)
        decorations[4][5] = .table     // Central reading table
        decorations[4][6] = .table     // Wider table
        decorations[7][2] = .chest     // A treasure chest in the corner

        let doors = [
            DoorDefinition(
                id: "door_back_to_hub_from_library",
                position: (col: 0, row: h/2),
                targetRoomId: "hub_main",
                spawnPosition: (col: 18, row: 11),
                label: "Main Hall"
            )
        ]

        let npcs = [
            NPCSpawnDefinition(
                id: "librarian_sage",
                name: "Sage the Librarian",
                position: (col: 6, row: 3),
                dialogueId: "librarian_intro"
            )
        ]

        return Room(
            id: "hub_library",
            name: "Buddy Base - Library",
            width: w,
            height: h,
            floorLayer: floor,
            wallLayer: walls,
            decorationLayer: decorations,
            doors: doors,
            npcSpawns: npcs,
            playerSpawn: (col: 1, row: h/2),
            musicTrack: "hub_theme"
        )
    }
}
