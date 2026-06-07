## RuntimePath — Represents an instanced connection between tool ports on a map.
##
## Channels materials/ingredients from a source tool's output port to a target
## tool's input port at a calculated flow rate.
class_name RuntimePath
extends RefCounted

## Unique identifier for this path instance (e.g. "path_1").
var id: String = ""

## Read-only static blueprint configuration for this connection type.
var path_data: PathData

## Source tool where this path starts.
var source_tool: RuntimeTool

## Output port index on the source tool (0-indexed).
var source_port: int

## Target tool where this path ends.
var target_tool: RuntimeTool

## Input port index on the target tool (0-indexed).
var target_port: int

## Current material flow rate traveling through the path (e.g. ton/h or L/h).
var flow_rate: float = 0.0

## The ID of the ingredient currently flowing through this path.
var carried_ingredient_id: String = ""


func _init(p_id: String, p_path_data: PathData, p_src: RuntimeTool, p_src_port: int, p_tgt: RuntimeTool, p_tgt_port: int) -> void:
	id = p_id
	path_data = p_path_data
	source_tool = p_src
	source_port = p_src_port
	target_tool = p_tgt
	target_port = p_tgt_port
	
	flow_rate = 0.0
	update_carried_ingredient()


## Refreshes the carried ingredient ID based on the source tool's output port.
func update_carried_ingredient() -> void:
	carried_ingredient_id = source_tool.get_output_port_ingredient(source_port)


## Checks if the target tool's input port accepts the carried ingredient.
func is_connection_compatible() -> bool:
	update_carried_ingredient()
	if carried_ingredient_id.is_empty():
		return false
		
	# Check if the target port expects the same ingredient
	var target_expected = target_tool.get_input_port_ingredient(target_port)
	if target_expected != carried_ingredient_id:
		return false
		
	# Check if the path data allows this ingredient
	if not path_data.allowed_ingredients.has(carried_ingredient_id):
		return false
		
	return true
