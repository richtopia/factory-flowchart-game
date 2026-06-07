## MapSimulation — Manages runtime tools and paths, and ticks the map's simulation.
##
## Can run asynchronously in a background thread or synchronously. Automatically
## synchronizes with the SimulationEngine for cross-map imports and exports.
class_name MapSimulation
extends RefCounted

## Configuration template for this map.
var map_data: MapData

## Active tools on this map: instance_id (String) -> RuntimeTool.
var tools: Dictionary = {}

## Active paths on this map: instance_id (String) -> RuntimePath.
var paths: Dictionary = {}

## The rate at which the thread loops (updates per second).
var tick_rate_hz: float = 1.0

# Threading state variables
var _thread: Thread = Thread.new()
var _running: bool = false
var _mutex: Mutex = Mutex.new()
var _sim_engine: Node = null


func _init(p_map_data: MapData) -> void:
	map_data = p_map_data


## Starts the background thread loop at the specified frequency (hertz).
func start(hz: float = 1.0) -> void:
	_mutex.lock()
	if _running:
		_mutex.unlock()
		return
	_running = true
	tick_rate_hz = hz
	# Cache the SimulationEngine coordinator on the main thread
	_sim_engine = _get_simulation_engine()
	_mutex.unlock()
	
	_thread.start(_thread_loop)


## Stops the background thread loop and waits for it to finish.
func stop() -> void:
	_mutex.lock()
	_running = false
	_mutex.unlock()
	
	if _thread.is_started():
		_thread.wait_to_finish()


# The loop executed inside the dedicated thread.
func _thread_loop() -> void:
	while true:
		_mutex.lock()
		var is_active := _running
		var hz := tick_rate_hz
		_mutex.unlock()
		
		if not is_active:
			break
			
		tick()
		
		var delay_ms := int(1000.0 / hz)
		if delay_ms > 0:
			OS.delay_msec(delay_ms)


## Runs a single simulation tick. Updates imports, resolves rates, and registers exports.
func tick() -> void:
	_mutex.lock()
	var sim_engine := _sim_engine
	if sim_engine == null:
		sim_engine = _get_simulation_engine()
		_sim_engine = sim_engine

	# 1. Fetch imports from the coordinator
	for tool: RuntimeTool in tools.values():
		if tool.is_importer:
			if sim_engine:
				tool.import_available_rate = sim_engine.consume_cross_map(map_data.id, tool.import_ingredient_id)

	# 2. Solve network rates
	FlowSolver.solve_rates(tools, paths)

	# 3. Send exports back to the coordinator
	for tool: RuntimeTool in tools.values():
		if tool.is_exporter:
			var export_rate: float = tool.input_port_flows.get(0, 0.0)
			if sim_engine:
				sim_engine.transfer_cross_map(tool.export_target_map, tool.id, tool.import_ingredient_id, export_rate)
				
	_mutex.unlock()


## Safely fetches the SimulationEngine autoload if registered in the SceneTree or Engine metadata.
func _get_simulation_engine() -> Node:
	if Engine.has_meta("SimulationEngine"):
		return Engine.get_meta("SimulationEngine") as Node
		
	var main_loop := Engine.get_main_loop()
	if main_loop and main_loop is SceneTree:
		var root := (main_loop as SceneTree).root
		if root.has_node("SimulationEngine"):
			return root.get_node("SimulationEngine")
	return null


## Adds an active tool instance to this simulation.
func add_tool(tool_instance: RuntimeTool) -> void:
	_mutex.lock()
	tools[tool_instance.id] = tool_instance
	_mutex.unlock()


## Removes a tool instance from this simulation.
func remove_tool(tool_id: String) -> void:
	_mutex.lock()
	tools.erase(tool_id)
	_mutex.unlock()


## Adds an active connection path to this simulation.
func add_path(path_instance: RuntimePath) -> void:
	_mutex.lock()
	paths[path_instance.id] = path_instance
	_mutex.unlock()


## Removes a connection path from this simulation.
func remove_path(path_id: String) -> void:
	_mutex.lock()
	paths.erase(path_id)
	_mutex.unlock()
