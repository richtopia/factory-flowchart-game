## Data model representing a transport path (e.g., pipeline, conveyor belt)
## that connects factory tools and carries ingredients between them.
class_name PathData
extends RefCounted

## Unique identifier for this path type (e.g., "pipeline").
var id: String = ""

## Human-readable display name (e.g., "Pipeline").
var name: String = ""

## List of ingredient IDs that this path type is allowed to carry.
var allowed_ingredients: Array[String] = []

## Visual rendering style identifier (e.g., "dense_dashed", "sparse_dashed").
var visual_style: String = ""


## Creates a [PathData] instance from a dictionary.
##
## Expected keys: [code]id[/code], [code]name[/code],
## [code]allowed_ingredients[/code], [code]visual_style[/code].
static func from_dict(d: Dictionary) -> PathData:
	var path := PathData.new()
	path.id = d.get("id", "")
	path.name = d.get("name", "")
	path.visual_style = d.get("visual_style", "")

	var raw_ingredients: Array = d.get("allowed_ingredients", [])
	for ingredient_id: Variant in raw_ingredients:
		path.allowed_ingredients.append(str(ingredient_id))

	return path
