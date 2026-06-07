## SimulationEngine — Global coordinator autoload for the factory simulation.
##
## Manages multiple MapSimulation instances and facilitates thread-safe
## cross-map transfer buffers using Mutex locks.
class_name SimulationEngineClass
extends Node

## Maps currently registered in the simulation: map_id (String) -> MapSimulation.
var active_simulations: Dictionary = {}

# Thread-safe broker buffers for cross-map transfers.
# Structure:
# _cross_map_buffers = {
#     "target_map_id": {
#         "source_tool_id": {
#             "ingredient_id": "water",
#             "rate": 12.5
#         }
#     }
# }
var _cross_map_buffers: Dictionary = {}
var _mutex: Mutex = Mutex.new()


func _ready() -> void:
	# Store reference in metadata for easy tree lookup when autoload isn't fully set up (like in GUT tests)
	Engine.set_meta("SimulationEngine", self)


## Registers a map simulation with the coordinator.
func register_map_simulation(map_id: String, map_sim: MapSimulation) -> void:
	active_simulations[map_id] = map_sim


## Unregisters a map simulation.
func unregister_map_simulation(map_id: String) -> void:
	active_simulations.erase(map_id)


## Starts all registered map simulations.
func start_simulation(hz: float = 1.0) -> void:
	for map_id: String in active_simulations:
		var sim: MapSimulation = active_simulations[map_id]
		sim.start(hz)


## Stops all registered map simulations.
func stop_simulation() -> void:
	for map_id: String in active_simulations:
		var sim: MapSimulation = active_simulations[map_id]
		sim.stop()


## Clears all cross-map data buffers and active simulations.
func clear_all() -> void:
	stop_simulation()
	active_simulations.clear()
	_mutex.lock()
	_cross_map_buffers.clear()
	_mutex.unlock()


## Registers a rate transfer from a source tool in Map A to a destination Map B.
## Thread-safe, callable from MapSimulation's thread.
func transfer_cross_map(target_map_id: String, source_tool_id: String, ingredient_id: String, rate: float) -> void:
	_mutex.lock()
	if not _cross_map_buffers.has(target_map_id):
		_cross_map_buffers[target_map_id] = {}
	
	_cross_map_buffers[target_map_id][source_tool_id] = {
		"ingredient_id": ingredient_id,
		"rate": rate
	}
	_mutex.unlock()


## Consumes the total accumulated supply rate of an ingredient on a target map.
## Thread-safe, callable from MapSimulation's thread.
func consume_cross_map(target_map_id: String, ingredient_id: String) -> float:
	_mutex.lock()
	var total_rate := 0.0
	
	if _cross_map_buffers.has(target_map_id):
		var map_buffer: Dictionary = _cross_map_buffers[target_map_id]
		for src_tool_id: String in map_buffer:
			var entry: Dictionary = map_buffer[src_tool_id]
			if entry.get("ingredient_id", "") == ingredient_id:
				total_rate += entry.get("rate", 0.0)
				
	_mutex.unlock()
	return total_rate
