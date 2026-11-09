# Fortnite Clone (Godot 4.3)

A stylized third-person Battle Royale prototype built with **Godot 4.3** and designed for AI-driven development with **Gemini Flash**.

---

## 🎮 Features Implemented

1. **Third-Person Locomotion & Camera Rig:**
   - **WASD:** Walk (6.0 m/s) and Sprint (9.5 m/s with `Shift`).
   - **Crouch & Slide:** Press `Ctrl` while sprinting to initiate a downhill/flat slide with friction decay.
   - **Ledge Mantle:** Automatic climbing when leaping towards ledges between 0.75m and 2.3m.
   - **Glider Canopy:** Press `Space` while falling in the air to deploy the glider (terminal velocity capped at -3.5 m/s).
   - **Mouse Camera:** Clamped pitch (-75° to +75°), over-the-shoulder `SpringArm3D` with collision separation. `Escape` frees mouse.

2. **Fortnite 4m-Grid Building System:**
   - **Grid Snapping:** Snaps pieces to 4.0m × 4.0m world cells, quantised to cardinal camera angles.
   - **Holographic Blueprint Preview:** Semi-transparent cyan preview when affordable; red when unaffordable.
   - **Turbo Build:** Hold Left Mouse Button to continuously place pieces.
   - **Keys:**
     - `Q`: Wall (4×4×0.2m)
     - `Z`: Floor (4×4×0.2m)
     - `C`: Ramp (rises 4m over 4m hypotenuse)
     - `V`: Roof (4×4m pyramid cone)
     - `RMB` (in build mode): Cycle Material (**Wood** 150HP -> **Stone** 300HP -> **Metal** 450HP).
     - Each piece costs 10 materials and builds up its HP dynamically.

3. **Harvesting & Weak-Point Minigame:**
   - **Pickaxe (`F` key):** Swings at world objects (trees, rocks, player buildings).
   - **Blue Weak-Point Indicator:** Hits generate a dynamic weak point on the hit surface. Striking the blue circle grants **2.5x damage (50 HP)** and **double material yield**.
   - **Weapon Slots (`1-5`):** Assault Rifle with recoil spread bloom, hitscan raycasting, and damage.

4. **Shrinking Storm System:**
   - **5-Phase Storm:** Shrinking cylindrical purple barrier with randomized center offsets.
   - **Storm Damage:** Directly damages player health (bypassing shields) scaling from 1 DPS in early phases to 10 DPS in late phases.

5. **Procedural 400×400m Island & Water:**
   - Procedural heightmap with FastNoiseLite, radial ocean falloff, and altitude vertex coloring (green grass, sandy beach, rocky cliffs).
   - Procedural scattering of destructible trees and rocks.

6. **Fortnite HUD (CanvasLayer):**
   - Green Health bar (100) & Blue Shield bar (100).
   - Material counters (Wood, Stone, Metal).
   - 6-slot Hotbar with active highlight.
   - Storm phase and countdown timer.
   - Building mode helper overlay.

---

## 📂 Project Structure

```
├── project.godot                     # Godot 4.3 project configuration & input maps
├── scenes/
│   ├── main.tscn                     # Main game scene
│   ├── player/
│   │   └── player.tscn               # CharacterBody3D, CameraRig, Glider, BuildingSystem
│   ├── building/
│   │   ├── wall.tscn                 # 4x4m Wall piece
│   │   ├── floor.tscn                # 4x4m Floor piece
│   │   ├── ramp.tscn                 # 4m Ramp piece
│   │   └── roof.tscn                 # 4m Pyramid roof piece
│   ├── environment/
│   │   ├── island.tscn               # Procedural 400x400m island terrain & ocean
│   │   ├── storm.tscn                # Cylindrical 5-phase shrinking barrier
│   │   ├── tree.tscn                 # Destructible wood tree
│   │   └── rock.tscn                 # Destructible stone rock
│   └── ui/
│       └── hud.tscn                  # Health, shield, materials, hotbar, storm UI
└── scripts/
    ├── autoload/
    │   └── globals.gd                # Game state, economy, signals, player stats
    ├── player/
    │   └── player_controller.gd      # Locomotion, slide, mantle, glider, camera
    ├── building/
    │   ├── building_system.gd        # 4m grid snap, blueprint preview, turbo build
    │   └── buildable.gd              # Piece health, material scaling, destruction
    ├── weapons/
    │   └── weapon_manager.gd         # Pickaxe, harvesting weak points, guns
    ├── environment/
    │   ├── island_generator.gd       # Procedural island surface tool & prop scatter
    │   ├── storm.gd                  # 5-phase shrinking circle & DPS tick
    │   └── destructible.gd           # Breakable object script
    └── ui/
        └── hud.gd                    # HUD display update listeners
```

---

## 🚀 Running the Project

You can run the project using Godot 4.3:

```bash
# Launch with Godot 4.3
godot scenes/main.tscn

# Or headless validation test:
godot --headless --path . --fixed-fps 60 --quit-after 60
```
