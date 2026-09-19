# 🛠️ Sprite StaticBody Builder for Godot 4
### *Automated 2D Physics Generation & Real-Time Dynamic Shadow Toolset*

[![Godot Engine](https://img.shields.io/badge/Godot-4.x-478CBF?logo=godotengine&logoColor=white)](https://godotengine.org/)
[![Language](https://img.shields.io/badge/Language-GDScript_2.0-blue)](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Category](https://img.shields.io/badge/Category-Tools_%26_Physics-orange)](#)
[![Status](https://img.shields.io/badge/Status-Production_Ready-success)](#)

A high-performance, developer-friendly Godot 4 editor plugin that bridges the gap between 2D concept art and physics-ready game assets. It automatically vectorizes arbitrary sprite textures into optimized **`StaticBody2D`** nodes with pixel-perfect polygon collision, intelligent polygon decimation, convex decomposition, live viewport previews, and **rotation-invariant real-time dynamic shadows**.

---

## 🌟 Executive Summary & Problem Solved

Creating collision geometry for irregular 2D sprites in game engines is traditionally tedious, manual, and error-prone:
1. **Manual Polygon Tracing**: Hand-placing dozens of collision vertices wastes artist and developer time.
2. **Concave Physics Issues**: 2D physics engines struggle with complex concave polygons without decomposition.
3. **Rigid Shadow Artifacts**: Standard 2D drop-shadows are locked to the object's local transform; rotating the object causes the shadow to swing unnaturally across the screen, violating consistent world lighting.

**Sprite StaticBody Builder** solves all three problems in one unified dock interface with a single click.

---

## 🚀 Key Highlights & Capabilities

- 🎯 **One-Click Vectorization**: Converts any `Sprite2D` or FileSystem texture into a physics-ready `StaticBody2D` instantly.
- 📐 **Ramer-Douglas-Peucker (RDP) Simplification**: Reduces thousands of pixel boundary points into lightweight, performant polygons (32 to 128 points) tailored for mobile and desktop budgets.
- 🧩 **Convex Decomposition Engine**: Automatically decomposes complex concave shapes into convex partitions using ear-clipping to prevent physics clipping and tunneling.
- 💡 **Real-Time Dynamic Shadows (`RealtimeShadow2D`)**: A specialized tool script that counter-rotates shadow displacement in world space. Shadows stay anchored to the global light source in real-time as objects or levels rotate.
- 👁️ **Live Viewport Canvas Overlay**: Renders collision wireframes, vertex indicators, and projected shadow contours directly inside the Godot 2D editor before committing.
- ⏪ **Full Engine Undo/Redo**: Seamlessly integrated into Godot's `EditorUndoRedoManager` (`Ctrl+Z` / `Ctrl+Y`).

---

## 🎛️ Dock Window Reference Guide

The plugin adds a clean, native tab to your Godot editor dock titled **"StaticBody"**. Below is an in-depth breakdown of every section and control.

```
┌─────────────────────────────────────────────────────────┐
│ [Icon] Target: Detected Sprite: Obstacle_Rock           │
│        res://art/rock.png (128x128)                     │
├─────────────────────────────────────────────────────────┤
│ ▼ ALPHA & TRACE                                         │
│   Alpha Threshold:     [====|====] 0.50                 │
│   Simplification:      [ Medium (Balanced - 64 pts) ▼ ] │
│   Max Points:          [ 64 ]                           │
│   Collision Mode:      [ Single Polygon             ▼ ] │
│   Build Mode:          [ Solids (Filled Area)       ▼ ] │
├─────────────────────────────────────────────────────────┤
│ ▼ GAMEPLAY ARCHETYPES & PRESETS                         │
│   Preset:              [ 🧱 Static Wall / Platform  ▼ ] │
├─────────────────────────────────────────────────────────┤
│ ▼ REAL SHADOW SPRITE                                    │
│   [x] Generate Real Shadow Sprite                       │
│   Anchor / Base:       [ Center (Top-Down)          ▼ ] │
│   Offset (X, Y):       X: [ 6.0 ]   Y: [ 8.0 ]          │
│   Light Angle / Dist:  Angle: [ 53.1° ]  Dist: [ 10.0px]│
│   Color / Alpha:       [ ■ rgba(0, 0, 0, 0.45) ]        │
│   Shadow Scale:        [ 1.00 ]                         │
│   [x] Realtime Rotation Sync                            │
├─────────────────────────────────────────────────────────┤
│ ▼ WORKFLOW OPTIONS                                      │
│   [x] Create StaticBody2D   [x] Keep Main Sprite        │
│   [x] Auto-Generate Collision                           │
├─────────────────────────────────────────────────────────┤
│ [ 🔨 Create StaticBody ]       [ 🔄 Regenerate ]        │
│ [ 👁️ Live Preview ]           [ 🗑️ Remove Collision ]   │
│ Status: Generated 1 polygon, 42 vertices total.         │
└─────────────────────────────────────────────────────────┘
```

---

### 1. Target Detection Header
Automatically monitors editor selection without manual dragging:
- **`Sprite2D` in Scene**: Detects the sprite and inspects its texture, centered mode, offsets, and regions.
- **`StaticBody2D` in Scene**: Detects existing bodies and reads previously generated collisions and shadow configurations.
- **Texture in FileSystem**: Allows building physics bodies straight from the asset drawer into the center of the active viewport.

---

### 2. Alpha & Trace Settings

| Setting | Type | Purpose & How It Works |
| :--- | :--- | :--- |
| **Alpha Threshold** | Slider + SpinBox (`0.0 - 1.0`) | Determines the opacity cutoff for solid pixels. Soft semi-transparent borders or anti-aliasing halos are ignored below this value (default: `0.5`). |
| **Simplification Preset** | Dropdown | Controls the vertex reduction aggressiveness via the **Ramer-Douglas-Peucker (RDP)** algorithm:<br>• **Low (Detailed - 128 pts)**: Preserves fine details and jagged outlines.<br>• **Medium (Balanced - 64 pts)**: Sweet spot for 2D physics performance and accuracy.<br>• **High (Low-Poly - 32 pts)**: Minimalist geometry optimized for mobile and large swarms of objects.<br>• **Custom...**: Unlocks direct epsilon distance control. |
| **Custom Epsilon** | SpinBox (`0.1 - 20.0`) | *Visible only when preset is set to Custom.* Epsilon distance in pixels. Higher values yield fewer vertices by eliminating smaller contours. |
| **Max Points** | SpinBox (`4 - 512`) | Defines a hard upper limit on the vertex count per polygon, guaranteeing strict memory and physics budgets. |
| **Collision Mode** | Dropdown | • **Single Polygon**: Creates one unified boundary polygon.<br>• **Convex Decomposition**: Automatically splits concave shapes into convex partitions using ear-clipping to prevent physics clipping and tunneling. |
| **Build Mode** | Dropdown | Corresponds to Godot's `CollisionPolygon2D.build_mode`: <br>• **Solids (Filled Area)**: The entire interior is solid (`BUILD_SOLIDS`).<br>• **Segments (Edges Only)**: Hollow boundary outline (`BUILD_SEGMENTS`). Ideal for boundary barriers or hollow chambers. |

---

### 3. Gameplay Archetypes & Presets

Provides standardized physics configurations across multiple game genres:

- 🧱 **Static Wall / Platform**: Standard static collision for level geometry, platforms, and boundaries.
- 🌀 **Rotating Obstacle / Spinner**: Attaches a lightweight rotation script (`RotatingObstacle`) that drives continuous angular motion. Unlocks an interactive **Rotation Speed (°/s)** spinbox.
- ⚠️ **Hazard / Trap**: Automatically registers the body into the engine `"hazards"` group for zero-boilerplate collision detection (`body.is_in_group("hazards")`).
- 🏁 **Goal / Checkpoint**: Archetype for level-exit triggers and win markers.

---

### 4. Real Shadow Sprite & Dynamic Lighting

A standout technical feature of this tool is its **rotation-invariant dynamic shadow system**.

| Setting | Description |
| :--- | :--- |
| **Generate Real Shadow Sprite** | Generates an intelligent, dedicated shadow node beneath the main visual sprite. |
| **Shadow Origin / Anchor** | Sets the geometric anchor point:<br>• **Center (Top-Down)**: Originates from the sprite center (standard for top-down games).<br>• **Bottom / Ground (Floor)**: Anchors to the base/feet of the sprite (standard for platformers and isometric games where shadows cast along the floor).<br>• **Custom Anchor**: Custom pivot point via offset vectors. |
| **Offset (X, Y)** | Direct pixel translation along Cartesian coordinates. |
| **Light Angle / Distance** | Alternative polar lighting controls:<br>• **Light Angle (°)**: Circular dial/slider (`0°` = Right, `90°` = Down, `135°` = Down-Right, `180°` = Left).<br>• **Shadow Distance (px)**: Distance cast away from the anchor point.<br>*(Offset X/Y and Angle/Distance are bidirectionally synchronized in real-time).* |
| **Shadow Color / Alpha** | ColorPicker with alpha channel support (default: `rgba(0, 0, 0, 0.45)`). |
| **Shadow Scale** | Uniform scaling multiplier (e.g. `0.9` for perspective height, `1.0` for 1:1 footprint). |
| **Realtime Rotation Sync** | Attaches `RealtimeShadow2D`. When the parent body or stage rotates, the shadow offset dynamically counter-rotates in real-time, preserving world light direction while matching silhouette orientation. |

> [!TIP]
> **Direct Viewport Repositioning**: Developers can click the generated `Sprite2DShadow` node directly in the Godot 2D Viewport and move it with the Move Tool (**`W`**). The tool automatically recalculates and saves the new world offset without snapping back.

---

### 5. Workflow Options

- **Create StaticBody2D**: Wraps generated nodes under a new `StaticBody2D`. If unchecked, attaches collision nodes directly to the target.
- **Keep Main Sprite**: Retains and parents the primary visual `Sprite2D` under the body.
- **Auto-Generate Collision**: Automatically computes contours upon pressing Create.

---

### 6. Action Buttons & Feedback

- **🔨 Create StaticBody**: Executes the creation pipeline with full Undo/Redo registration.
- **🔄 Regenerate Collision**: Updates collision polygons and shadow parameters on an existing body without disturbing its transform, scripts, or scene hierarchy.
- **👁️ Live Preview (Toggle)**: Draws semi-transparent green polygons, yellow vertex points, and shadow contours directly on the editor viewport canvas.
- **🗑️ Remove Collision**: Cleanly strips all `CollisionPolygon2D` children from the target body.
- **Status Bar**: Real-time diagnostic readouts showing generated polygon count, vertex count, and operation status.

---

## 🔬 Technical Architecture & Math

```
[ Sprite2D Texture ]
        │
        ▼
[ BitMap Extraction ] ──── (Alpha Threshold Evaluation)
        │
        ▼
[ Contour Tracing ] ────── (Marching Squares / Opaque Boundary)
        │
        ▼
[ RDP Simplification ] ─── (Epsilon Tolerance & Max Points Budget)
        │
        ▼
[ Ear-Clipping / Convex ]─ (Single Poly OR Convex Decomposition)
        │
        ├─────────────────────────────┬─────────────────────────────┐
        ▼                             ▼                             ▼
[ CollisionPolygon2D Nodes ]   [ Sprite2D (Main) ]   [ RealtimeShadow2D Node ]
```

### Counter-Rotation Math (`RealtimeShadow2D`)
In top-down or side-scrolling games, a global light source (e.g. sun from the top-left) remains fixed relative to the screen. When an object rotates by angle $\theta$, rigid children rotate with it:

$$\vec{v}_{\text{rigid}} = \mathbf{R}(\theta) \cdot \vec{v}_{\text{offset}}$$

To keep the shadow's world displacement constant, `RealtimeShadow2D` calculates the parent's global transformation matrix $\mathbf{T}_{\text{parent}}$ and applies affine inversion in `_process` and `_physics_process`:

$$\vec{p}_{\text{local}} = \mathbf{T}_{\text{parent}}^{-1} \cdot (\vec{p}_{\text{world\_origin}} + \vec{v}_{\text{shadow\_offset}})$$

**Result**:
- $\text{Global Rotation}$: Matches the parent, rotating the shadow silhouette with the object.
- $\text{Global Displacement}$: Strictly preserved at $\vec{v}_{\text{shadow\_offset}}$, ensuring lighting stays completely natural.

---

## 📦 File Structure

```
addons/sprite_staticbody_builder/
├── plugin.cfg                  # Plugin metadata and entry script declaration
├── sprite_staticbody_plugin.gd # EditorPlugin lifecycle, Undo/Redo & Viewport overlays
├── sprite_staticbody_dock.gd   # Dock UI logic, signal dispatching & target sync
├── sprite_staticbody_dock.tscn # Clean Godot 4 Control scene for the dock UI
├── collision_generator.gd      # Bitmap tracing & ear-clipping decomposition
├── polygon_simplifier.gd       # Ramer-Douglas-Peucker (RDP) algorithm
├── collision_preview.gd        # Viewport canvas overlay renderer
└── resources/
    ├── realtime_shadow.gd      # RealtimeShadow2D tool script
    ├── rotating_obstacle.gd    # Continuous rotation archetype script
    ├── hazard_area.gd          # Hazard trigger script
    └── goal_area.gd            # Level exit trigger script
```

---

## 🛠️ Installation & Setup

1. Copy the `addons/sprite_staticbody_builder` folder into your Godot 4 project's `res://addons/` directory.
2. In the Godot editor, navigate to **Project → Project Settings → Plugins**.
3. Locate **Sprite StaticBody Builder** and check the **Enable** box.
4. The dock will appear in your editor panels ready for use.

---

## 📄 License & Attribution
- **Author**: Rohan Choudhary
- **License**: MIT License

This project is open-source software licensed under the **MIT License** (see [LICENSE](LICENSE)). Feel free to use, modify, and integrate it into commercial and personal games.
