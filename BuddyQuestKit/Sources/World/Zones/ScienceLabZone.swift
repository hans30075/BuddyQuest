import Foundation

/// The Science Lab — Science zone
/// A high-tech laboratory with experiment stations, crystal specimens, and bookshelves
/// Rooms: lab_lobby → lab_research → lab_reactor
public enum ScienceLabZone {

    public static func create() -> Zone {
        let zone = Zone(
            id: "science_lab",
            name: "Science Lab",
            subject: .science,
            musicTrack: "lab_theme",
            requiredLevel: 5
        )

        zone.registerRoom(id: "lab_lobby") { createLabLobby() }
        zone.registerRoom(id: "lab_research") { createLabResearch() }
        zone.registerRoom(id: "lab_reactor") { createLabReactor() }

        return zone
    }

    // MARK: - Lab Lobby

    private static func createLabLobby() -> Room {
        let w = 20
        let h = 15

        // Floor layer — clean lab floor with stone path and reading nook
        var floor = Array(repeating: Array(repeating: TileType.labFloor, count: w), count: h)

        // Stone path from north entry (cols 7-8) down to center area
        for row in 0..<8 {
            floor[row][7] = .stoneFloor
            floor[row][8] = .stoneFloor
        }
        for col in 6..<10 {
            floor[6][col] = .stoneFloor
            floor[7][col] = .stoneFloor
        }

        // Wood floor reading nook in bottom-right corner
        for row in 10..<14 {
            for col in 14..<19 {
                floor[row][col] = .woodFloor
            }
        }

        // Wall layer
        var walls = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)

        // North wall with opening at cols 7-8
        for col in 0..<w {
            walls[0][col] = .wall
        }
        walls[0][7] = .empty
        walls[0][8] = .empty

        // South wall with portal at cols 9-10 for research door
        for col in 0..<w {
            walls[h - 1][col] = .wall
        }
        walls[h-1][9] = .portal
        walls[h-1][10] = .portal

        // West wall
        for row in 0..<h {
            walls[row][0] = .wall
        }

        // East wall
        for row in 0..<h {
            walls[row][w - 1] = .wall
        }

        // Decoration layer
        var decorations = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)
        decorations[1][10] = .sign
        decorations[5][4] = .table
        decorations[5][5] = .table
        decorations[5][6] = .table
        decorations[8][4] = .table
        decorations[8][5] = .table
        decorations[8][6] = .table
        decorations[5][12] = .table
        decorations[5][13] = .table
        decorations[9][9] = .table
        decorations[9][10] = .table
        decorations[2][18] = .bookshelf
        decorations[3][18] = .bookshelf
        decorations[4][18] = .bookshelf
        decorations[5][18] = .bookshelf
        decorations[6][18] = .bookshelf
        decorations[7][18] = .bookshelf
        decorations[8][18] = .bookshelf
        decorations[10][17] = .bookshelf
        decorations[10][18] = .bookshelf
        decorations[3][3] = .crystal
        decorations[3][15] = .crystal
        decorations[7][15] = .crystal
        decorations[11][2] = .crystal
        decorations[12][9] = .crystal
        decorations[12][2] = .chest
        decorations[13][6] = .rock

        // Doors
        let doors = [
            DoorDefinition(
                id: "door_back_to_hub",
                position: (col: 7, row: 0),
                targetRoomId: "hub_main",
                targetZoneId: "buddy_base",
                spawnPosition: (col: 13, row: 13),
                label: "Main Hall"
            ),
            DoorDefinition(
                id: "door_back_to_hub_2",
                position: (col: 8, row: 0),
                targetRoomId: "hub_main",
                targetZoneId: "buddy_base",
                spawnPosition: (col: 13, row: 13),
                label: "Main Hall"
            ),
            // South door to Research Station (quest-gated)
            DoorDefinition(
                id: "door_to_research",
                position: (col: 9, row: h - 1),
                targetRoomId: "lab_research",
                spawnPosition: (col: 10, row: 1),
                requiredFlag: "lab_middle_unlocked",
                lockedMessage: "Complete 3 Science challenges with Professor Atom to unlock the Research Lab.",
                label: "Research Lab"
            ),
            DoorDefinition(
                id: "door_to_research_2",
                position: (col: 10, row: h - 1),
                targetRoomId: "lab_research",
                spawnPosition: (col: 10, row: 1),
                requiredFlag: "lab_middle_unlocked",
                lockedMessage: "Complete 3 Science challenges with Professor Atom to unlock the Research Lab.",
                label: "Research Lab"
            ),
        ]

        let npcs = [
            NPCSpawnDefinition(
                id: "professor_atom",
                name: "Professor Atom",
                position: (col: 12, row: 7),
                dialogueId: "lab_welcome",
                givesChallenge: true
            )
        ]

        return Room(
            id: "lab_lobby",
            name: "Science Lab - Lobby",
            width: w,
            height: h,
            floorLayer: floor,
            wallLayer: walls,
            decorationLayer: decorations,
            doors: doors,
            npcSpawns: npcs,
            playerSpawn: (col: 7, row: 1),
            musicTrack: "lab_theme"
        )
    }

    // MARK: - Research Station

    private static func createLabResearch() -> Room {
        let w = 20
        let h = 15

        var floor = Array(repeating: Array(repeating: TileType.labFloor, count: w), count: h)

        // Stone path from north entry down to center
        for row in 0..<8 {
            floor[row][10] = .stoneFloor
            floor[row][11] = .stoneFloor
        }

        // Wider experiment area in center
        for row in 5..<10 {
            for col in 6..<15 {
                floor[row][col] = .stoneFloor
            }
        }

        // Wood floor specimen area in bottom-left
        for row in 10..<14 {
            for col in 2..<7 {
                floor[row][col] = .woodFloor
            }
        }

        var walls = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)

        // North wall with opening at cols 10-11
        for col in 0..<w {
            walls[0][col] = .wall
        }
        walls[0][10] = .empty
        walls[0][11] = .empty

        // South wall with portal at cols 9-10 for reactor door
        for col in 0..<w {
            walls[h-1][col] = .wall
        }
        walls[h-1][9] = .portal
        walls[h-1][10] = .portal

        for row in 0..<h {
            walls[row][0] = .wall
            walls[row][w-1] = .wall
        }

        // Decorations — experiment tables, specimens
        var decorations = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)
        decorations[3][4] = .table
        decorations[3][5] = .table
        decorations[3][6] = .table
        decorations[7][3] = .table
        decorations[7][4] = .table
        decorations[6][14] = .table
        decorations[6][15] = .table
        decorations[8][14] = .table
        decorations[8][15] = .table
        decorations[2][14] = .bookshelf
        decorations[2][15] = .bookshelf
        decorations[2][16] = .bookshelf
        decorations[10][17] = .bookshelf
        decorations[11][17] = .bookshelf
        decorations[4][8] = .crystal
        decorations[9][12] = .crystal
        decorations[11][3] = .crystal
        decorations[11][5] = .crystal
        decorations[12][4] = .crystal
        decorations[1][7] = .sign
        decorations[12][15] = .chest

        let doors = [
            // North exit back to lobby
            DoorDefinition(
                id: "door_back_lobby",
                position: (col: 10, row: 0),
                targetRoomId: "lab_lobby",
                spawnPosition: (col: 9, row: 13),
                label: "Lobby"
            ),
            DoorDefinition(
                id: "door_back_lobby_2",
                position: (col: 11, row: 0),
                targetRoomId: "lab_lobby",
                spawnPosition: (col: 10, row: 13),
                label: "Lobby"
            ),
            // South exit to Reactor Room (quest-gated)
            DoorDefinition(
                id: "door_to_reactor",
                position: (col: 9, row: h - 1),
                targetRoomId: "lab_reactor",
                spawnPosition: (col: 10, row: 1),
                requiredFlag: "lab_boss_unlocked",
                lockedMessage: "Complete 3 Science challenges with Dr. Helix to unlock the Reactor Room.",
                label: "Reactor Room"
            ),
            DoorDefinition(
                id: "door_to_reactor_2",
                position: (col: 10, row: h - 1),
                targetRoomId: "lab_reactor",
                spawnPosition: (col: 10, row: 1),
                requiredFlag: "lab_boss_unlocked",
                lockedMessage: "Complete 3 Science challenges with Dr. Helix to unlock the Reactor Room.",
                label: "Reactor Room"
            ),
        ]

        let npcs = [
            NPCSpawnDefinition(
                id: "lab_researcher",
                name: "Dr. Helix",
                position: (col: 10, row: 7),
                dialogueId: "lab_researcher_welcome",
                givesChallenge: true
            )
        ]

        return Room(
            id: "lab_research",
            name: "Science Lab - Research Station",
            width: w,
            height: h,
            floorLayer: floor,
            wallLayer: walls,
            decorationLayer: decorations,
            doors: doors,
            npcSpawns: npcs,
            playerSpawn: (col: 10, row: 1),
            musicTrack: "lab_theme"
        )
    }

    // MARK: - Reactor Room

    private static func createLabReactor() -> Room {
        let w = 20
        let h = 15

        var floor = Array(repeating: Array(repeating: TileType.labFloor, count: w), count: h)

        // Central stone platform
        for row in 4..<11 {
            for col in 5..<15 {
                floor[row][col] = .stoneFloor
            }
        }

        // Path from north entry
        for row in 0..<5 {
            floor[row][10] = .stoneFloor
            floor[row][11] = .stoneFloor
        }

        var walls = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)

        // All walls solid except north opening
        for col in 0..<w {
            walls[0][col] = .wall
            walls[h-1][col] = .wall
        }
        for row in 0..<h {
            walls[row][0] = .wall
            walls[row][w-1] = .wall
        }
        walls[0][10] = .empty
        walls[0][11] = .empty

        // Decorations — crystals, glow, reactor feel
        var decorations = Array(repeating: Array(repeating: TileType.empty, count: w), count: h)
        // Crystal "reactor" in center
        decorations[6][9] = .crystal
        decorations[6][10] = .crystal
        decorations[7][9] = .crystal
        decorations[7][10] = .crystal
        decorations[8][9] = .crystal
        decorations[8][10] = .crystal
        // Ring of crystals around reactor
        decorations[4][7] = .crystal
        decorations[4][12] = .crystal
        decorations[10][7] = .crystal
        decorations[10][12] = .crystal
        decorations[5][5] = .crystal
        decorations[9][5] = .crystal
        decorations[5][14] = .crystal
        decorations[9][14] = .crystal
        // Equipment
        decorations[2][3] = .table
        decorations[2][4] = .table
        decorations[2][15] = .table
        decorations[2][16] = .table
        decorations[12][3] = .bookshelf
        decorations[12][4] = .bookshelf
        decorations[12][15] = .bookshelf
        decorations[12][16] = .bookshelf
        decorations[1][8] = .sign

        let doors = [
            // North exit back to research station
            DoorDefinition(
                id: "door_back_research",
                position: (col: 10, row: 0),
                targetRoomId: "lab_research",
                spawnPosition: (col: 9, row: 13),
                label: "Research Lab"
            ),
            DoorDefinition(
                id: "door_back_research_2",
                position: (col: 11, row: 0),
                targetRoomId: "lab_research",
                spawnPosition: (col: 10, row: 13),
                label: "Research Lab"
            ),
        ]

        let npcs = [
            NPCSpawnDefinition(
                id: "lab_director",
                name: "Director Spark",
                position: (col: 10, row: 5),
                dialogueId: "lab_director_welcome",
                givesChallenge: true
            )
        ]

        return Room(
            id: "lab_reactor",
            name: "Science Lab - Reactor Room",
            width: w,
            height: h,
            floorLayer: floor,
            wallLayer: walls,
            decorationLayer: decorations,
            doors: doors,
            npcSpawns: npcs,
            playerSpawn: (col: 10, row: 1),
            musicTrack: "lab_theme"
        )
    }
}
