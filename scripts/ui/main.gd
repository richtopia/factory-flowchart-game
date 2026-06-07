## Main — Main game control script that ties the UI panels to the SimulationEngine.
##
## Manages play/pause state, simulation speed, map selection, and triggers periodic
## UI refreshes to pull metrics from the background threads.
class_name MainControlClass
extends Control

# UI Node references
@onready var flowchart_editor: FlowchartEditor = $VBoxContainer/FlowchartEditor
@onready var map_selector: OptionButton = $VBoxContainer/MenuBar/MapSelector
@onready var play_button: Button = $VBoxContainer/MenuBar/PlayButton
@onready var speed_slider: HSlider = $VBoxContainer/MenuBar/HBoxContainer/SpeedSlider
@onready var speed_label: Label = $VBoxContainer/MenuBar/HBoxContainer/SpeedLabel
@onready var status_label: Label = $VBoxContainer/MenuBar/StatusLabel

# UI refresh timer (ticks independently to keep UI labels responsive)
@onready var ui_timer: Timer = $UITimer

var is_playing: bool = false
var current_map_id: String = ""


func _ready() -> void:
	# 1. Initialize simulation engine if autoload didn't start it
	var sim_engine: SimulationEngineClass = Engine.get_meta("SimulationEngine")
	if not sim_engine:
		# Fallback if running standalone scene
		sim_engine = SimulationEngineClass.new()
		Engine.set_meta("SimulationEngine", sim_engine)
		add_child(sim_engine)

	# 2. Wait for DataManager autoload to complete loading TOML database
	if not DataManager.is_node_ready():
		await DataManager.ready
		
	# Populate map simulations with demo setups
	_initialize_simulations(sim_engine)
	
	# 3. Populate MapSelector dropdown
	map_selector.clear()
	var idx := 0
	for map_id: String in DataManager.maps:
		var map_data: MapData = DataManager.maps[map_id]
		map_selector.add_item(map_data.name, idx)
		map_selector.set_item_metadata(idx, map_id)
		if idx == 0:
			current_map_id = map_id
		idx += 1
		
	map_selector.connect("item_selected", _on_map_selected)
	play_button.connect("pressed", _on_play_pressed)
	speed_slider.connect("value_changed", _on_speed_changed)
	
	# 4. Load the default map
	if not current_map_id.is_empty():
		flowchart_editor.load_map(current_map_id)
		
	# 5. Start the independent UI refresh timer
	ui_timer.connect("timeout", _on_ui_timer_timeout)
	ui_timer.start(0.1) # Update UI at 10 Hz for smooth redraws
	
	_update_play_button_ui()
	_update_status_bar()


# Sets up the simulations and pre-populates a working demo flowchart
# to demonstrate rate balancing, starvation, and cross-map transfers.
func _initialize_simulations(sim_engine: SimulationEngineClass) -> void:
	# Clear any old runs
	sim_engine.clear_all()
	
	for map_id: String in DataManager.maps:
		var map_data: MapData = DataManager.maps[map_id]
		var sim := MapSimulation.new(map_data)
		sim_engine.register_map_simulation(map_id, sim)
		
		# Build a default working demo graph on the default map
		if map_id == "aluminum_valley":
			_create_demo_aluminum_chain(sim)
		elif map_id == "chemical_plant":
			_create_demo_chemical_plant(sim)


# Creates a default working aluminum production chain.
func _create_demo_aluminum_chain(sim: MapSimulation) -> void:
	# Fetch configurations from DataManager
	var mine_data: ToolData = DataManager.tools.get("bauxite_mine")
	var refinery_data: ToolData = DataManager.tools.get("refinery")
	var smelter_data: ToolData = DataManager.tools.get("smelter")
	var extruder_data: ToolData = DataManager.tools.get("extruder")
	
	var bauxite_mining_recipe: RecipeData = DataManager.recipes.get("bauxite_mining")
	var alumina_refining_recipe: RecipeData = DataManager.recipes.get("alumina_refining")
	var aluminum_smelting_recipe: RecipeData = DataManager.recipes.get("aluminum_smelting")
	var aluminum_extrusion_recipe: RecipeData = DataManager.recipes.get("aluminum_extrusion")
	
	var conveyor_path_data: PathData = DataManager.paths.get("conveyor")
	var power_line_path_data: PathData = DataManager.paths.get("power_line")
	var pipeline_path_data: PathData = DataManager.paths.get("pipeline")
	
	if not mine_data or not refinery_data or not smelter_data or not extruder_data:
		return
	if not bauxite_mining_recipe or not alumina_refining_recipe or not aluminum_smelting_recipe or not aluminum_extrusion_recipe:
		return
	if not conveyor_path_data or not power_line_path_data or not pipeline_path_data:
		return
		
	# 1. Power substation (Importer importing electricity from map "grid")
	var power_substation := RuntimeTool.new("power_substation", mine_data)
	power_substation.configure_as_importer("grid", "electricity")
	power_substation.import_available_rate = 30.0  # MW
	sim.add_tool(power_substation)
	
	# 2. Water pump (Importer importing water from map "lake")
	var water_pump := RuntimeTool.new("water_pump", mine_data)
	water_pump.configure_as_importer("lake", "water")
	water_pump.import_available_rate = 10.0 # ton/hour
	sim.add_tool(water_pump)
	
	# 3. Bauxite Mine
	var mine_1 := RuntimeTool.new("mine_1", mine_data)
	mine_1.set_recipe(bauxite_mining_recipe)
	sim.add_tool(mine_1)
	
	# 4. Alumina Refinery
	var refinery_1 := RuntimeTool.new("refinery_1", refinery_data)
	refinery_1.set_recipe(alumina_refining_recipe)
	sim.add_tool(refinery_1)
	
	# 5. Aluminum Smelter
	var smelter_1 := RuntimeTool.new("smelter_1", smelter_data)
	smelter_1.set_recipe(aluminum_smelting_recipe)
	sim.add_tool(smelter_1)
	
	# 6. Aluminum Extruder
	var extruder_1 := RuntimeTool.new("extruder_1", extruder_data)
	extruder_1.set_recipe(aluminum_extrusion_recipe)
	sim.add_tool(extruder_1)
	
	# 7. Bar Exporter (sends extruded_bar to "aluminum_valley_sub" map)
	var bar_exporter := RuntimeTool.new("bar_exporter", mine_data)
	bar_exporter.configure_as_exporter("aluminum_valley_sub", "extruded_bar")
	sim.add_tool(bar_exporter)
	
	# Connect paths
	var p1 := RuntimePath.new("path_p1", power_line_path_data, power_substation, 0, mine_1, 0)
	sim.add_path(p1)
	
	var p2 := RuntimePath.new("path_p2", power_line_path_data, power_substation, 0, smelter_1, 1)
	sim.add_path(p2)
	
	var p3 := RuntimePath.new("path_p3", pipeline_path_data, water_pump, 0, refinery_1, 1)
	sim.add_path(p3)
	
	var p4 := RuntimePath.new("path_p4", conveyor_path_data, mine_1, 0, refinery_1, 0)
	sim.add_path(p4)
	
	var p5 := RuntimePath.new("path_p5", conveyor_path_data, refinery_1, 0, smelter_1, 0)
	sim.add_path(p5)
	
	var p6 := RuntimePath.new("path_p6", pipeline_path_data, smelter_1, 0, extruder_1, 0)
	sim.add_path(p6)
	
	var p7 := RuntimePath.new("path_p7", conveyor_path_data, extruder_1, 0, bar_exporter, 0)
	sim.add_path(p7)


# Creates a default working methane steam reforming plant.
func _create_demo_chemical_plant(sim: MapSimulation) -> void:
	# Fetch configurations from DataManager
	var reactor_data: ToolData = DataManager.tools.get("reactor")
	var steam_reforming_recipe: RecipeData = DataManager.recipes.get("steam_reforming")
	var pipeline_path_data: PathData = DataManager.paths.get("pipeline")
	
	if not reactor_data or not steam_reforming_recipe or not pipeline_path_data:
		return
		
	# 1. Methane source (Importer importing ch4 from map "reservoir")
	var methane_well := RuntimeTool.new("methane_well", reactor_data)
	methane_well.configure_as_importer("reservoir", "ch4")
	methane_well.import_available_rate = 3.0  # ton/hour
	sim.add_tool(methane_well)
	
	# 2. Water source (Importer importing water from map "lake")
	var water_pump := RuntimeTool.new("water_pump", reactor_data)
	water_pump.configure_as_importer("lake", "water")
	water_pump.import_available_rate = 10.0 # ton/hour
	sim.add_tool(water_pump)
	
	# 3. Chemical Reactor (standard machine with steam reforming selected)
	var reactor_1 := RuntimeTool.new("reactor_1", reactor_data)
	reactor_1.set_recipe(steam_reforming_recipe)
	sim.add_tool(reactor_1)
	
	# 4. Hydrogen Exporter (sends h2 to "aluminum_valley_sub" map)
	var h2_exporter := RuntimeTool.new("h2_exporter", reactor_data)
	h2_exporter.configure_as_exporter("aluminum_valley_sub", "h2")
	sim.add_tool(h2_exporter)
	
	# 5. Connect paths
	# Path 1: Methane Well -> Reactor Methane input (port 0)
	var path_ch4 := RuntimePath.new("path_ch4", pipeline_path_data, methane_well, 0, reactor_1, 0)
	sim.add_path(path_ch4)
	
	# Path 2: Water Pump -> Reactor Water input (port 1)
	var path_water := RuntimePath.new("path_water", pipeline_path_data, water_pump, 0, reactor_1, 1)
	sim.add_path(path_water)
	
	# Path 3: Reactor Hydrogen output (port 0) -> Exporter
	var path_h2 := RuntimePath.new("path_h2", pipeline_path_data, reactor_1, 0, h2_exporter, 0)
	sim.add_path(path_h2)


func _on_map_selected(idx: int) -> void:
	var map_id: String = map_selector.get_item_metadata(idx)
	if map_id == current_map_id:
		return
		
	current_map_id = map_id
	flowchart_editor.load_map(current_map_id)
	_update_status_bar()


func _on_play_pressed() -> void:
	var sim_engine: SimulationEngineClass = Engine.get_meta("SimulationEngine")
	if not sim_engine:
		return
		
	is_playing = not is_playing
	if is_playing:
		sim_engine.start_simulation(speed_slider.value)
	else:
		sim_engine.stop_simulation()
		
	_update_play_button_ui()
	_update_status_bar()


func _on_speed_changed(val: float) -> void:
	speed_label.text = "Speed: %.1fx" % val
	
	if is_playing:
		var sim_engine: SimulationEngineClass = Engine.get_meta("SimulationEngine")
		if sim_engine:
			# Re-apply updated frequency to active thread loops
			sim_engine.start_simulation(val)


func _on_ui_timer_timeout() -> void:
	# Redraw line flows and update port throughput labels
	flowchart_editor.update_ui()


func _update_play_button_ui() -> void:
	if is_playing:
		play_button.text = "Pause"
	else:
		play_button.text = "Play"


func _update_status_bar() -> void:
	if is_playing:
		status_label.text = "Simulation: RUNNING (Map: %s)" % current_map_id
		status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		status_label.text = "Simulation: PAUSED (Map: %s)" % current_map_id
		status_label.add_theme_color_override("font_color", Color.YELLOW)
