## Unit tests for the SimulationEngine, MapSimulation, and FlowSolver classes.
extends GutTest

var engine: SimulationEngineClass = null


func before_each() -> void:
	# Remove any existing autoload meta reference to avoid cross-test contamination
	if Engine.has_meta("SimulationEngine"):
		Engine.remove_meta("SimulationEngine")
	
	# Instantiate SimulationEngine manually for isolation
	engine = SimulationEngineClass.new()
	Engine.set_meta("SimulationEngine", engine)


func after_each() -> void:
	if engine:
		engine.clear_all()
		engine.free()
	if Engine.has_meta("SimulationEngine"):
		Engine.remove_meta("SimulationEngine")


# ─────────────────────────────────────────────────────────────────────────────
# Helper Methods
# ─────────────────────────────────────────────────────────────────────────────

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


func create_mock_path_data(path_id: String, ingredients: Array[String]) -> PathData:
	var p := PathData.new()
	p.id = path_id
	p.name = path_id.capitalize()
	p.allowed_ingredients = ingredients
	p.visual_style = "solid"
	return p


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

func test_simple_rate_balancing() -> void:
	var map_data := create_mock_map_data("map_1")
	var sim := MapSimulation.new(map_data)
	engine.register_map_simulation("map_1", sim)
	
	# Set up a mine that outputs 10.0 ore, and a smelter that consumes 10.0 ore to output 10.0 bar
	var mine_recipe := create_mock_recipe("mine_ore", [], [["ore", 10.0]])
	var smelter_recipe := create_mock_recipe("smelt_ore", [["ore", 10.0]], [["bar", 10.0]])
	
	var mine_tool_data := create_mock_tool_data("mine", ["mine_ore"])
	var smelter_tool_data := create_mock_tool_data("smelter", ["smelt_ore"])
	
	var r_mine := RuntimeTool.new("mine_1", mine_tool_data)
	r_mine.set_recipe(mine_recipe)
	
	var r_smelter := RuntimeTool.new("smelter_1", smelter_tool_data)
	r_smelter.set_recipe(smelter_recipe)
	
	# Path from mine output 0 to smelter input 0
	var path_data := create_mock_path_data("conveyor", ["ore"])
	var path := RuntimePath.new("path_1", path_data, r_mine, 0, r_smelter, 0)
	
	sim.add_tool(r_mine)
	sim.add_tool(r_smelter)
	sim.add_path(path)
	
	# Execute simulation tick
	sim.tick()
	
	# Mine should run at 100% capacity (1.0) and output 10.0 ore
	assert_almost_eq(r_mine.operating_rate, 1.0, 0.001)
	assert_almost_eq(r_mine.output_port_flows[0], 10.0, 0.001)
	
	# Path should carry 10.0 ore
	assert_almost_eq(path.flow_rate, 10.0, 0.001)
	assert_eq(path.carried_ingredient_id, "ore")
	
	# Smelter gets 10.0 ore, runs at 100% capacity (1.0), and outputs 10.0 bar
	assert_almost_eq(r_smelter.operating_rate, 1.0, 0.001)
	assert_almost_eq(r_smelter.output_port_flows[0], 10.0, 0.001)


func test_input_starvation() -> void:
	var map_data := create_mock_map_data("map_1")
	var sim := MapSimulation.new(map_data)
	engine.register_map_simulation("map_1", sim)
	
	# Mine outputs only 2.0 ore. Smelter needs 5.0 ore.
	var mine_recipe := create_mock_recipe("mine_ore", [], [["ore", 2.0]])
	var smelter_recipe := create_mock_recipe("smelt_ore", [["ore", 5.0]], [["bar", 5.0]])
	
	var mine_tool_data := create_mock_tool_data("mine", ["mine_ore"])
	var smelter_tool_data := create_mock_tool_data("smelter", ["smelt_ore"])
	
	var r_mine := RuntimeTool.new("mine_1", mine_tool_data)
	r_mine.set_recipe(mine_recipe)
	
	var r_smelter := RuntimeTool.new("smelter_1", smelter_tool_data)
	r_smelter.set_recipe(smelter_recipe)
	
	var path_data := create_mock_path_data("conveyor", ["ore"])
	var path := RuntimePath.new("path_1", path_data, r_mine, 0, r_smelter, 0)
	
	sim.add_tool(r_mine)
	sim.add_tool(r_smelter)
	sim.add_path(path)
	
	sim.tick()
	
	# Mine outputs 2.0
	assert_almost_eq(r_mine.operating_rate, 1.0, 0.001)
	assert_almost_eq(path.flow_rate, 2.0, 0.001)
	
	# Smelter is starved: gets 2.0 but needs 5.0. Should run at 40% capacity (0.4)
	assert_almost_eq(r_smelter.operating_rate, 0.4, 0.001)
	assert_almost_eq(r_smelter.output_port_flows[0], 2.0, 0.001)


func test_backpressure_throttling() -> void:
	var map_data := create_mock_map_data("map_1")
	var sim := MapSimulation.new(map_data)
	engine.register_map_simulation("map_1", sim)
	
	# Mine outputs 10.0 ore. Smelter is stopped (no recipe set).
	var mine_recipe := create_mock_recipe("mine_ore", [], [["ore", 10.0]])
	
	var mine_tool_data := create_mock_tool_data("mine", ["mine_ore"])
	var smelter_tool_data := create_mock_tool_data("smelter", [])
	
	var r_mine := RuntimeTool.new("mine_1", mine_tool_data)
	r_mine.set_recipe(mine_recipe)
	
	var r_smelter := RuntimeTool.new("smelter_1", smelter_tool_data)
	
	var path_data := create_mock_path_data("conveyor", ["ore"])
	var path := RuntimePath.new("path_1", path_data, r_mine, 0, r_smelter, 0)
	
	sim.add_tool(r_mine)
	sim.add_tool(r_smelter)
	sim.add_path(path)
	
	sim.tick()
	
	# Smelter is stopped (runs at 0.0). Backpressure should propagate back through path
	# and throttle the Mine down to 0.0 capacity.
	assert_almost_eq(r_smelter.operating_rate, 0.0, 0.001)
	assert_almost_eq(r_mine.operating_rate, 0.0, 0.001)
	assert_almost_eq(path.flow_rate, 0.0, 0.001)


func test_cross_map_transfers() -> void:
	# Map A (Source Map)
	var map_a_data := create_mock_map_data("map_a")
	var sim_a := MapSimulation.new(map_a_data)
	engine.register_map_simulation("map_a", sim_a)
	
	# Mine -> Exporter
	var mine_recipe := create_mock_recipe("mine_h2", [], [["h2", 5.0]])
	var mine_tool_data := create_mock_tool_data("mine", ["mine_h2"])
	var r_mine := RuntimeTool.new("mine_1", mine_tool_data)
	r_mine.set_recipe(mine_recipe)
	
	var exporter_tool_data := create_mock_tool_data("exporter", [])
	var r_exporter := RuntimeTool.new("exporter_1", exporter_tool_data)
	r_exporter.configure_as_exporter("map_b", "h2")
	
	var path_data := create_mock_path_data("pipeline", ["h2"])
	var path_a := RuntimePath.new("path_a", path_data, r_mine, 0, r_exporter, 0)
	
	sim_a.add_tool(r_mine)
	sim_a.add_tool(r_exporter)
	sim_a.add_path(path_a)
	
	# Map B (Target Map)
	var map_b_data := create_mock_map_data("map_b")
	var sim_b := MapSimulation.new(map_b_data)
	engine.register_map_simulation("map_b", sim_b)
	
	# Importer -> Consumer (requires 10.0 h2)
	var importer_tool_data := create_mock_tool_data("importer", [])
	var r_importer := RuntimeTool.new("importer_1", importer_tool_data)
	r_importer.configure_as_importer("map_a", "h2")
	
	var consumer_recipe := create_mock_recipe("consume_h2", [["h2", 10.0]], [["bar", 10.0]])
	var consumer_tool_data := create_mock_tool_data("consumer", ["consume_h2"])
	var r_consumer := RuntimeTool.new("consumer_1", consumer_tool_data)
	r_consumer.set_recipe(consumer_recipe)
	
	var path_b := RuntimePath.new("path_b", path_data, r_importer, 0, r_consumer, 0)
	
	sim_b.add_tool(r_importer)
	sim_b.add_tool(r_consumer)
	sim_b.add_path(path_b)
	
	# 1. Tick Map A
	sim_a.tick()
	assert_almost_eq(r_mine.operating_rate, 1.0, 0.001)
	assert_almost_eq(path_a.flow_rate, 5.0, 0.001)
	assert_almost_eq(r_exporter.input_port_flows[0], 5.0, 0.001)
	
	# Check registry in SimulationEngine
	var broker_rate := engine.consume_cross_map("map_b", "h2")
	assert_almost_eq(broker_rate, 5.0, 0.001)
	
	# 2. Tick Map B
	sim_b.tick()
	
	# Importer should supply 5.0. Consumer needs 10.0. Consumer runs at 50% (0.5)
	assert_almost_eq(r_importer.output_port_flows[0], 5.0, 0.001)
	assert_almost_eq(path_b.flow_rate, 5.0, 0.001)
	assert_almost_eq(r_consumer.operating_rate, 0.5, 0.001)


func test_multithreading() -> void:
	var map_data := create_mock_map_data("map_1")
	var sim := MapSimulation.new(map_data)
	engine.register_map_simulation("map_1", sim)
	
	# Start thread at high speed
	sim.start(100.0)
	
	OS.delay_msec(15) # Wait briefly
	assert_true(sim._running, "Thread should be marked as running")
	
	sim.stop()
	assert_false(sim._running, "Thread should be stopped")
