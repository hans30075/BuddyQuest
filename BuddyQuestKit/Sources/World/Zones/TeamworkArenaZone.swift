import Foundation

/// The Teamwork Arena — Social Skills zone
/// A warm, welcoming outdoor arena with sand floors, garden corners, and a central dirt clearing
/// Rooms: arena_entrance → arena_training → arena_grand
public enum TeamworkArenaZone {

    public static func create() -> Zone {
        let zone = Zone(
            id: "teamwork_arena",
            name: "Teamwork Arena",
            subject: .social,
            musicTrack: "arena_theme",
            requiredLevel: 2
        )

        zone.registerRoom(id: "arena_entrance") { createArenaEntrance() }
        zone.registerRoom(id: "arena_training") { createArenaTraining() }
        zone.registerRoom(id: "arena_grand") { createArenaGrand() }

        return zone
    }

    // MARK: - Arena Entrance

    private static func createArenaEntrance() -> Room {
        let w = 20
        let h = 15

        var floor = Array(repeating: Array(repeating: TileType.sand, count: w), count: h)

        // Dirt path entering from east (row 7-8)
        for col in 10..<w {
            floor[7][col] = .path
            floor[8][col] = .path
        }
        for col in 7..<11 {
            floor[7][col] = .path
            floor[8][col] = .path
        }

        // Central dirt clearing
        for row in 5..<11 {
            for col in 5..<15 {
                floor[row][col] = .dirt
            }
        }
        for col in 7..<w {
            floor[7][col] = .path
            floor[8][col] = .path
        }

        // Grass garden corners
        for row in 1..<5 {
            for col in 1..<6 {
                floor[row][col] = .grass
            }
        }
        for row in 10..<14 {
            for col in 1..<6 {
                floor[row][col] = .grass
            }
        }
        for row in 1..<5 {
            for col in 14..<19 {
                floor[row][col] = .grass
            }
        }

        // Wall layer
        var walls = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)

        for col in 0..<w {
            walls[0][col] = .tree
            walls[h - 1][col] = .tree
        }
        for row in 0..<h {
            walls[row][0] = .tree
        }
        // East wall with 2-tile opening at rows 7-8 (hub exit)
        for row in 0..<h {
            if row != 7 && row != 8 {
                walls[row][w - 1] = .tree
            }
        }
        // West wall with portal at rows 7-8 (training door)
        for row in 0..<h {
            if row == 7 || row == 8 {
                walls[row][0] = .portal
            } else {
                walls[row][0] = .tree
            }
        }

        // Extra trees
        walls[1][1] = .tree
        walls[3][1] = .tree
        walls[5][1] = .tree
        walls[9][1] = .tree
        walls[11][1] = .tree
        walls[13][1] = .tree
        walls[1][7] = .tree
        walls[1][12] = .tree
        walls[13][7] = .tree
        walls[13][12] = .tree

        // Decorations
        var decorations = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)
        decorations[4][5] = .rock
        decorations[4][9] = .rock
        decorations[4][14] = .rock
        decorations[11][5] = .rock
        decorations[11][9] = .rock
        decorations[11][14] = .rock
        decorations[6][4] = .rock
        decorations[9][4] = .rock
        decorations[6][15] = .rock
        decorations[9][15] = .rock
        decorations[6][17] = .sign
        // Flower gardens
        decorations[2][2] = .flower
        decorations[3][4] = .flower
        decorations[1][3] = .flower
        decorations[4][2] = .flower
        decorations[2][5] = .flower
        decorations[11][2] = .flower
        decorations[12][4] = .flower
        decorations[10][3] = .flower
        decorations[13][2] = .flower
        decorations[2][15] = .flower
        decorations[3][17] = .flower
        decorations[1][16] = .flower
        decorations[4][15] = .flower
        decorations[2][18] = .flower
        decorations[6][7] = .flower
        decorations[10][12] = .flower
        decorations[5][11] = .flower

        let doors = [
            // East exit back to hub
            DoorDefinition(
                id: "door_back_to_hub",
                position: (col: 19, row: 7),
                targetRoomId: "hub_main",
                targetZoneId: "buddy_base",
                spawnPosition: (col: 1, row: 4),
                label: "Main Hall"
            ),
            DoorDefinition(
                id: "door_back_to_hub_2",
                position: (col: 19, row: 8),
                targetRoomId: "hub_main",
                targetZoneId: "buddy_base",
                spawnPosition: (col: 1, row: 4),
                label: "Main Hall"
            ),
            // West door to Training Grounds (quest-gated)
            DoorDefinition(
                id: "door_to_training",
                position: (col: 0, row: 7),
                targetRoomId: "arena_training",
                spawnPosition: (col: 18, row: 7),
                requiredFlag: "arena_middle_unlocked",
                lockedMessage: "Complete 3 Social challenges with Coach Unity to unlock the Training Grounds.",
                label: "Training Grounds"
            ),
            DoorDefinition(
                id: "door_to_training_2",
                position: (col: 0, row: 8),
                targetRoomId: "arena_training",
                spawnPosition: (col: 18, row: 8),
                requiredFlag: "arena_middle_unlocked",
                lockedMessage: "Complete 3 Social challenges with Coach Unity to unlock the Training Grounds.",
                label: "Training Grounds"
            ),
        ]

        let npcs = [
            NPCSpawnDefinition(
                id: "coach_unity",
                name: "Coach Unity",
                position: (col: 8, row: 7),
                dialogueId: "arena_welcome",
                givesChallenge: true
            )
        ]

        return Room(
            id: "arena_entrance",
            name: "Teamwork Arena - Entrance",
            width: w,
            height: h,
            floorLayer: floor,
            wallLayer: walls,
            decorationLayer: decorations,
            doors: doors,
            npcSpawns: npcs,
            playerSpawn: (col: 13, row: 7),
            musicTrack: "arena_theme"
        )
    }

    // MARK: - Training Grounds

    private static func createArenaTraining() -> Room {
        let w = 20
        let h = 15

        var floor = Array(repeating: Array(repeating: TileType.sand, count: w), count: h)

        // Central dirt training area
        for row in 3..<12 {
            for col in 4..<16 {
                floor[row][col] = .dirt
            }
        }

        // Path from east entrance
        for col in 15..<w {
            floor[7][col] = .path
            floor[8][col] = .path
        }

        // Grass garden corners
        for row in 1..<4 {
            for col in 1..<5 {
                floor[row][col] = .grass
            }
        }
        for row in 11..<14 {
            for col in 1..<5 {
                floor[row][col] = .grass
            }
        }
        for row in 1..<4 {
            for col in 15..<19 {
                floor[row][col] = .grass
            }
        }
        for row in 11..<14 {
            for col in 15..<19 {
                floor[row][col] = .grass
            }
        }

        var walls = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)

        for col in 0..<w {
            walls[0][col] = .tree
            walls[h-1][col] = .tree
        }
        // West wall with portal at rows 7-8 for grand arena door
        for row in 0..<h {
            if row == 7 || row == 8 {
                walls[row][0] = .portal
            } else {
                walls[row][0] = .tree
            }
        }
        // East wall with opening at rows 7-8
        for row in 0..<h {
            if row != 7 && row != 8 {
                walls[row][w-1] = .tree
            }
        }

        // Obstacle rocks in the training area
        walls[5][6] = .rock
        walls[5][13] = .rock
        walls[9][6] = .rock
        walls[9][13] = .rock
        walls[7][9] = .rock
        walls[7][10] = .rock

        // Decorations
        var decorations = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)
        decorations[1][2] = .flower
        decorations[2][3] = .flower
        decorations[3][1] = .flower
        decorations[12][2] = .flower
        decorations[11][3] = .flower
        decorations[13][1] = .flower
        decorations[1][16] = .flower
        decorations[2][17] = .flower
        decorations[12][16] = .flower
        decorations[13][17] = .flower
        decorations[6][8] = .sign
        decorations[3][8] = .rock
        decorations[11][11] = .rock

        let doors = [
            // East exit back to entrance
            DoorDefinition(
                id: "door_back_entrance",
                position: (col: w - 1, row: 7),
                targetRoomId: "arena_entrance",
                spawnPosition: (col: 1, row: 7),
                label: "Entrance"
            ),
            DoorDefinition(
                id: "door_back_entrance_2",
                position: (col: w - 1, row: 8),
                targetRoomId: "arena_entrance",
                spawnPosition: (col: 1, row: 8),
                label: "Entrance"
            ),
            // West exit to Grand Arena (quest-gated)
            DoorDefinition(
                id: "door_to_grand",
                position: (col: 0, row: 7),
                targetRoomId: "arena_grand",
                spawnPosition: (col: 18, row: 7),
                requiredFlag: "arena_boss_unlocked",
                lockedMessage: "Complete 3 Social challenges with Captain Rally to unlock the Grand Arena.",
                label: "Grand Arena"
            ),
            DoorDefinition(
                id: "door_to_grand_2",
                position: (col: 0, row: 8),
                targetRoomId: "arena_grand",
                spawnPosition: (col: 18, row: 8),
                requiredFlag: "arena_boss_unlocked",
                lockedMessage: "Complete 3 Social challenges with Captain Rally to unlock the Grand Arena.",
                label: "Grand Arena"
            ),
        ]

        let npcs = [
            NPCSpawnDefinition(
                id: "arena_captain",
                name: "Captain Rally",
                position: (col: 10, row: 7),
                dialogueId: "arena_captain_welcome",
                givesChallenge: true
            )
        ]

        return Room(
            id: "arena_training",
            name: "Teamwork Arena - Training Grounds",
            width: w,
            height: h,
            floorLayer: floor,
            wallLayer: walls,
            decorationLayer: decorations,
            doors: doors,
            npcSpawns: npcs,
            playerSpawn: (col: 18, row: 7),
            musicTrack: "arena_theme"
        )
    }

    // MARK: - Grand Arena

    private static func createArenaGrand() -> Room {
        let w = 20
        let h = 15

        var floor = Array(repeating: Array(repeating: TileType.sand, count: w), count: h)

        // Large dirt arena in center
        for row in 2..<13 {
            for col in 3..<17 {
                floor[row][col] = .dirt
            }
        }

        // Path from east entrance
        for col in 16..<w {
            floor[7][col] = .path
            floor[8][col] = .path
        }

        // Grass patches in corners
        for row in 1..<3 {
            for col in 1..<4 {
                floor[row][col] = .grass
            }
        }
        for row in 12..<14 {
            for col in 1..<4 {
                floor[row][col] = .grass
            }
        }

        var walls = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)

        for col in 0..<w {
            walls[0][col] = .tree
            walls[h-1][col] = .tree
        }
        for row in 0..<h {
            walls[row][0] = .tree
        }
        // East wall with opening at rows 7-8
        for row in 0..<h {
            if row != 7 && row != 8 {
                walls[row][w-1] = .tree
            }
        }

        // Scenic trees
        walls[1][1] = .tree
        walls[13][1] = .tree
        walls[2][2] = .tree
        walls[12][2] = .tree

        // Decorations — arena markers, flowers
        var decorations = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)
        // Arena corner markers
        decorations[2][3] = .rock
        decorations[2][16] = .rock
        decorations[12][3] = .rock
        decorations[12][16] = .rock
        decorations[7][3] = .rock
        decorations[7][16] = .rock
        // Central area markers
        decorations[5][7] = .sign
        decorations[5][12] = .sign
        // Flowers
        decorations[1][2] = .flower
        decorations[13][2] = .flower
        decorations[1][17] = .flower
        decorations[13][17] = .flower
        decorations[4][5] = .flower
        decorations[10][14] = .flower
        decorations[3][10] = .flower
        decorations[11][9] = .flower

        let doors = [
            // East exit back to training
            DoorDefinition(
                id: "door_back_training",
                position: (col: w - 1, row: 7),
                targetRoomId: "arena_training",
                spawnPosition: (col: 1, row: 7),
                label: "Training Grounds"
            ),
            DoorDefinition(
                id: "door_back_training_2",
                position: (col: w - 1, row: 8),
                targetRoomId: "arena_training",
                spawnPosition: (col: 1, row: 8),
                label: "Training Grounds"
            ),
        ]

        let npcs = [
            NPCSpawnDefinition(
                id: "arena_champion_npc",
                name: "Champion Star",
                position: (col: 10, row: 7),
                dialogueId: "arena_champion_welcome",
                givesChallenge: true
            )
        ]

        return Room(
            id: "arena_grand",
            name: "Teamwork Arena - Grand Arena",
            width: w,
            height: h,
            floorLayer: floor,
            wallLayer: walls,
            decorationLayer: decorations,
            doors: doors,
            npcSpawns: npcs,
            playerSpawn: (col: 18, row: 7),
            musicTrack: "arena_theme"
        )
    }
}
