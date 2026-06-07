## Data model representing a factory tool (machine) that can execute recipes
## to transform ingredients.
##
## Tools have physical dimensions for placement on the map and constraints
## on which recipes they support and how many paths they accept.
class_name ToolData
extends RefCounted

## Unique identifier for this tool type (e.g., "reactor").
var id: String = ""

## Human-readable display name (e.g., "Chemical Reactor").
var name: String = ""

## Physical width of the tool in meters, used for map placement.
var width_m: float = 0.0

## Physical length of the tool in meters, used for map placement.
var length_m: float = 0.0

## List of recipe IDs that this tool is capable of executing.
var allowed_recipes: Array[String] = []

## Maximum number of input paths that can connect to this tool.
var max_input_paths: int = 0

## Maximum number of output paths that can originate from this tool.
var max_output_paths: int = 0


## Creates a [ToolData] instance from a dictionary.
##
## Expected keys: [code]id[/code], [code]name[/code], [code]width_m[/code],
## [code]length_m[/code], [code]allowed_recipes[/code],
## [code]max_input_paths[/code], [code]max_output_paths[/code].
static func from_dict(d: Dictionary) -> ToolData:
	var tool := ToolData.new()
	tool.id = d.get("id", "")
	tool.name = d.get("name", "")
	tool.width_m = float(d.get("width_m", 0.0))
	tool.length_m = float(d.get("length_m", 0.0))
	tool.max_input_paths = int(d.get("max_input_paths", 0))
	tool.max_output_paths = int(d.get("max_output_paths", 0))

	var raw_recipes: Array = d.get("allowed_recipes", [])
	for recipe_id: Variant in raw_recipes:
		tool.allowed_recipes.append(str(recipe_id))

	return tool
