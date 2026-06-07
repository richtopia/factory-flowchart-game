## Data model representing a single input or output entry within a recipe.
##
## Each [RecipeIO] pairs an ingredient with a flow rate, measured in
## tons per hour.
class_name RecipeIO
extends RefCounted

## The ID of the ingredient consumed or produced.
var ingredient_id: String = ""

## Flow rate in tons per hour.
var rate: float = 0.0


## Creates a [RecipeIO] instance from a dictionary.
##
## Expected keys: [code]ingredient_id[/code], [code]rate[/code].
static func from_dict(d: Dictionary) -> RecipeIO:
	var rio := RecipeIO.new()
	rio.ingredient_id = d.get("ingredient_id", "")
	rio.rate = float(d.get("rate", 0.0))
	return rio
