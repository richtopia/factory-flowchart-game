extends GutTest

var engine: SimulationEngineClass = null

func before_each() -> void:
	if Engine.has_meta("SimulationEngine"):
		Engine.remove_meta("SimulationEngine")
	
	engine = SimulationEngineClass.new()
	Engine.set_meta("SimulationEngine", engine)
	
	# Wait for DataManager autoload to be fully ready
	if not DataManager.is_node_ready():
		await DataManager.ready

func after_each() -> void:
	if engine:
		engine.clear_all()
		engine.free()
	if Engine.has_meta("SimulationEngine"):
		Engine.remove_meta("SimulationEngine")

func test_aluminum_data_loaded() -> void:
	# Verify all new elements are loaded
	assert_true(DataManager.ingredients.has("bauxite"), "Bauxite loaded")
	assert_true(DataManager.ingredients.has("alumina"), "Alumina loaded")
	assert_true(DataManager.ingredients.has("molten_aluminum"), "Molten Aluminum loaded")
	assert_true(DataManager.ingredients.has("extruded_bar"), "Extruded Bar loaded")
	assert_true(DataManager.ingredients.has("electricity"), "Electricity loaded")
	
	assert_true(DataManager.paths.has("conveyor"), "Conveyor loaded")
	assert_true(DataManager.paths.has("power_line"), "Power Line loaded")
	
	assert_true(DataManager.recipes.has("bauxite_mining"), "Mining recipe loaded")
	assert_true(DataManager.recipes.has("alumina_refining"), "Refining recipe loaded")
	assert_true(DataManager.recipes.has("aluminum_smelting"), "Smelting recipe loaded")
	assert_true(DataManager.recipes.has("aluminum_extrusion"), "Extrusion recipe loaded")
	
	assert_true(DataManager.tools.has("bauxite_mine"), "Mine tool loaded")
	assert_true(DataManager.tools.has("refinery"), "Refinery tool loaded")
	assert_true(DataManager.tools.has("smelter"), "Smelter tool loaded")
	assert_true(DataManager.tools.has("extruder"), "Extruder tool loaded")

func test_aluminum_simulation_full_throughput() -> void:
	# Set up a simulation map
	var map_data = DataManager.maps.get("aluminum_valley")
	var sim = MapSimulation.new(map_data)
	engine.register_map_simulation("aluminum_valley", sim)
	
	var mine_data = DataManager.tools.get("bauxite_mine")
	var refinery_data = DataManager.tools.get("refinery")
	var smelter_data = DataManager.tools.get("smelter")
	var extruder_data = DataManager.tools.get("extruder")
	
	var bauxite_mining = DataManager.recipes.get("bauxite_mining")
	var alumina_refining = DataManager.recipes.get("alumina_refining")
	var aluminum_smelting = DataManager.recipes.get("aluminum_smelting")
	var aluminum_extrusion = DataManager.recipes.get("aluminum_extrusion")
	
	var conveyor = DataManager.paths.get("conveyor")
	var power_line = DataManager.paths.get("power_line")
	var pipeline = DataManager.paths.get("pipeline")
	
	# Importers / Exporters / Machines
	var power_substation = RuntimeTool.new("power_substation", mine_data)
	power_substation.configure_as_importer("grid", "electricity")
	sim.add_tool(power_substation)
	
	var water_pump = RuntimeTool.new("water_pump", mine_data)
	water_pump.configure_as_importer("lake", "water")
	sim.add_tool(water_pump)
	
	var mine_1 = RuntimeTool.new("mine_1", mine_data)
	mine_1.set_recipe(bauxite_mining)
	sim.add_tool(mine_1)
	
	var refinery_1 = RuntimeTool.new("refinery_1", refinery_data)
	refinery_1.set_recipe(alumina_refining)
	sim.add_tool(refinery_1)
	
	var smelter_1 = RuntimeTool.new("smelter_1", smelter_data)
	smelter_1.set_recipe(aluminum_smelting)
	sim.add_tool(smelter_1)
	
	var extruder_1 = RuntimeTool.new("extruder_1", extruder_data)
	extruder_1.set_recipe(aluminum_extrusion)
	sim.add_tool(extruder_1)
	
	var bar_exporter = RuntimeTool.new("bar_exporter", mine_data)
	bar_exporter.configure_as_exporter("aluminum_valley_sub", "extruded_bar")
	sim.add_tool(bar_exporter)
	
	# Connect them
	sim.add_path(RuntimePath.new("p1", power_line, power_substation, 0, mine_1, 0))
	sim.add_path(RuntimePath.new("p2", power_line, power_substation, 0, smelter_1, 1))
	sim.add_path(RuntimePath.new("p3", pipeline, water_pump, 0, refinery_1, 1))
	sim.add_path(RuntimePath.new("p4", conveyor, mine_1, 0, refinery_1, 0))
	sim.add_path(RuntimePath.new("p5", conveyor, refinery_1, 0, smelter_1, 0))
	sim.add_path(RuntimePath.new("p6", pipeline, smelter_1, 0, extruder_1, 0))
	sim.add_path(RuntimePath.new("p7", conveyor, extruder_1, 0, bar_exporter, 0))
	
	# Seed the cross-map imports in SimulationEngine before tick
	engine.transfer_cross_map("aluminum_valley", "grid_feed", "electricity", 50.0) # MW
	engine.transfer_cross_map("aluminum_valley", "lake_feed", "water", 10.0)       # ton/h
	
	# Run one solver tick
	sim.tick()
	
	# Under full supply, let's see operating rates:
	# Power = 50.0 MW.
	# Mine needs 1.0 MW -> produces 12.0 ton/h bauxite. Mine runs at 100%.
	# Refinery needs 6.0 ton/h bauxite, 3.0 ton/h water. Mine supplies 12.0. Water supplies 10.0. Refinery runs at 100% -> produces 3.0 ton/h alumina.
	# Smelter needs 4.0 ton/h alumina, 20.0 MW power. Refinery only supplies 3.0 alumina. So Smelter is starved of alumina (3.0 / 4.0 = 75%).
	# Extruder needs 2.0 ton/h molten aluminum. Smelter supplies 1.5. So Extruder is starved (1.5 / 2.0 = 75%).
	assert_almost_eq(mine_1.operating_rate, 0.5, 0.01, "Mine operates at 50% capacity due to refinery backpressure")
	assert_almost_eq(refinery_1.operating_rate, 1.0, 0.01, "Refinery operates at 100% capacity")
	assert_almost_eq(smelter_1.operating_rate, 0.75, 0.01, "Smelter throttled to 75% due to alumina starvation")
	assert_almost_eq(extruder_1.operating_rate, 0.75, 0.01, "Extruder throttled to 75% due to molten aluminum starvation")

func test_aluminum_simulation_power_starvation() -> void:
	var map_data = DataManager.maps.get("aluminum_valley")
	var sim = MapSimulation.new(map_data)
	engine.register_map_simulation("aluminum_valley", sim)
	
	var mine_data = DataManager.tools.get("bauxite_mine")
	var refinery_data = DataManager.tools.get("refinery")
	var smelter_data = DataManager.tools.get("smelter")
	var extruder_data = DataManager.tools.get("extruder")
	
	var bauxite_mining = DataManager.recipes.get("bauxite_mining")
	var alumina_refining = DataManager.recipes.get("alumina_refining")
	var aluminum_smelting = DataManager.recipes.get("aluminum_smelting")
	var aluminum_extrusion = DataManager.recipes.get("aluminum_extrusion")
	
	var conveyor = DataManager.paths.get("conveyor")
	var power_line = DataManager.paths.get("power_line")
	var pipeline = DataManager.paths.get("pipeline")
	
	# Importers / Exporters / Machines
	var power_substation = RuntimeTool.new("power_substation", mine_data)
	power_substation.configure_as_importer("grid", "electricity")
	sim.add_tool(power_substation)
	
	var water_pump = RuntimeTool.new("water_pump", mine_data)
	water_pump.configure_as_importer("lake", "water")
	sim.add_tool(water_pump)
	
	var mine_1 = RuntimeTool.new("mine_1", mine_data)
	mine_1.set_recipe(bauxite_mining)
	sim.add_tool(mine_1)
	
	var refinery_1 = RuntimeTool.new("refinery_1", refinery_data)
	refinery_1.set_recipe(alumina_refining)
	sim.add_tool(refinery_1)
	
	var smelter_1 = RuntimeTool.new("smelter_1", smelter_data)
	smelter_1.set_recipe(aluminum_smelting)
	sim.add_tool(smelter_1)
	
	var extruder_1 = RuntimeTool.new("extruder_1", extruder_data)
	extruder_1.set_recipe(aluminum_extrusion)
	sim.add_tool(extruder_1)
	
	var bar_exporter = RuntimeTool.new("bar_exporter", mine_data)
	bar_exporter.configure_as_exporter("aluminum_valley_sub", "extruded_bar")
	sim.add_tool(bar_exporter)
	
	# Connect them
	sim.add_path(RuntimePath.new("p1", power_line, power_substation, 0, mine_1, 0))
	sim.add_path(RuntimePath.new("p2", power_line, power_substation, 0, smelter_1, 1))
	sim.add_path(RuntimePath.new("p3", pipeline, water_pump, 0, refinery_1, 1))
	sim.add_path(RuntimePath.new("p4", conveyor, mine_1, 0, refinery_1, 0))
	sim.add_path(RuntimePath.new("p5", conveyor, refinery_1, 0, smelter_1, 0))
	sim.add_path(RuntimePath.new("p6", pipeline, smelter_1, 0, extruder_1, 0))
	sim.add_path(RuntimePath.new("p7", conveyor, extruder_1, 0, bar_exporter, 0))
	
	# Seed 10.0 MW of electricity in SimulationEngine
	engine.transfer_cross_map("aluminum_valley", "grid_feed", "electricity", 10.0) # MW
	engine.transfer_cross_map("aluminum_valley", "lake_feed", "water", 10.0)       # ton/h
	
	# Run one solver tick
	sim.tick()
	
	# Total electricity is 10.0 MW. Demand is 1.0 MW (mine) + 20.0 MW (smelter) = 21.0 MW.
	# Mine gets 10.0 * (1 / 21) = 0.476 MW -> operates at 47.6%.
	# Smelter gets 10.0 * (20 / 21) = 9.52 MW -> operates at 9.52 / 20 = 47.6%.
	assert_almost_eq(mine_1.operating_rate, 0.317, 0.02, "Mine starved of electricity and throttled by backpressure")
	assert_almost_eq(refinery_1.operating_rate, 0.635, 0.02, "Refinery backpressured by electricity-starved smelter")
	assert_almost_eq(smelter_1.operating_rate, 0.476, 0.02, "Smelter limited by electricity share")
	assert_almost_eq(extruder_1.operating_rate, 0.476, 0.02, "Extruder starved of molten aluminum")

func test_aluminum_simulation_backpressure() -> void:
	var map_data = DataManager.maps.get("aluminum_valley")
	var sim = MapSimulation.new(map_data)
	engine.register_map_simulation("aluminum_valley", sim)
	
	var mine_data = DataManager.tools.get("bauxite_mine")
	var refinery_data = DataManager.tools.get("refinery")
	var smelter_data = DataManager.tools.get("smelter")
	var extruder_data = DataManager.tools.get("extruder")
	
	var bauxite_mining = DataManager.recipes.get("bauxite_mining")
	var alumina_refining = DataManager.recipes.get("alumina_refining")
	var aluminum_smelting = DataManager.recipes.get("aluminum_smelting")
	
	var conveyor = DataManager.paths.get("conveyor")
	var power_line = DataManager.paths.get("power_line")
	var pipeline = DataManager.paths.get("pipeline")
	
	# Importers / Machines
	var power_substation = RuntimeTool.new("power_substation", mine_data)
	power_substation.configure_as_importer("grid", "electricity")
	sim.add_tool(power_substation)
	
	var water_pump = RuntimeTool.new("water_pump", mine_data)
	water_pump.configure_as_importer("lake", "water")
	sim.add_tool(water_pump)
	
	var mine_1 = RuntimeTool.new("mine_1", mine_data)
	mine_1.set_recipe(bauxite_mining)
	sim.add_tool(mine_1)
	
	var refinery_1 = RuntimeTool.new("refinery_1", refinery_data)
	refinery_1.set_recipe(alumina_refining)
	sim.add_tool(refinery_1)
	
	var smelter_1 = RuntimeTool.new("smelter_1", smelter_data)
	smelter_1.set_recipe(aluminum_smelting)
	sim.add_tool(smelter_1)
	
	# Extruder is stopped (recipe = null)
	var extruder_1 = RuntimeTool.new("extruder_1", extruder_data)
	extruder_1.set_recipe(null)
	sim.add_tool(extruder_1)
	
	# Connect paths
	sim.add_path(RuntimePath.new("p1", power_line, power_substation, 0, mine_1, 0))
	sim.add_path(RuntimePath.new("p2", power_line, power_substation, 0, smelter_1, 1))
	sim.add_path(RuntimePath.new("p3", pipeline, water_pump, 0, refinery_1, 1))
	sim.add_path(RuntimePath.new("p4", conveyor, mine_1, 0, refinery_1, 0))
	sim.add_path(RuntimePath.new("p5", conveyor, refinery_1, 0, smelter_1, 0))
	sim.add_path(RuntimePath.new("p6", pipeline, smelter_1, 0, extruder_1, 0))
	
	# Seed electricity and water in SimulationEngine
	engine.transfer_cross_map("aluminum_valley", "grid_feed", "electricity", 50.0)
	engine.transfer_cross_map("aluminum_valley", "lake_feed", "water", 10.0)
	
	# Run one solver tick
	sim.tick()
	
	# Smelter backpressured by stopped extruder -> 0% capacity
	# Refinery backpressured by stopped smelter -> 0% capacity
	# Mine backpressured by stopped refinery -> 0% capacity
	assert_almost_eq(extruder_1.operating_rate, 0.0, 0.01, "Extruder runs at 0% (stopped)")
	assert_almost_eq(smelter_1.operating_rate, 0.0, 0.01, "Smelter throttled to 0% due to backpressure")
	assert_almost_eq(refinery_1.operating_rate, 0.0, 0.01, "Refinery throttled to 0% due to backpressure")
	assert_almost_eq(mine_1.operating_rate, 0.0, 0.01, "Mine throttled to 0% due to backpressure")
