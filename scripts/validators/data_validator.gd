## DataValidator — Validates loaded data for referential integrity and metric correctness.
##
## Called by DataManager after all TOML data has been parsed and stored.
## Returns an Array[String] of human-readable error messages. An empty array
## means all checks passed.
class_name DataValidator
extends RefCounted

## Configurable whitelist of valid base units (metric SI or derived).
## Extend this list as new ingredients require different base tracking units.
const VALID_BASE_UNITS: PackedStringArray = [
	"kg",   # kilograms — mass
	"L",    # litres — volume
	"J",    # joules — energy
	"m",    # metres — length
	"mol",  # moles — amount of substance
	"W",    # watts — power
	"A",    # amperes — electric current
	"K",    # kelvin — temperature
	"Pa",   # pascals — pressure
]

## Configurable whitelist of valid measurement (display/scaling) units.
const VALID_MEASUREMENT_UNITS: PackedStringArray = [
	"ton",   # metric tonnes
	"MW",    # megawatts
	"kWh",   # kilowatt-hours
	"m3",    # cubic metres
	"GJ",    # gigajoules
	"kA",    # kiloamperes
	"bar",   # pressure
]


## Runs all validation checks against the loaded data dictionaries.
## Returns an array of error message strings (empty = all passed).
func validate_all(
	ingredients_dict: Dictionary,
	paths_dict: Dictionary,
	recipes_dict: Dictionary,
	tools_dict: Dictionary,
	maps_dict: Dictionary
) -> Array[String]:
	var errors: Array[String] = []

	_validate_ingredients(ingredients_dict, errors)
	_validate_paths(paths_dict, ingredients_dict, errors)
	_validate_recipes(recipes_dict, ingredients_dict, errors)
	_validate_tools(tools_dict, recipes_dict, errors)
	_validate_maps(maps_dict, errors)

	return errors


## Validates all ingredient entries.
func _validate_ingredients(ingredients_dict: Dictionary, errors: Array[String]) -> void:
	for id: String in ingredients_dict:
		var ing: IngredientData = ingredients_dict[id]
		var prefix := "Ingredient '%s'" % id

		# Check required fields
		if ing.name.is_empty():
			errors.append("%s: missing 'name'" % prefix)

		# Validate base_unit against whitelist
		if ing.base_unit.is_empty():
			errors.append("%s: missing 'base_unit'" % prefix)
		elif not VALID_BASE_UNITS.has(ing.base_unit):
			errors.append("%s: invalid base_unit '%s' (allowed: %s)" % [
				prefix, ing.base_unit, ", ".join(VALID_BASE_UNITS)
			])

		# Validate measurement_unit against whitelist
		if ing.measurement_unit.is_empty():
			errors.append("%s: missing 'measurement_unit'" % prefix)
		elif not VALID_MEASUREMENT_UNITS.has(ing.measurement_unit):
			errors.append("%s: invalid measurement_unit '%s' (allowed: %s)" % [
				prefix, ing.measurement_unit, ", ".join(VALID_MEASUREMENT_UNITS)
			])


## Validates all path entries. Checks ingredient references.
func _validate_paths(
	paths_dict: Dictionary,
	ingredients_dict: Dictionary,
	errors: Array[String]
) -> void:
	for id: String in paths_dict:
		var path: PathData = paths_dict[id]
		var prefix := "Path '%s'" % id

		if path.name.is_empty():
			errors.append("%s: missing 'name'" % prefix)

		if path.visual_style.is_empty():
			errors.append("%s: missing 'visual_style'" % prefix)

		if path.allowed_ingredients.is_empty():
			errors.append("%s: 'allowed_ingredients' is empty" % prefix)

		# Referential integrity: each allowed ingredient must exist
		for ingredient_id in path.allowed_ingredients:
			if not ingredients_dict.has(ingredient_id):
				errors.append("%s: references unknown ingredient '%s'" % [
					prefix, ingredient_id
				])


## Validates all recipe entries. Checks ingredient references and rate values.
func _validate_recipes(
	recipes_dict: Dictionary,
	ingredients_dict: Dictionary,
	errors: Array[String]
) -> void:
	for id: String in recipes_dict:
		var recipe: RecipeData = recipes_dict[id]
		var prefix := "Recipe '%s'" % id

		if recipe.name.is_empty():
			errors.append("%s: missing 'name'" % prefix)

		# Heat must be non-negative
		if recipe.heat_required < 0.0:
			errors.append("%s: heat_required is negative (%.2f)" % [
				prefix, recipe.heat_required
			])

		# Must have at least one input and one output
		if recipe.inputs.is_empty():
			errors.append("%s: has no inputs defined" % prefix)
		if recipe.outputs.is_empty():
			errors.append("%s: has no outputs defined" % prefix)

		# Validate each input
		for i in range(recipe.inputs.size()):
			var input_io: RecipeIO = recipe.inputs[i]
			var io_prefix := "%s input[%d]" % [prefix, i]

			if input_io.ingredient_id.is_empty():
				errors.append("%s: missing 'ingredient_id'" % io_prefix)
			elif not ingredients_dict.has(input_io.ingredient_id):
				errors.append("%s: references unknown ingredient '%s'" % [
					io_prefix, input_io.ingredient_id
				])

			if input_io.rate <= 0.0:
				errors.append("%s: rate must be > 0 (got %.4f)" % [
					io_prefix, input_io.rate
				])

		# Validate each output
		for i in range(recipe.outputs.size()):
			var output_io: RecipeIO = recipe.outputs[i]
			var io_prefix := "%s output[%d]" % [prefix, i]

			if output_io.ingredient_id.is_empty():
				errors.append("%s: missing 'ingredient_id'" % io_prefix)
			elif not ingredients_dict.has(output_io.ingredient_id):
				errors.append("%s: references unknown ingredient '%s'" % [
					io_prefix, output_io.ingredient_id
				])

			if output_io.rate <= 0.0:
				errors.append("%s: rate must be > 0 (got %.4f)" % [
					io_prefix, output_io.rate
				])


## Validates all tool entries. Checks recipe references and dimensions.
func _validate_tools(
	tools_dict: Dictionary,
	recipes_dict: Dictionary,
	errors: Array[String]
) -> void:
	for id: String in tools_dict:
		var tool: ToolData = tools_dict[id]
		var prefix := "Tool '%s'" % id

		if tool.name.is_empty():
			errors.append("%s: missing 'name'" % prefix)

		# Dimensions must be positive
		if tool.width_m <= 0.0:
			errors.append("%s: width_m must be > 0 (got %.2f)" % [prefix, tool.width_m])
		if tool.length_m <= 0.0:
			errors.append("%s: length_m must be > 0 (got %.2f)" % [prefix, tool.length_m])

		# Port counts must be non-negative
		if tool.max_input_paths < 0:
			errors.append("%s: max_input_paths is negative (%d)" % [prefix, tool.max_input_paths])
		if tool.max_output_paths < 0:
			errors.append("%s: max_output_paths is negative (%d)" % [prefix, tool.max_output_paths])

		# Referential integrity: each allowed recipe must exist
		for recipe_id in tool.allowed_recipes:
			if not recipes_dict.has(recipe_id):
				errors.append("%s: references unknown recipe '%s'" % [prefix, recipe_id])


## Validates all map entries. Checks dimensions and cross-map references.
func _validate_maps(maps_dict: Dictionary, errors: Array[String]) -> void:
	for id: String in maps_dict:
		var map: MapData = maps_dict[id]
		var prefix := "Map '%s'" % id

		if map.name.is_empty():
			errors.append("%s: missing 'name'" % prefix)

		# Dimensions must be positive
		if map.width_m <= 0.0:
			errors.append("%s: width_m must be > 0 (got %.2f)" % [prefix, map.width_m])
		if map.length_m <= 0.0:
			errors.append("%s: length_m must be > 0 (got %.2f)" % [prefix, map.length_m])

		# Cross-map link validation
		if map.is_linked_map:
			if map.target_map_id.is_empty():
				errors.append("%s: is_linked_map is true but target_map_id is empty" % prefix)
			elif not maps_dict.has(map.target_map_id):
				errors.append("%s: references unknown target map '%s'" % [
					prefix, map.target_map_id
				])
			# Prevent self-referencing
			if map.target_map_id == id:
				errors.append("%s: target_map_id references itself" % prefix)
