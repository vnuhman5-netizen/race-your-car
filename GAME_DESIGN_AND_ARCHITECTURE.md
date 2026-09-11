# City Driver — Design & Architecture Reference

An original arcade city-driving game for Linux/Ubuntu, built in Godot 4.x / GDScript.
Inspired by the *gameplay style* of mobile driving games (drive around a city, complete
point-to-point and parking missions, obey traffic rules, earn money, unlock cars).
No copyrighted assets, branding, UI, sounds, code, or map data are used anywhere in
this project — everything is either built with Godot's built-in primitives/procedural
meshes or, later, sourced from clearly-labeled free/CC0 asset packs.

This document is a living reference. Keep it open while we build — each milestone will
reference sections of it and update it as the project grows.

---

## 1. Game Design Overview

**Core loop:** pick a mission from a list → drive to the objective while following
traffic rules → complete it (arrive / park correctly) within time and penalty limits →
earn money → spend money on new cars and upgrades in the Garage → repeat with harder
missions.

**Pillars:**
- **Arcade, not sim.** Cars should be fun and forgiving to drive with mouse/keyboard,
  not a physics sim you need to master.
- **Readable city.** A small number of clearly laid-out intersections, not an open
  world — easier to build, easier to design missions around.
- **Systemic, data-driven content.** Missions, cars, and upgrades are defined as data
  (Godot `Resource` files) so new content doesn't require new code.

**Feature set (target, built incrementally — see Roadmap):**
Third-person driving, traffic vehicles, traffic lights, intersections, pedestrians,
parking missions, point-to-point missions, speed-limit/rule violations, collision
detection, money/reward system, vehicle upgrades, multiple unlockable cars, mission
progression, main menu, garage, settings, pause menu, results screen, save/load.

---

## 2. Recommended Project Architecture

**Engine pattern:** Autoload singletons for cross-scene state + independent, reusable
scenes composed together, communicating via **signals** (never deep `get_node()` reaches
into unrelated branches of the tree).

**Autoload singletons (Project Settings → Autoload):**

| Name | Responsibility | Added in |
|---|---|---|
| `GameManager` | Pause/resume, global game state, cross-scene requests (e.g. "reset the car") | Milestone 1 |
| `EconomyManager` | Money balance, earning/spending | Milestone 6 |
| `SaveManager` | Load/save `SaveData` resource to disk | Milestone 6 |
| `MissionManager` | Active mission, mission list, completion/failure signals | Milestone 5 |
| `AudioManager` | SFX/music bus control, one-shot SFX playback | Milestone 8 |

**Why autoloads for this?** These are things exactly one of exists for the whole game
session and many unrelated scenes need to read or trigger (HUD, missions, garage, pause
menu all care about money; almost everything cares about pause state). Everything else
(a specific car, a specific traffic light) stays a normal node in the scene tree.

**Composition pattern for gameplay scenes:** each major "thing" (car, traffic light,
pedestrian, mission trigger) is its own `.tscn` with its own script, so it can be
placed, duplicated, and reused freely in the editor without code changes. A car doesn't
know about missions; a mission doesn't know how a car's engine works. They only talk
through signals and small, explicit APIs (e.g. `car.speed_changed`, `mission.completed`).

---

## 3. Folder Structure (target — grows milestone by milestone)

```
res://
├── project.godot
├── icon.svg
├── scenes/
│   ├── Main.tscn                 # entry point scene
│   ├── world/
│   │   ├── World_Downtown.tscn   # first city map
│   │   ├── TrafficLight.tscn
│   │   └── ParkingZone.tscn
│   ├── car/
│   │   ├── Car.tscn              # base reusable car
│   │   └── variants/             # per-model overrides (later)
│   ├── traffic/
│   │   ├── TrafficCar.tscn
│   │   └── Pedestrian.tscn
│   ├── missions/
│   │   └── MissionMarker.tscn
│   └── ui/
│       ├── HUD.tscn
│       ├── MainMenu.tscn
│       ├── PauseMenu.tscn
│       ├── Garage.tscn
│       ├── SettingsMenu.tscn
│       └── ResultsScreen.tscn
├── scripts/
│   ├── autoload/
│   │   ├── GameManager.gd
│   │   ├── EconomyManager.gd
│   │   ├── SaveManager.gd
│   │   ├── MissionManager.gd
│   │   └── AudioManager.gd
│   ├── car/
│   │   ├── Car.gd
│   │   └── CameraRig.gd
│   ├── traffic/
│   │   ├── TrafficCar.gd
│   │   ├── TrafficLight.gd
│   │   └── Pedestrian.gd
│   ├── missions/
│   │   ├── Mission.gd            # Resource script
│   │   └── MissionMarker.gd
│   └── ui/
│       ├── HUD.gd
│       ├── MainMenu.gd
│       ├── PauseMenu.gd
│       ├── Garage.gd
│       └── ResultsScreen.gd
├── resources/
│   ├── cars/                     # CarStats .tres files, one per model
│   ├── missions/                 # Mission .tres files, one per mission
│   └── theme/                    # shared UI Theme resource
├── materials/                    # shared StandardMaterial3D resources
└── assets/                       # third-party CC0/free assets, clearly credited
    └── CREDITS.md
```

**Milestone 1 uses a deliberately smaller slice of this** (see §7) so we get something
playable before investing in the full structure.

---

## 4. Scene Structure (target end state)

```
Main.tscn (Node)
├── World_Downtown.tscn (instanced)
│   ├── Ground, roads, buildings (StaticBody3D)
│   ├── TrafficLight.tscn instances at intersections
│   ├── TrafficCar.tscn instances on lanes
│   ├── Pedestrian.tscn instances on sidewalks
│   └── MissionMarker.tscn instances at objectives
├── Car.tscn (instanced) — the player's current car
├── CameraRig.tscn (instanced) — follows Car
└── UI (CanvasLayer)
    ├── HUD.tscn
    ├── PauseMenu.tscn (hidden by default)
    └── ResultsScreen.tscn (hidden by default)
```

`MainMenu.tscn`, `Garage.tscn`, and `SettingsMenu.tscn` are separate scenes swapped in
as the "current scene" before `Main.tscn` is loaded (classic menu → gameplay flow).

---

## 5. Scripts & Responsibilities

| Script | Type | Responsibility |
|---|---|---|
| `GameManager.gd` | Autoload | Pause/resume state, global signals (car reset, etc.) |
| `Car.gd` | RigidBody3D | Reads input, arcade acceleration/braking/steering, emits `speed_changed` |
| `CameraRig.gd` | Node3D | Smooth third-person follow/look-at |
| `HUD.gd` | CanvasLayer | Speed readout, pause menu, wires input to `GameManager` |
| `TrafficLight.gd` *(M3)* | Node3D | Red/yellow/green cycle, exposes `is_red()` for cross-traffic logic |
| `TrafficCar.gd` *(M4)* | RigidBody3D | Follows a lane path, obeys traffic lights, simple avoidance |
| `Pedestrian.gd` *(M4)* | CharacterBody3D | Walks a simple path, crosses at lights |
| `Mission.gd` *(M5)* | Resource | Data: type, description, target, reward, time limit |
| `MissionMarker.gd` *(M5)* | Area3D | Detects car arrival, reports to `MissionManager` |
| `EconomyManager.gd` *(M6)* | Autoload | Money balance, spend/earn API |
| `SaveManager.gd` *(M6)* | Autoload | Serialize/deserialize `SaveData` to `user://savegame.tres` |
| `Garage.gd` *(M7)* | Control | Car selection/purchase, upgrade UI |

---

## 6. Input Actions

Configured in **Project Settings → Input Map** (not stored in version-controlled
`project.godot` by us manually — you add these once in the editor):

| Action | Suggested keys | Used by |
|---|---|---|
| `move_forward` | `W`, `Up Arrow` | Car |
| `move_backward` | `S`, `Down Arrow` | Car |
| `steer_left` | `A`, `Left Arrow` | Car |
| `steer_right` | `D`, `Right Arrow` | Car |
| `brake` | `Space` | Car |
| `pause` | `Escape` | HUD |
| `reset_car` | `R` | HUD (debug convenience, keep for the whole project) |
| `handbrake` *(later)* | `Shift` | Car (drift missions) |
| `horn` *(later)* | `H` | Car |

The architecture is input-agnostic: gameplay code only ever calls
`Input.get_action_strength(...)` / `Input.is_action_pressed(...)`, never checks specific
keys. That means adding a gamepad or touch-input layer later is just a matter of
mapping new physical inputs onto the same action names — no gameplay code changes.

---

## 7. Data Structures (target design, introduced as needed)

**`CarStats` (Resource, introduced Milestone 7)**
```gdscript
class_name CarStats extends Resource
@export var car_name: String
@export var scene: PackedScene
@export var price: int
@export var max_forward_speed: float
@export var acceleration: float
@export var braking_power: float
@export var max_turn_rate: float
```
One `.tres` file per car model in `resources/cars/`. The Garage reads all of them to
populate the car list — adding a new car is "add a `.tres` + a scene", no code changes.

**`Mission` (Resource, introduced Milestone 5)**
```gdscript
class_name Mission extends Resource
@export var mission_id: String
@export var title: String
@export var description: String
@export_enum("PointToPoint", "Parking", "TimeTrial") var mission_type: String
@export var target_position: Vector3
@export var reward_money: int
@export var time_limit_seconds: float
```

**`SaveData` (Resource, introduced Milestone 6)**
```gdscript
class_name SaveData extends Resource
@export var money: int = 0
@export var unlocked_car_ids: Array[String] = []
@export var selected_car_id: String = ""
@export var completed_mission_ids: Array[String] = []
```
Saved with `ResourceSaver.save()` to `user://savegame.tres` — Godot's built-in binary/
text resource format, reliable and simple, no external dependencies.

---

## 8. Development Roadmap

| Milestone | Goal |
|---|---|
| **M1** | Playable prototype: drivable car, third-person camera, ground plane, speed HUD, pause, reset |
| **M2** | Refactor into modular scenes (`Car.tscn`, `World.tscn` split out), simple low-poly car body, a real road layout with lane markings |
| **M3** | Traffic lights, intersections, speed-limit zones, rule-violation tracking |
| **M4** | Traffic vehicles (lane-following AI) and pedestrians |
| **M5** | Mission system: point-to-point + parking missions, mission UI, results/game-over screen |
| **M6** | Money/reward system, save/load progress |
| **M7** | Garage: multiple unlockable cars, upgrades |
| **M8** | Main menu, settings menu, pause menu polish, placeholder audio |
| **M9** | Performance pass, input-abstraction check for future touch/gamepad, Linux export & packaging |

We start Milestone 1 below.
