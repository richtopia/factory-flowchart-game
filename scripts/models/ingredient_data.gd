## Data model representing a raw ingredient or material in the factory simulation.
##
## Each ingredient has a base unit for internal calculations and a
## measurement unit for display purposes (e.g., tons, MW).
class_name IngredientData
extends RefCounted

## Unique identifier for this ingredient (e.g., "water", "ch4").
var id: String = ""

## Human-readable display name (e.g., "Water", "Methane").
var name: String = ""

## Base SI unit used for internal calculations (e.g., "L", "kg", "J").
var base_unit: String = ""

## Unit used for display and rate calculations (e.g., "ton", "MW").
var measurement_unit: String = ""

## Resource path to the ingredient's icon texture.
var icon_path: String = ""


## Creates an [IngredientData] instance from a dictionary.
##
## Expected keys: [code]id[/code], [code]name[/code], [code]base_unit[/code],
## [code]measurement_unit[/code], [code]icon_path[/code].
static func from_dict(d: Dictionary) -> IngredientData:
	var ingredient := IngredientData.new()
	ingredient.id = d.get("id", "")
	ingredient.name = d.get("name", "")
	ingredient.base_unit = d.get("base_unit", "")
	ingredient.measurement_unit = d.get("measurement_unit", "")
	ingredient.icon_path = d.get("icon_path", "")
	return ingredient
