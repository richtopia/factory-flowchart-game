## RuntimeTool — Represents an instanced machine on a map in the simulation.
##
## Tracks runtime state like operating capacity (operating_rate), recipe assignment,
## current port flows, and cross-map link roles (importer/exporter).
class_name RuntimeTool
extends RefCounted

## Unique instance identifier on the map (e.g., "reactor_1").
var id: String = ""

## Read-only static blueprint configuration for this tool type.
var tool_data: ToolData

## The recipe currently selected and being processed by this tool.
var selected_recipe: RecipeData = null

## Current operating efficiency/capacity scaling (0.0 to 1.0).
## 1.0 means operating at 100% of the recipe rates.
var operating_rate: float = 0.0

## Cross-map export configuration.
var is_exporter: bool = false
var export_target_map: String = ""

## Cross-map import configuration.
var is_importer: bool = false
var import_source_map: String = ""
var import_ingredient_id: String = ""
var import_available_rate: float = 0.0  # Provided dynamically by SimulationEngine

## Port flows: keyed by port index (int) -> current material rate (float, in ton/h or L/h).
var input_port_flows: Dictionary = {}
var output_port_flows: Dictionary = {}


func _init(p_id: String, p_tool_data: ToolData) -> void:
	id = p_id
	tool_data = p_tool_data
	_clear_ports()


## Clears all port flows to 0.0.
func _clear_ports() -> void:
	input_port_flows.clear()
	output_port_flows.clear()
	
	for i in range(tool_data.max_input_paths):
		input_port_flows[i] = 0.0
	for i in range(tool_data.max_output_paths):
		output_port_flows[i] = 0.0


## Assigns a recipe to this tool. Verifies the recipe is allowed by ToolData.
func set_recipe(recipe: RecipeData) -> bool:
	if recipe == null:
		selected_recipe = null
		_clear_ports()
		return true
		
	if not tool_data.allowed_recipes.has(recipe.id):
		push_error("Tool '%s' cannot run recipe '%s'." % [tool_data.id, recipe.id])
		return false
		
	selected_recipe = recipe
	_clear_ports()
	return true


## Gets the ingredient ID expected at a specific input port index.
## Returns an empty string if index is out of bounds or no recipe is assigned.
func get_input_port_ingredient(port_index: int) -> String:
	if is_exporter and port_index == 0:
		# Exporters accept the ingredient they export
		return import_ingredient_id # Reuse for exported ingredient
	if selected_recipe == null or port_index < 0 or port_index >= selected_recipe.inputs.size():
		return ""
	return selected_recipe.inputs[port_index].ingredient_id


## Gets the ingredient ID produced at a specific output port index.
## Returns an empty string if index is out of bounds or no recipe is assigned.
func get_output_port_ingredient(port_index: int) -> String:
	if is_importer and port_index == 0:
		return import_ingredient_id
	if selected_recipe == null or port_index < 0 or port_index >= selected_recipe.outputs.size():
		return ""
	return selected_recipe.outputs[port_index].ingredient_id


## Helper to configure this tool as an importer from another map.
func configure_as_importer(source_map: String, ingredient_id: String) -> void:
	is_importer = true
	import_source_map = source_map
	import_ingredient_id = ingredient_id
	selected_recipe = null
	_clear_ports()


## Helper to configure this tool as an exporter to another map.
func configure_as_exporter(target_map: String, ingredient_id: String) -> void:
	is_exporter = true
	export_target_map = target_map
	import_ingredient_id = ingredient_id  # Stores the exported ingredient ID
	selected_recipe = null
	_clear_ports()
