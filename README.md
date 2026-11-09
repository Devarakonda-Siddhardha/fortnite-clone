# Fortnite Battle Royale Clone (Godot 4.3)

A stylized third-person Battle Royale game built with **Godot 4.3**, fully reproducing the benchmark procedures and specifications established by Stefan 3D AI (*Claude vs GPT vs Gemini Battle Royale benchmark*).

---

## 🎮 Key Features

### 1. Locomotion & Traversal System
- **WASD Movement:** Walk (6.0 m/s) and Sprint (9.5 m/s with `Shift`).
- **Tactical Slide:** Press `Ctrl` while sprinting to execute a momentum-based slide into crouch with dynamic camera lowering.
- **Ledge Mantle:** Smooth ledge climbing for vertical obstacles between 0.75m and 2.3m.
- **Deployable Glider:** Press `Space` in mid-air to deploy the glider canopy, reducing fall velocity to a floaty -3.5 m/s.
- **Third-Person Camera Rig:** Clamped pitch (-75° to +75°), over-the-shoulder `SpringArm3D` with collision margin. `Escape` toggles mouse capture.

### 2. Authentic 4m-Grid Building System
- **Grid Snapping:** Precision snapping to 4.0m × 4.0m world grid cells, automatically quantised to cardinal player camera yaw angles.
- **Holographic Blueprint Preview:** Semi-transparent cyan holographic preview when affordable; glowing red when unaffordable.
- **Turbo Building:** Hold Left Mouse Button to continuously construct pieces along your movement path.
- **Keys:**
  - `Q`: Wall (4×4×0.2m)
  - `Z`: Floor (4×4×0.2m)
  - `C`: Ramp (rises 4m over 4m hypotenuse)
  - `V`: Roof (4×4m pyramid cone)
  - `RMB` (in build mode): Cycle Material (**Wood** 150 HP -> **Stone/Brick** 300 HP -> **Metal** 450 HP).
- **Structure HP Scaling & Growth:** Each piece costs 10 materials and dynamically grows upward from 40% initial HP to 100% full health.

### 3. Combat, Weapons & Audio SFX
- **Pickaxe (`F` key):** Swings with a forward punch animation.
- **Blue Weak-Point Indicator:** Striking breakable trees, rocks, or structures spawns a blue target circle; hitting the weak point grants **2.5x damage (50 HP)** and **double material yield**.
- **6-Slot Weapon Hotbar:**
  - **Slot 0:** Harvesting Pickaxe (`F`)
  - **Slot 1:** Assault Rifle (Rapid automatic fire, 32 DMG, authentic audio `assault_rifle.wav`, camera recoil kick)
  - **Slot 2:** Pump Shotgun (5-pellet spread, 90 DMG burst, audio `shotgun.wav`)
  - **Slot 3:** Bolt-Action Sniper Rifle (Precision long-range, 110 DMG, audio `sniper_rifle.wav`)
  - **Slot 4:** Shield Potion (+50 Shield)
  - **Slot 5:** Medkit (Restores 100 HP)
- **3D Held Weapon View:** Over-the-shoulder 3D weapon models rendered dynamically with recoil and cadence animations.

### 4. 24 AI Opponent Bots & Match Simulation
- **24 Named Bots:** Spawns across village, industrial yard, hilltop towers, and biomes.
- **State Machine AI:**
  - **Patrol:** Wanders between island points of interest.
  - **Attack & Strafe:** Line-of-sight raycasting, evasive left/right strafing, and burst firing with spatial 3D audio.
  - **Defensive Building:** 60% chance to immediately build a protective wall upon taking damage!
  - **Storm Evasion:** Detects storm barrier shrinking and sprints toward the safe zone center.
  - **Death & Loot Drops:** Drops floating 3D weapons and shield potions upon elimination.

### 5. Interactive Loot & Chest System
- **Treasure Chests:** Placed inside village houses and industrial warehouses. Approaching chests triggers interactive opening animation and scatters weapons, shield potions, and building materials.
- **Floating 3D Ground Pickups:** Rotating, bobbing 3D items with rarity glow that equip to player inventory on touch.

### 6. 5-Phase Shrinking Storm Barrier
- **Animated Barrier:** 5-phase shrinking cylindrical purple forcefield with randomized center offsets.
- **Direct Health Damage:** Bypasses shields and applies escalating DPS (1 -> 2 -> 5 -> 8 -> 10 DPS).

### 7. Procedural 400×400m Island & Landmarks
- **Terrain & Biomes:** Procedural FastNoiseLite heightmap with radial ocean falloff, sandy beaches, green plains, and rocky cliffs.
- **Landmarks:**
  - **Center Village:** 6 furnished houses arranged around a central plaza with loot chests.
  - **Industrial Yard:** 3 large warehouses with loot chests.
  - **Hilltop Lookout Towers:** 3 high-altitude vantage points.
  - **Battle Bus:** Airborne drop vehicle suspended 80m above the island.
  - **Foliage & Props:** 140 pine, oak, and palm trees + 90 destructible stone boulders.

### 8. Full Battle Royale Match Loop & HUD
- **HUD Elements:**
  - Health bar (100 HP, green) & Shield bar (100 Shield, blue).
  - Wood, Stone, and Metal material counters.
  - 6-slot inventory hotbar with active selection indicator.
  - Storm phase indicator and live countdown timer.
  - Live Player Counter (`25 ALIVE`) and Player Eliminations (`KILLS: 0`).
  - Real-time Killfeed with colored victim/killer alerts.
  - `#1 VICTORY ROYALE` animated pop-in banner upon winning the match!
  - `ELIMINATED / GAME OVER` banner upon death.

---

## 📂 Project Structure

```
├── project.godot                     # Godot 4.3 project configuration, input maps & autoloads
├── assets/
│   ├── audio/                        # Authentic gunshot sound effects (.wav)
│   ├── models/                       # 21 benchmark 3D models & modular building kit (.glb)
│   ├── animations/                   # Character traversal & combat animations (.fbx)
│   └── characters/                   # Mixamo 3D character rigs (.fbx)
├── scenes/
│   ├── main.tscn                     # Master world scene (Island, Storm, Bots, Player, HUD)
│   ├── player/
│   │   └── player.tscn               # CharacterBody3D, CameraRig, Glider, BuildingSystem, WeaponManager
│   ├── bot/
│   │   └── bot.tscn                  # AI Opponent with line-of-sight raycasts & 3D audio
│   ├── building/
│   │   ├── wall.tscn                 # 4x4m Wall piece
│   │   ├── floor.tscn                # 4x4m Floor piece
│   │   ├── ramp.tscn                 # 4m Ramp piece
│   │   └── roof.tscn                 # 4m Pyramid roof piece
│   ├── environment/
│   │   ├── island.tscn               # Procedural 400x400m island terrain & ocean
│   │   ├── storm.tscn                # Cylindrical 5-phase shrinking barrier
│   │   ├── chest.tscn                # Interactive treasure chest with loot spawning
│   │   ├── pickup.tscn               # Floating rotating 3D ground item pickup
│   │   ├── tree.tscn                 # Destructible wood tree
│   │   └── rock.tscn                 # Destructible stone rock
│   └── ui/
│       └── hud.tscn                  # Health, shield, materials, hotbar, storm, killfeed, victory banner
└── scripts/
    ├── autoload/
    │   ├── globals.gd                # Global state, materials economy, signals, player health/shield
    │   └── game_manager.gd           # 25-player match loop, alive counter, killfeed, victory condition
    ├── player/
    │   └── player_controller.gd      # Locomotion, slide decay, mantle raycasts, glider fall, camera rig
    ├── bot/
    │   └── bot_ai.gd                 # Bot patrol, target scanning, strafing, defensive walls, loot drop
    ├── building/
    │   ├── building_system.gd        # 4m grid snap, blueprint hologram, turbo build
    │   └── buildable.gd              # Piece health scaling (Wood/Stone/Metal), growth animation, destruction
    ├── weapons/
    │   └── weapon_manager.gd         # Pickaxe weak point minigame, hitscan weapons, audio SFX, held models
    ├── environment/
    │   ├── island_generator.gd       # FastNoiseLite terrain mesh, biomes, village, warehouses, towers, bus
    │   ├── bot_spawner.gd            # Spawns 24 named AI bots across island POIs
    │   ├── storm.gd                  # 5-phase shrinking circle & shield-bypassing DPS
    │   ├── chest.gd                  # Chest opening interaction & loot scatter
    │   ├── pickup.gd                 # Floating item pickup logic & inventory integration
    │   └── destructible.gd           # Breakable object script
    └── ui/
        └── hud.gd                    # HUD display update listeners, killfeed animations, victory royale tween
```

---

## 🚀 Running the Game

Launch with **Godot 4.3**:

```bash
# Launch interactive gameplay in Godot 4.3
godot scenes/main.tscn

# Or run headless automated test suite:
godot --headless --path . --fixed-fps 60 --quit-after 180
```

---

## 🎮 Controls

| Action | Key / Control |
|---|---|
| **Move** | `W`, `A`, `S`, `D` |
| **Look / Aim** | `Mouse` |
| **Sprint** | `Shift` (hold) |
| **Slide / Crouch** | `Ctrl` (press while sprinting to slide) |
| **Jump / Glider** | `Space` (press in air to toggle glider) |
| **Mantle** | `W` + `Space` into ledge (0.75m – 2.3m) |
| **Fire / Place Build / Swing** | `Left Mouse Button` |
| **Cycle Material (in Build Mode)** | `Right Mouse Button` |
| **Pickaxe** | `F` |
| **Weapons / Items (Slots 1-5)** | `1`, `2`, `3`, `4`, `5` |
| **Build Wall (4×4m)** | `Q` |
| **Build Floor (4×4m)** | `Z` |
| **Build Ramp (4m)** | `C` |
| **Build Roof (4×4m Pyramid)** | `V` |
| **Unlock / Lock Mouse Cursor** | `Escape` |
