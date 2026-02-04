# DigCraft

A 2D mining/building game built with SpriteKit and SwiftUI, targeting iOS 17+ and macOS 14+.

## Prerequisites

- **Xcode 16+** (Swift 6.0)
- **xcodegen** - install via Homebrew:
  ```
  brew install xcodegen
  ```

## Build Instructions

1. Clone the repo and `cd` into it:
   ```
   git clone <repo-url>
   cd 2d-digger
   ```

2. Generate the Xcode project:
   ```
   xcodegen generate
   ```

3. Open the project:
   ```
   open DigCraft.xcodeproj
   ```

4. In Xcode:
   - Pick a scheme from the scheme selector in the toolbar:
     - **DigCraft_macOS** to run on your Mac
     - **DigCraft_iOS** to run on an iOS Simulator or device
   - For iOS, choose a simulator (e.g. iPhone 16) from the destination dropdown next to the scheme
   - Press **Cmd+R** (or Product > Run) to build and launch

### Command Line Alternative

```
# macOS
xcodebuild -project DigCraft.xcodeproj -scheme DigCraft_macOS -destination 'platform=macOS' build

# iOS Simulator
xcodebuild -project DigCraft.xcodeproj -scheme DigCraft_iOS -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Running Tests

In Xcode, press **Cmd+U** (or Product > Test) with the `DigCraftTests_macOS` or `DigCraftTests_iOS` scheme selected.

From the command line:
```
xcodebuild test -project DigCraft.xcodeproj -scheme DigCraftTests_macOS -destination 'platform=macOS'
```

## Controls

### macOS
| Key | Action |
|-----|--------|
| A / D | Move left / right |
| W / Space | Jump |
| Left click | Dig tile |
| Right click | Place tile |
| 1-5 | Select hotbar slot |

### iOS
- Drag left side of screen to move
- Tap right side of screen to dig
- Jump button in top-right corner

## Project Structure

The project uses xcodegen (`project.yml`) to generate the Xcode project. The `.xcodeproj` is gitignored -- always regenerate it after pulling.

```
DigCraft/
  App/            SwiftUI shell (app entry, navigation, game view)
  Game/
    Simulation/   Pure Swift game logic (world, physics, inventory)
    Rendering/    SpriteKit rendering (tile maps, camera, player sprite)
    Input/        Platform input mapping
    SaveLoad/     Delta-based JSON persistence
  UI/             SwiftUI overlays (hotbar, pause menu)
DigCraftTests/    Unit tests (simulation, world gen, physics, save/load)
```
