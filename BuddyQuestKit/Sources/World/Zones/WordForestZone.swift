import Foundation

/// The Word Forest — Language Arts zone
/// A lush forest with paths, flowers, and signs teaching vocabulary and reading
/// Rooms: forest_entrance → forest_deep → forest_grove
public enum WordForestZone {

    public static func create() -> Zone {
        let zone = Zone(
            id: "word_forest",
            name: "Word Forest",
            subject: .languageArts,
            musicTrack: "forest_theme",
            requiredLevel: 1
        )

        zone.registerRoom(id: "forest_entrance") { createForestEntrance() }
        zone.registerRoom(id: "forest_deep") { createForestDeep() }
        zone.registerRoom(id: "forest_grove") { createForestGrove() }

        return zone
    }

    // MARK: - Forest Entrance

    private static func createForestEntrance() -> Room {
        let w = 20
        let h = 15

        // Floor layer — lush grass with a dirt path leading north
        var floor = Array(repeating: Array(repeating: TileType.grass, count: w), count: h)

        // Central dirt path from south to north
        for row in 0..<h {
            floor[row][w/2 - 1] = .dirt
            floor[row][w/2] = .dirt
        }

        // Small clearing in the center with flowers
        for row in 5..<9 {
            for col in 6..<14 {
                floor[row][col] = .grass
            }
        }

        // Flower patches scattered in the clearing
        floor[6][7] = .flower
        floor[7][12] = .flower
        floor[5][10] = .flower
        floor[8][8] = .flower
        floor[6][13] = .flower
        floor[8][6] = .flower

        // Wall layer — trees around the perimeter
        var walls = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)

        // North tree wall with 2-tile portal at cols 9-10 for door to forest_deep
        for col in 0..<w {
            if col == w/2 - 1 || col == w/2 {
                walls[0][col] = .portal
            } else {
                walls[0][col] = .tree
            }
        }

        // East and west tree walls
        for row in 0..<h {
            walls[row][0] = .tree
            walls[row][1] = .tree     // Double-thick west tree line
            walls[row][w-1] = .tree
            walls[row][w-2] = .tree   // Double-thick east tree line
        }

        // South wall with opening for hub door
        for col in 0..<w {
            if col != w/2 - 1 && col != w/2 {
                walls[h-1][col] = .tree
            }
        }

        // Extra trees for depth and atmosphere
        walls[2][4] = .tree
        walls[2][5] = .tree
        walls[3][3] = .tree
        walls[2][w-5] = .tree
        walls[2][w-6] = .tree
        walls[3][w-4] = .tree
        walls[10][4] = .tree
        walls[11][3] = .tree
        walls[10][w-5] = .tree
        walls[11][w-4] = .tree

        // Decorations — rocks and signs
        var decorations = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)
        decorations[3][w/2 + 2] = .sign     // Welcome sign near path
        decorations[6][4] = .rock            // Scenic rocks
        decorations[9][w-5] = .rock
        decorations[7][7] = .flower          // Extra flowers in clearing
        decorations[7][11] = .flower

        // Doors
        let doors = [
            // South exit back to Buddy Base hub (spawn near Word Forest portal at col 4)
            DoorDefinition(
                id: "door_back_to_hub",
                position: (col: w/2, row: h-1),
                targetRoomId: "hub_main",
                targetZoneId: "buddy_base",
                spawnPosition: (col: 4, row: 1),
                label: "Main Hall"
            ),
            DoorDefinition(
                id: "door_back_to_hub_2",
                position: (col: w/2 - 1, row: h-1),
                targetRoomId: "hub_main",
                targetZoneId: "buddy_base",
                spawnPosition: (col: 4, row: 1),
                label: "Main Hall"
            ),
            // North door to Deep Woods (quest-gated)
            DoorDefinition(
                id: "door_to_deep",
                position: (col: w/2 - 1, row: 0),
                targetRoomId: "forest_deep",
                spawnPosition: (col: 10, row: 13),
                requiredFlag: "forest_middle_unlocked",
                lockedMessage: "Complete 3 Language Arts challenges with Fern the Forest Sprite to unlock the Deep Woods.",
                label: "Deep Woods"
            ),
            DoorDefinition(
                id: "door_to_deep_2",
                position: (col: w/2, row: 0),
                targetRoomId: "forest_deep",
                spawnPosition: (col: 10, row: 13),
                requiredFlag: "forest_middle_unlocked",
                lockedMessage: "Complete 3 Language Arts challenges with Fern the Forest Sprite to unlock the Deep Woods.",
                label: "Deep Woods"
            ),
        ]

        let npcs = [
            NPCSpawnDefinition(
                id: "forest_sprite",
                name: "Fern the Forest Sprite",
                position: (col: w/2 + 3, row: 6),
                dialogueId: "forest_welcome",
                givesChallenge: true
            )
        ]

        return Room(
            id: "forest_entrance",
            name: "Word Forest - Entrance",
            width: w,
            height: h,
            floorLayer: floor,
            wallLayer: walls,
            decorationLayer: decorations,
            doors: doors,
            npcSpawns: npcs,
            playerSpawn: (col: w/2, row: h - 3),
            musicTrack: "forest_theme"
        )
    }

    // MARK: - Forest Deep Woods

    private static func createForestDeep() -> Room {
        let w = 20
        let h = 15

        // Floor — dense forest floor with winding dirt path
        var floor = Array(repeating: Array(repeating: TileType.grass, count: w), count: h)

        // Winding dirt path from south entrance to NPC area in center-east
        for row in 12..<h {
            floor[row][w/2 - 1] = .dirt
            floor[row][w/2] = .dirt
        }
        // Path curves east
        for row in 7..<13 {
            floor[row][w/2] = .dirt
            floor[row][w/2 + 1] = .dirt
        }
        for col in (w/2)..<15 {
            floor[7][col] = .dirt
            floor[8][col] = .dirt
        }

        // Small clearing around NPC
        for row in 5..<9 {
            for col in 12..<17 {
                floor[row][col] = .grass
            }
        }

        // Flower meadow area in the west
        floor[4][4] = .flower
        floor[5][3] = .flower
        floor[6][5] = .flower
        floor[3][6] = .flower
        floor[5][7] = .flower
        floor[7][3] = .flower
        floor[9][5] = .flower
        floor[10][4] = .flower

        // Wall layer — thick tree borders
        var walls = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)

        // North wall with portal for grove door
        for col in 0..<w {
            if col == w/2 - 1 || col == w/2 {
                walls[0][col] = .portal
            } else {
                walls[0][col] = .tree
            }
        }

        // South wall with opening back to entrance
        for col in 0..<w {
            if col != w/2 - 1 && col != w/2 {
                walls[h-1][col] = .tree
            }
        }

        // East and west walls
        for row in 0..<h {
            walls[row][0] = .tree
            walls[row][1] = .tree
            walls[row][w-1] = .tree
            walls[row][w-2] = .tree
        }

        // Interior trees for dense forest feel
        walls[3][4] = .tree
        walls[2][5] = .tree
        walls[4][3] = .tree
        walls[10][7] = .tree
        walls[11][8] = .tree
        walls[3][10] = .tree
        walls[2][11] = .tree
        walls[10][14] = .tree
        walls[11][15] = .tree
        walls[4][8] = .tree
        walls[9][3] = .tree

        // Decorations
        var decorations = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)
        decorations[2][7] = .sign
        decorations[6][11] = .rock
        decorations[10][10] = .rock
        decorations[3][14] = .flower
        decorations[9][16] = .flower
        decorations[12][6] = .flower

        let doors = [
            // South exit back to forest entrance
            DoorDefinition(
                id: "door_back_entrance",
                position: (col: w/2 - 1, row: h-1),
                targetRoomId: "forest_entrance",
                spawnPosition: (col: w/2 - 1, row: 1),
                label: "Entrance"
            ),
            DoorDefinition(
                id: "door_back_entrance_2",
                position: (col: w/2, row: h-1),
                targetRoomId: "forest_entrance",
                spawnPosition: (col: w/2, row: 1),
                label: "Entrance"
            ),
            // North exit to Ancient Grove (quest-gated)
            DoorDefinition(
                id: "door_to_grove",
                position: (col: w/2 - 1, row: 0),
                targetRoomId: "forest_grove",
                spawnPosition: (col: 10, row: 13),
                requiredFlag: "forest_boss_unlocked",
                lockedMessage: "Complete 3 Language Arts challenges with Willow the Wise to unlock the Ancient Grove.",
                label: "Ancient Grove"
            ),
            DoorDefinition(
                id: "door_to_grove_2",
                position: (col: w/2, row: 0),
                targetRoomId: "forest_grove",
                spawnPosition: (col: 10, row: 13),
                requiredFlag: "forest_boss_unlocked",
                lockedMessage: "Complete 3 Language Arts challenges with Willow the Wise to unlock the Ancient Grove.",
                label: "Ancient Grove"
            ),
        ]

        let npcs = [
            NPCSpawnDefinition(
                id: "forest_willow",
                name: "Willow the Wise",
                position: (col: 14, row: 6),
                dialogueId: "forest_willow_welcome",
                givesChallenge: true
            )
        ]

        return Room(
            id: "forest_deep",
            name: "Word Forest - Deep Woods",
            width: w,
            height: h,
            floorLayer: floor,
            wallLayer: walls,
            decorationLayer: decorations,
            doors: doors,
            npcSpawns: npcs,
            playerSpawn: (col: w/2, row: h - 3),
            musicTrack: "forest_theme"
        )
    }

    // MARK: - Forest Ancient Grove

    private static func createForestGrove() -> Room {
        let w = 20
        let h = 15

        // Floor — mystical clearing with stone circle
        var floor = Array(repeating: Array(repeating: TileType.grass, count: w), count: h)

        // Stone circle in center
        for row in 4..<11 {
            for col in 6..<14 {
                floor[row][col] = .stoneFloor
            }
        }

        // Dirt path from south to stone circle
        for row in 10..<h {
            floor[row][w/2 - 1] = .dirt
            floor[row][w/2] = .dirt
        }

        // Flowers around the stone circle
        floor[3][7] = .flower
        floor[3][12] = .flower
        floor[11][7] = .flower
        floor[11][12] = .flower
        floor[5][5] = .flower
        floor[9][5] = .flower
        floor[5][14] = .flower
        floor[9][14] = .flower

        // Wall layer — thick tree border, no north exit (boss room)
        var walls = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)

        // All walls solid
        for col in 0..<w {
            walls[0][col] = .tree
            walls[h-1][col] = .tree
        }
        for row in 0..<h {
            walls[row][0] = .tree
            walls[row][1] = .tree
            walls[row][w-1] = .tree
            walls[row][w-2] = .tree
        }

        // South wall opening back to deep woods
        walls[h-1][w/2 - 1] = .empty
        walls[h-1][w/2] = .empty

        // Ancient tree clusters
        walls[2][5] = .tree
        walls[2][6] = .tree
        walls[2][13] = .tree
        walls[2][14] = .tree
        walls[12][4] = .tree
        walls[12][5] = .tree
        walls[12][14] = .tree
        walls[12][15] = .tree

        // Decorations — crystals, rocks for mystical feel
        var decorations = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)
        decorations[4][6] = .crystal
        decorations[4][13] = .crystal
        decorations[10][6] = .crystal
        decorations[10][13] = .crystal
        decorations[7][5] = .crystal
        decorations[7][14] = .crystal
        decorations[3][9] = .sign
        decorations[1][10] = .rock
        decorations[13][8] = .rock

        let doors = [
            // South exit back to Deep Woods
            DoorDefinition(
                id: "door_back_deep",
                position: (col: w/2 - 1, row: h-1),
                targetRoomId: "forest_deep",
                spawnPosition: (col: w/2 - 1, row: 1),
                label: "Deep Woods"
            ),
            DoorDefinition(
                id: "door_back_deep_2",
                position: (col: w/2, row: h-1),
                targetRoomId: "forest_deep",
                spawnPosition: (col: w/2, row: 1),
                label: "Deep Woods"
            ),
        ]

        let npcs = [
            NPCSpawnDefinition(
                id: "forest_guardian",
                name: "Elder Oak",
                position: (col: 10, row: 7),
                dialogueId: "forest_guardian_welcome",
                givesChallenge: true
            )
        ]

        return Room(
            id: "forest_grove",
            name: "Word Forest - Ancient Grove",
            width: w,
            height: h,
            floorLayer: floor,
            wallLayer: walls,
            decorationLayer: decorations,
            doors: doors,
            npcSpawns: npcs,
            playerSpawn: (col: w/2, row: h - 3),
            musicTrack: "forest_theme"
        )
    }
}
