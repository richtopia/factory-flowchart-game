## Data model representing a factory recipe that transforms input ingredients
## into output ingredients, optionally requiring heat energy.
class_name RecipeData
extends RefCounted

## Unique identifier for this recipe (e.g., "steam_reforming").
var id: String = ""

## Human-readable display name (e.g., "Steam Reforming").
var name: String = ""

## Heat energy required to run this recipe, in megawatts (MW).
var heat_required: float = 0.0

## List of input ingredients and their consumption rates.
var inputs: Array[RecipeIO] = []

## List of output ingredients and their production rates.
var outputs: Array[RecipeIO] = []


## Creates a [RecipeData] instance from a dictionary.
##
## Expected keys: [code]id[/code], [code]name[/code],
## [code]heat_required[/code], [code]inputs[/code], [code]outputs[/code].
## The [code]inputs[/code] and [code]outputs[/code] values must be arrays of
## dictionaries, each parsed via [method RecipeIO.from_dict].
static func from_dict(d: Dictionary) -> RecipeData:
	var recipe := RecipeData.new()
	recipe.id = d.get("id", "")
	recipe.name = d.get("name", "")
	recipe.heat_required = float(d.get("heat_required", 0.0))

	var raw_inputs: Array = d.get("inputs", [])
	for entry: Variant in raw_inputs:
		if entry is Dictionary:
			recipe.inputs.append(RecipeIO.from_dict(entry))

	var raw_outputs: Array = d.get("outputs", [])
	for entry: Variant in raw_outputs:
		if entry is Dictionary:
			recipe.outputs.append(RecipeIO.from_dict(entry))

	return recipe
