# DigCraft Phase 0 MVP - Implementation Plan

## Project Setup
- **Xcode project** via xcodegen (v2.44.1 installed)
- **Targets**: Single multiplatform target (iOS 17+ / macOS 14+)
- **Tile size**: 16px
- **App shell**: SwiftUI with SpriteKit embedded via `SpriteView`

## Architecture

```
SwiftUI Shell (App, TitleScreen, GameView)
    |
    | owns simulation + scene
    v
GameSimulation (@Observable)          GameScene (SpriteKit)
  - World, Player, Inventory            - ChunkRenderer (SKTileMapNode per chunk)
  - PhysicsSystem                        - PlayerNode, CameraController
  - processes GameCommands               - InputMapper -> GameCommands
  - emits [GameEvent]                    - consumes GameEvents
  (NO SpriteKit imports)                 (reads simulation state)
```

Simulation is the source of truth. Rendering reflects it. Commands flow in, events flow out.

## File Structure

```
2d-digger/
  project.yml                          # xcodegen spec
  DigCraft/
    App/
      DigCraftApp.swift                # @main entry point
      ContentView.swift                # Navigation (title vs game)
      TitleScreenView.swift            # New Game / Load Game
      GameView.swift                   # SpriteView + SwiftUI overlays
    Game/
      Simulation/
        TileType.swift                 # enum: air, grass, dirt, stone, oreCopper
        Chunk.swift                    # 32x32 flat tile array + ChunkCoord
        World.swift                    # 256x192 grid, chunk storage, tile access
        GameCommand.swift              # Codable enum: move, jump, dig, place, selectHotbar
        Events.swift                   # GameEvent enum for sim->renderer
        PlayerState.swift              # Position, velocity, AABB
        Inventory.swift                # 5-slot hotbar with stacking
        WorldGenerator.swift           # Seeded terrain via GKPerlinNoiseSource
        PhysicsSystem.swift            # Gravity, movement, AABB collision
        GameSimulation.swift           # Central loop: owns state, processes commands, fixed timestep
      Rendering/
        GameScene.swift                # SKScene: update loop, event dispatch, input forwarding
        ChunkRenderer.swift            # SKTileMapNode per chunk, dirty tracking
        TileAtlas.swift                # Placeholder colored-square textures + SKTileSet
        PlayerNode.swift               # Cyan rectangle sprite
        CameraController.swift         # Smooth follow with world bounds clamping
      Input/
        InputMapper.swift              # Platform input -> GameCommand
      SaveLoad/
        SaveManager.swift              # JSON encode/decode to documents dir
        SaveModels.swift               # SaveData + TileDelta (delta encoding)
    UI/
      HotbarView.swift                 # SwiftUI hotbar overlay
      PauseMenuView.swift              # Resume / Save / Quit
      ControlsOverlay.swift            # In-game controls reference
    Assets.xcassets/                    # AccentColor, AppIcon placeholders
  DigCraftTests/
    SimulationTests.swift
    WorldGeneratorTests.swift
    PhysicsTests.swift
    SaveLoadTests.swift
```

## Implementation Steps (in order)

### Step 0: Project scaffold
- Create directory structure, `project.yml`, `Assets.xcassets` with required `Contents.json` files
- Run `xcodegen generate` to produce `.xcodeproj`
- Verify it opens and builds empty

### Step 1: Foundation types (pure Swift, no frameworks)
- `TileType` - UInt8 enum with `isSolid`, `displayName`
- `Chunk` - 32x32 flat `[TileType]` array with subscript
- `ChunkCoord` - Hashable, Codable
- `World` - 8x6 chunk grid, `tileAt(x:y:)`, `setTile(x:y:to:)` returns dirty ChunkCoord
- `PlayerState` - position/velocity in tile units, AABB (0.8 x 1.8 tiles)
- `AABB` - intersection test, tile range computation
- `Inventory` - 5 slots, add (stack/fill), removeSelected
- `GameCommand` - Codable enum
- `Events` - GameEvent enum

### Step 2: World generation
- `WorldGenerator` using `GKPerlinNoiseSource` for surface heights
- Surface ~128 tiles with +/-16 variation
- Layers: air above surface, grass at surface, dirt 20 tiles deep, then stone
- 3% ore in stone layer via deterministic hash
- Unit tests: same seed = same world, layer correctness

### Step 3: Physics & game simulation
- `PhysicsSystem` - gravity (-30 t/s^2), jump (12 t/s), move (6 t/s), friction, terminal velocity
- Separate-axis collision resolution (X then Y)
- `GameSimulation` (@Observable) - fixed timestep accumulator at 60Hz
- Command processing: move, jump, dig (range check + inventory add), place (collision check + inventory remove)
- Spawn player at world center on surface

### Step 4: SpriteKit rendering
- `TileAtlas` - generates colored-square textures per tile type, builds SKTileSet
- `ChunkRenderer` - creates 48 SKTileMapNodes, dirty tracking, rebuild per frame
- `PlayerNode` - cyan rectangle, bottom-center anchor
- `CameraController` - smooth lerp follow, world bounds clamping
- `GameScene` - wires everything together, update loop processes events

### Step 5: SwiftUI app shell
- `DigCraftApp` - @main with WindowGroup
- `ContentView` - state machine: title vs game
- `TitleScreenView` - New Game (random seed) / Load Game
- `GameView` - creates simulation + scene, hosts SpriteView, overlays hotbar + pause button

### Step 6: Input system
- `InputMapper` - macOS: WASD + Space + mouse (left=dig, right=place) + number keys
- iOS: left side drag = move, right side tap = dig, jump button
- Held-key tracking for smooth movement

### Step 7: UI overlays
- `HotbarView` - 5 slots with tile color, count, yellow selection border
- `PauseMenuView` - Resume / Save / Quit with material background
- `ControlsOverlay` - in-game controls reference, toggled via help button

### Step 8: Save/Load
- `SaveModels` - SaveData (seed + tile deltas + player + inventory)
- `SaveManager` - delta encoding (compare current vs regenerated world), JSON to documents dir
- `GameSimulation.restore(player:inventory:)` method
- Load flow: regenerate from seed, apply deltas, restore player

### Step 9: Polish
- Debug overlay toggle (tile grid, player AABB, chunk borders, FPS via SKView)
- iOS jump button
- `git init` and initial commit

## Key Design Decisions

1. **SKTileMapNode per chunk** (48 nodes) for fastest MVP. Interface supports swapping to pre-rendered chunk textures if perf issues arise.
2. **`@Observable`** (not ObservableObject) for GameSimulation -- SwiftUI hotbar reads inventory directly with automatic fine-grained updates.
3. **Fixed timestep accumulator** decouples physics from frame rate (important for ProMotion 120Hz iPads).
4. **Delta-based saves** -- only modified tiles stored, regenerate world from seed on load.
5. **Y=0 is bottom** matching SpriteKit's coordinate system, no flipping needed.
6. **Player hitbox 0.8 x 1.8 tiles** -- narrower than 1 tile so player can fit through 1-wide gaps.

## Verification
- `xcodegen generate` produces buildable project
- Run on iOS Simulator + macOS: world renders, player moves/jumps, can dig and place tiles
- Save game, quit, load game: world state restored accurately
- Unit tests pass for simulation types, world generation, physics, save/load
