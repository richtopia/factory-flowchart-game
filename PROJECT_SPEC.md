# Project Plan: 2D Factory Flowchart Simulation Engine
# Target Engine: Godot 4.x (GDScript)
# Core Infrastructure: Data-driven design via TOML parsing for complete moddability.

## 1. Core Thesis & Architecture
Develop a 2D data-driven factory simulation game where a simple flowchart serves as both the gameplay loop and the graphical user interface. 

To ensure clean project organization, follow a strict Model-View-Controller (MVC) architecture pattern:
- **Data Models:** Standard Godot `RefCounted` or `Resource` scripts that store simulation state.
- **Simulation Engine (Core):** A global autoload or standalone manager class that calculates discrete tick/rate math. It must be completely decoupled from the UI.
- **UI Render Layer (View):** Mandate the utilization of Godot 4's native `GraphEdit` node as the master workspace container, displaying child `GraphNode` UI elements.

---

## 2. Entity & TOML Schemas
All parameters must be externalized in TOML configurations. Use the following explicit data schemas when writing the parser backend. All physical quantities must rely exclusively on metric units.

### A. Ingredient (`/data/ingredients/`)
Defines the components tracked through production chains. Requires strict standardization of base quantities versus scaled display tracking.
```toml
id = "water"
name = "Water"
base_unit = "L"              # Pure metric base tracking unit (e.g., L, kg, J)
measurement_unit = "ton"     # Standard workflow scaling denominator (e.g., ton, MW)
icon_path = "res://assets/icons/water.png"

```

### B. Path (`/data/paths/`)

Defines connection types between tools.

```toml
id = "pipeline"
name = "Pipeline"
allowed_ingredients = ["water", "ch4", "h2", "co2"]
visual_style = "dense_dashed" # Direct layout draw properties mapping

```

### C. Recipe (`/data/recipes/`)

Defines chemical/mechanical transformations and baseline metric formulas.

```toml
id = "steam_reforming"
name = "Steam Reforming"
heat_required = 6.2 # in MW

[[inputs]]
ingredient_id = "ch4"
rate = 2.2 # tons/hour

[[inputs]]
ingredient_id = "water"
rate = 4.9 # tons/hour

[[outputs]]
ingredient_id = "h2"
rate = 1.1 # tons/hour

[[outputs]]
ingredient_id = "co2"
rate = 6.0 # tons/hour

```

### D. Tool (`/data/tools/`)

Defines structures routing, reading, and performing processes.

```toml
id = "reactor"
name = "Chemical Reactor"
width_m = 5.0
length_m = 3.0
allowed_recipes = ["steam_reforming"]
max_input_paths = 3
max_output_paths = 2

```

### E. Map (`/data/maps/`)

Defines layouts, sizing grids, and linkage parameters.

```toml
id = "aluminum_valley"
name = "Aluminum Production Valley"
width_m = 500
length_m = 200

# Advanced concept: Cross-Map tool pipeline linkage
[link]
is_linked_map = false
target_map_id = "" 

```

---

## 3. Implementation Milestones

Execute the development of this workspace sequentially. Present task-level plans and artifacts for review at the completion of each milestone.

### Milestone 1: TOML Parsers & Data Layers

* Create a pure GDScript utility to parse the TOML specifications for Ingredients, Paths, Recipes, Tools, and Maps into lightweight data classes.
* Ensure strict metric validation checks execute on application startup to handle mismatch configurations or unmapped unit IDs.

### Milestone 2: Simulation Loop Engine

* Build a processing framework tracking simulation tick logic completely decoupled from UI frame rates.
* Implement continuous rate balancing: a Tool processes its selected Recipe if and only if it receives its metric requirements via incoming linked Paths.
* Incorporate cross-map multi-threading infrastructure allowing excess outputs from Map A to be systematically registered into the supply pipeline arrays of Map B.

### Milestone 3: Flowchart Graph UI (GraphEdit & GraphNode)

* Bind the core UI workspace to a native Godot 4 `GraphEdit` control node.
* Realize active production elements by dynamically instantiating individual native `GraphNode` nodes inside the canvas.
* Leverage `GraphNode` native slot-and-port properties (mapping active ports directly via child control scripts) to structurally handle inputs (left-side ports) and outputs (right-side ports).
* Intercept `connection_request` and `disconnection_request` signals from the `GraphEdit` interface to actively validate, form, and discard data routing configurations inside the backend simulation loop.
* Use path definitions to drive connection rendering variants (e.g., dense dashed formatting for fluid pipelines, sparse dashed profiles for raw heat links).
* Display real-time throughput metrics via clear string label arrays (e.g., `[2.2 ton/hour]`) dynamically rendering over active ports.

### Milestone 4: Base Game Content (Aluminum Chain)

Create the baseline TOML database mapping the complete Aluminum production workflow:

1. **Bauxite Mine (Tool):** Outputs Bauxite Ore via Conveyor lines.
2. **Refinery (Tool):** Consumes Bauxite Ore + Additives via Pipeline → Outputs Alumina (Al₂O₃).
3. **Smelter (Tool):** Consumes Alumina + Electricity via High-Voltage Electrical lines (Hall-Héroult Process) → Outputs Molten Aluminum.
4. **Extruder (Tool):** Consumes Molten Aluminum → Outputs finished Extruded Bar Stock.
