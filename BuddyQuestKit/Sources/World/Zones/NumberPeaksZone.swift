import Foundation

/// The Number Peaks — Math zone
/// A rugged mountain landscape with snow, stone paths, and crystal formations teaching arithmetic and math
/// Rooms: peaks_base → peaks_cavern → peaks_summit
public enum NumberPeaksZone {

    public static func create() -> Zone {
        let zone = Zone(
            id: "number_peaks",
            name: "Number Peaks",
            subject: .math,
            musicTrack: "peaks_theme",
            requiredLevel: 3
        )

        zone.registerRoom(id: "peaks_base") { createPeaksBase() }
        zone.registerRoom(id: "peaks_cavern") { createPeaksCavern() }
        zone.registerRoom(id: "peaks_summit") { createPeaksSummit() }

        return zone
    }

    // MARK: - Peaks Base

    private static func createPeaksBase() -> Room {
        let w = 20
        let h = 15

        // Floor layer — snow base everywhere, with stone paths
        var floor = Array(repeating: Array(repeating: TileType.snow, count: w), count: h)

        // Stone path from west entrance (row 7-8) heading east to center
        for col in 0..<12 {
            floor[7][col] = .stoneFloor
            floor[8][col] = .stoneFloor
        }

        // Stone path branching north from center toward NPC area
        for row in 2..<8 {
            floor[row][10] = .stoneFloor
            floor[row][11] = .stoneFloor
        }

        // Wider landing area around the NPC (col 10-14, row 4-7)
        for row in 4..<8 {
            for col in 10..<15 {
                floor[row][col] = .stoneFloor
            }
        }

        // Small stone plaza near NPC for challenge area
        for row in 3..<5 {
            for col in 11..<14 {
                floor[row][col] = .stoneFloor
            }
        }

        // Scattered dirt patches in the snow for natural feel
        floor[2][4] = .dirt
        floor[3][5] = .dirt
        floor[11][6] = .dirt
        floor[12][15] = .dirt
        floor[10][3] = .dirt
        floor[1][16] = .dirt
        floor[13][12] = .dirt

        // Wall layer
        var walls = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)

        // North rock wall (solid)
        for col in 0..<w {
            walls[0][col] = .rock
        }

        // South rock wall (solid)
        for col in 0..<w {
            walls[h - 1][col] = .rock
        }

        // East rock wall with portal at rows 7-8 for cavern door
        for row in 0..<h {
            if row == 7 || row == 8 {
                walls[row][w - 1] = .portal
            } else {
                walls[row][w - 1] = .rock
            }
        }

        // West rock wall with opening at rows 7-8 for the hub door
        for row in 0..<h {
            if row != 7 && row != 8 {
                walls[row][0] = .rock
            }
        }

        // Interior rocky outcrops
        walls[2][3] = .rock
        walls[2][4] = .rock
        walls[3][3] = .rock
        walls[1][5] = .rock
        walls[1][15] = .rock
        walls[1][16] = .rock
        walls[2][16] = .rock
        walls[2][17] = .rock
        walls[3][17] = .rock
        walls[11][16] = .rock
        walls[11][17] = .rock
        walls[12][17] = .rock
        walls[12][16] = .rock
        walls[11][3] = .rock
        walls[12][4] = .rock
        walls[12][3] = .rock
        walls[10][9] = .rock
        walls[10][10] = .rock
        walls[5][2] = .rock
        walls[10][2] = .rock

        // Decoration layer
        var decorations = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)
        decorations[6][2] = .sign
        decorations[2][12] = .crystal
        decorations[2][13] = .crystal
        decorations[3][13] = .crystal
        decorations[3][15] = .crystal
        decorations[4][16] = .crystal
        decorations[10][14] = .crystal
        decorations[11][14] = .crystal
        decorations[10][15] = .crystal
        decorations[11][5] = .crystal
        decorations[12][6] = .crystal
        decorations[5][8] = .crystal
        decorations[9][13] = .crystal
        decorations[4][17] = .crystal
        decorations[7][16] = .crystal
        decorations[4][9] = .sign

        // Doors
        let doors = [
            DoorDefinition(
                id: "door_back_to_hub",
                position: (col: 0, row: 7),
                targetRoomId: "hub_main",
                targetZoneId: "buddy_base",
                spawnPosition: (col: 18, row: 4),
                label: "Main Hall"
            ),
            DoorDefinition(
                id: "door_back_to_hub_2",
                position: (col: 0, row: 8),
                targetRoomId: "hub_main",
                targetZoneId: "buddy_base",
                spawnPosition: (col: 18, row: 4),
                label: "Main Hall"
            ),
            DoorDefinition(
                id: "door_to_cavern",
                position: (col: w - 1, row: 7),
                targetRoomId: "peaks_cavern",
                spawnPosition: (col: 1, row: 7),
                requiredFlag: "peaks_middle_unlocked",
                lockedMessage: "Complete 3 Math challenges with Rocky the Calcinator to unlock the Crystal Cavern.",
                label: "Crystal Cavern"
            ),
            DoorDefinition(
                id: "door_to_cavern_2",
                position: (col: w - 1, row: 8),
                targetRoomId: "peaks_cavern",
                spawnPosition: (col: 1, row: 8),
                requiredFlag: "peaks_middle_unlocked",
                lockedMessage: "Complete 3 Math challenges with Rocky the Calcinator to unlock the Crystal Cavern.",
                label: "Crystal Cavern"
            ),
        ]

        let npcs = [
            NPCSpawnDefinition(
                id: "rocky_calcinator",
                name: "Rocky the Calcinator",
                position: (col: 12, row: 6),
                dialogueId: "peaks_welcome",
                givesChallenge: true
            )
        ]

        return Room(
            id: "peaks_base",
            name: "Number Peaks - Base Camp",
            width: w,
            height: h,
            floorLayer: floor,
            wallLayer: walls,
            decorationLayer: decorations,
            doors: doors,
            npcSpawns: npcs,
            playerSpawn: (col: 1, row: 7),
            musicTrack: "peaks_theme"
        )
    }

    // MARK: - Crystal Cavern

    private static func createPeaksCavern() -> Room {
        let w = 20
        let h = 15

        var floor = Array(repeating: Array(repeating: TileType.snow, count: w), count: h)

        // Stone path through the cavern
        for col in 0..<w {
            floor[7][col] = .stoneFloor
            floor[8][col] = .stoneFloor
        }

        // Wider area around NPC
        for row in 4..<10 {
            for col in 8..<14 {
                floor[row][col] = .stoneFloor
            }
        }

        floor[3][5] = .dirt
        floor[11][4] = .dirt
        floor[2][14] = .dirt
        floor[12][15] = .dirt

        var walls = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)

        for col in 0..<w {
            walls[0][col] = .rock
            walls[h-1][col] = .rock
        }

        // West wall with opening at rows 7-8
        for row in 0..<h {
            if row != 7 && row != 8 {
                walls[row][0] = .rock
            }
        }

        // East wall with portal at rows 7-8 for summit door
        for row in 0..<h {
            if row == 7 || row == 8 {
                walls[row][w-1] = .portal
            } else {
                walls[row][w-1] = .rock
            }
        }

        // Interior rock formations
        walls[2][4] = .rock
        walls[2][5] = .rock
        walls[3][4] = .rock
        walls[12][4] = .rock
        walls[12][5] = .rock
        walls[2][15] = .rock
        walls[3][16] = .rock
        walls[11][15] = .rock
        walls[12][15] = .rock
        walls[5][3] = .rock
        walls[10][3] = .rock
        walls[5][17] = .rock
        walls[10][17] = .rock

        var decorations = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)
        decorations[1][7] = .crystal
        decorations[1][8] = .crystal
        decorations[1][12] = .crystal
        decorations[3][6] = .crystal
        decorations[3][14] = .crystal
        decorations[6][5] = .crystal
        decorations[9][5] = .crystal
        decorations[6][16] = .crystal
        decorations[9][16] = .crystal
        decorations[13][7] = .crystal
        decorations[13][12] = .crystal
        decorations[11][10] = .crystal
        decorations[4][10] = .sign

        let doors = [
            DoorDefinition(
                id: "door_back_base",
                position: (col: 0, row: 7),
                targetRoomId: "peaks_base",
                spawnPosition: (col: 18, row: 7),
                label: "Base Camp"
            ),
            DoorDefinition(
                id: "door_back_base_2",
                position: (col: 0, row: 8),
                targetRoomId: "peaks_base",
                spawnPosition: (col: 18, row: 8),
                label: "Base Camp"
            ),
            DoorDefinition(
                id: "door_to_summit",
                position: (col: w - 1, row: 7),
                targetRoomId: "peaks_summit",
                spawnPosition: (col: 1, row: 7),
                requiredFlag: "peaks_boss_unlocked",
                lockedMessage: "Complete 3 Math challenges with the Crystal Sage to unlock the Summit.",
                label: "Summit"
            ),
            DoorDefinition(
                id: "door_to_summit_2",
                position: (col: w - 1, row: 8),
                targetRoomId: "peaks_summit",
                spawnPosition: (col: 1, row: 8),
                requiredFlag: "peaks_boss_unlocked",
                lockedMessage: "Complete 3 Math challenges with the Crystal Sage to unlock the Summit.",
                label: "Summit"
            ),
        ]

        let npcs = [
            NPCSpawnDefinition(
                id: "peaks_crystal_sage",
                name: "Crystal Sage",
                position: (col: 11, row: 6),
                dialogueId: "peaks_crystal_sage_welcome",
                givesChallenge: true
            )
        ]

        return Room(
            id: "peaks_cavern",
            name: "Number Peaks - Crystal Cavern",
            width: w,
            height: h,
            floorLayer: floor,
            wallLayer: walls,
            decorationLayer: decorations,
            doors: doors,
            npcSpawns: npcs,
            playerSpawn: (col: 1, row: 7),
            musicTrack: "peaks_theme"
        )
    }

    // MARK: - Peaks Summit

    private static func createPeaksSummit() -> Room {
        let w = 20
        let h = 15

        var floor = Array(repeating: Array(repeating: TileType.snow, count: w), count: h)

        // Stone platform in center
        for row in 4..<11 {
            for col in 5..<15 {
                floor[row][col] = .stoneFloor
            }
        }

        // Path from west entrance
        for col in 0..<6 {
            floor[7][col] = .stoneFloor
            floor[8][col] = .stoneFloor
        }

        var walls = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)

        for col in 0..<w {
            walls[0][col] = .rock
            walls[h-1][col] = .rock
        }
        for row in 0..<h {
            walls[row][w-1] = .rock
        }
        for row in 0..<h {
            if row != 7 && row != 8 {
                walls[row][0] = .rock
            }
        }

        // Scenic boulders
        walls[2][4] = .rock
        walls[2][5] = .rock
        walls[2][14] = .rock
        walls[2][15] = .rock
        walls[12][4] = .rock
        walls[12][15] = .rock
        walls[5][17] = .rock
        walls[9][17] = .rock

        var decorations = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)
        decorations[3][7] = .crystal
        decorations[3][12] = .crystal
        decorations[11][7] = .crystal
        decorations[11][12] = .crystal
        decorations[7][15] = .crystal
        decorations[6][4] = .crystal
        decorations[1][10] = .sign
        decorations[13][10] = .rock

        let doors = [
            DoorDefinition(
                id: "door_back_cavern",
                position: (col: 0, row: 7),
                targetRoomId: "peaks_cavern",
                spawnPosition: (col: 18, row: 7),
                label: "Crystal Cavern"
            ),
            DoorDefinition(
                id: "door_back_cavern_2",
                position: (col: 0, row: 8),
                targetRoomId: "peaks_cavern",
                spawnPosition: (col: 18, row: 8),
                label: "Crystal Cavern"
            ),
        ]

        let npcs = [
            NPCSpawnDefinition(
                id: "peaks_summit_keeper",
                name: "Summit Keeper",
                position: (col: 10, row: 7),
                dialogueId: "peaks_summit_keeper_welcome",
                givesChallenge: true
            )
        ]

        return Room(
            id: "peaks_summit",
            name: "Number Peaks - Summit",
            width: w,
            height: h,
            floorLayer: floor,
            wallLayer: walls,
            decorationLayer: decorations,
            doors: doors,
            npcSpawns: npcs,
            playerSpawn: (col: 1, row: 7),
            musicTrack: "peaks_theme"
        )
    }
}
