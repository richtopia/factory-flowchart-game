## Unit tests for the flowchart UI elements (FlowchartEditor and ToolNode).
extends GutTest

var engine: SimulationEngineClass = null
var editor: FlowchartEditor = null


func before_each() -> void:
	if Engine.has_meta("SimulationEngine"):
		Engine.remove_meta("SimulationEngine")
		
	engine = SimulationEngineClass.new()
	Engine.set_meta("SimulationEngine", engine)
	
	# Instantiate editor
	editor = FlowchartEditor.new()
	add_child_autofree(editor)


func after_each() -> void:
	if engine:
		engine.clear_all()
		engine.free()
	if Engine.has_meta("SimulationEngine"):
		Engine.remove_meta("SimulationEngine")


# Helper to create mock objects
func create_mock_recipe(recipe_id: String, inputs: Array, outputs: Array) -> RecipeData:
	var r := RecipeData.new()
	r.id = recipe_id
	r.name = recipe_id.capitalize()
	r.heat_required = 0.0
	
	for inp: Array in inputs:
		var io := RecipeIO.new()
		io.ingredient_id = inp[0]
		io.rate = inp[1]
		r.inputs.append(io)
		
	for out: Array in outputs:
		var io := RecipeIO.new()
		io.ingredient_id = out[0]
		io.rate = out[1]
		r.outputs.append(io)
		
	return r


func create_mock_tool_data(tool_id: String, recipes: Array[String], max_in: int = 3, max_out: int = 3) -> ToolData:
	var t := ToolData.new()
	t.id = tool_id
	t.name = tool_id.capitalize()
	t.width_m = 5.0
	t.length_m = 5.0
	t.allowed_recipes = recipes
	t.max_input_paths = max_in
	t.max_output_paths = max_out
	return t


func create_mock_map_data(map_id: String) -> MapData:
	var m := MapData.new()
	m.id = map_id
	m.name = map_id.capitalize()
	m.width_m = 100.0
	m.length_m = 100.0
	return m


# ─────────────────────────────────────────────────────────────────────────────
# Test Cases
# ─────────────────────────────────────────────────────────────────────────────

func test_ingredient_port_type_mapping() -> void:
	# Port type mapping should assign consistent integer IDs based on the keys
	var type_1 = editor._get_ingredient_port_type("water")
	var type_2 = editor._get_ingredient_port_type("ch4")
	var type_3 = editor._get_ingredient_port_type("water")
	
	assert_true(type_1 > 0, "Water type code should be positive")
	assert_true(type_2 > 0, "Methane type code should be positive")
	assert_eq(type_1, type_3, "Identical ingredients must map to the same type integer")
	assert_ne(type_1, type_2, "Different ingredients must map to different type integers")


func test_tool_node_slot_creation() -> void:
	# Set up a tool node
	var recipe := create_mock_recipe("mine_ore", [], [["ore", 10.0]])
	var tool_data := create_mock_tool_data("mine", ["mine_ore"])
	var r_tool := RuntimeTool.new("mine_1", tool_data)
	r_tool.set_recipe(recipe)
	
	# Instantiate ToolNode
	var node: ToolNode = load("res://scenes/ui/tool_node.tscn").instantiate()
	add_child_autofree(node)
	
	node.setup_node(r_tool)
	
	# Output slot 0 should be enabled on the right, disabled on the left
	assert_false(node.is_slot_enabled_left(0), "Left side of slot 0 should be disabled")
	assert_true(node.is_slot_enabled_right(0), "Right side of slot 0 should be enabled")
	
	# Clean up node
	node.free()


func test_ui_connection_and_disconnection() -> void:
	# Set up map
	var map_data := create_mock_map_data("map_1")
	var sim := MapSimulation.new(map_data)
	engine.register_map_simulation("map_1", sim)
	editor.current_map_sim = sim
	
	# Setup tools
	var mine_recipe := create_mock_recipe("mine_ore", [], [["ore", 10.0]])
	var smelter_recipe := create_mock_recipe("smelt_ore", [["ore", 10.0]], [["bar", 10.0]])
	var mine_tool_data := create_mock_tool_data("mine", ["mine_ore"])
	var smelter_tool_data := create_mock_tool_data("smelter", ["smelt_ore"])
	
	var r_mine := RuntimeTool.new("mine_1", mine_tool_data)
	r_mine.set_recipe(mine_recipe)
	var r_smelter := RuntimeTool.new("smelter_1", smelter_tool_data)
	r_smelter.set_recipe(smelter_recipe)
	
	sim.add_tool(r_mine)
	sim.add_tool(r_smelter)
	
	# Create ToolNode UI elements and add to editor
	var mine_node: ToolNode = load("res://scenes/ui/tool_node.tscn").instantiate()
	mine_node.name = "mine_1"
	editor.add_child(mine_node)
	mine_node.setup_node(r_mine)
	
	var smelter_node: ToolNode = load("res://scenes/ui/tool_node.tscn").instantiate()
	smelter_node.name = "smelter_1"
	editor.add_child(smelter_node)
	smelter_node.setup_node(r_smelter)
	
	# 1. Trigger connection request
	editor.emit_signal("connection_request", "mine_1", 0, "smelter_1", 0)
	
	# Verify visual connection exists in GraphEdit
	var connection_list = editor.get_connection_list()
	assert_eq(connection_list.size(), 1, "GraphEdit connection list should contain 1 connection")
	
	# Verify backend RuntimePath exists in simulation
	assert_eq(sim.paths.size(), 1, "MapSimulation should have 1 active path")
	var path: RuntimePath = sim.paths.values()[0]
	assert_eq(path.source_tool.id, "mine_1")
	assert_eq(path.target_tool.id, "smelter_1")
	assert_eq(path.carried_ingredient_id, "ore")

	# 2. Trigger disconnection request
	editor.emit_signal("disconnection_request", "mine_1", 0, "smelter_1", 0)
	
	# Verify visual connection removed
	assert_eq(editor.get_connection_list().size(), 0, "GraphEdit connection list should be empty")
	
	# Verify backend path deleted
	assert_eq(sim.paths.size(), 0, "MapSimulation paths should be empty")
	
	# Free nodes
	mine_node.free()
	smelter_node.free()
