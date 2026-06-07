## Unit tests for the DataValidator.
## Covers referential integrity, metric unit whitelists, positive value
## enforcement, and duplicate ID detection.
extends GutTest


# ─────────────────────────────────────────────────────────────────────────────
# Helpers — build minimal valid data sets
# ─────────────────────────────────────────────────────────────────────────────

func _make_ingredient(id: String, base_u: String = "L", meas_u: String = "ton") -> IngredientData:
	return IngredientData.from_dict({
		"id": id, "name": id.capitalize(),
		"base_unit": base_u, "measurement_unit": meas_u,
		"icon_path": "res://assets/icons/%s.png" % id
	})


func _make_path(id: String, ingredients: Array = []) -> PathData:
	return PathData.from_dict({
		"id": id, "name": id.capitalize(),
		"allowed_ingredients": ingredients,
		"visual_style": "dense_dashed"
	})


func _make_recipe_io(ingredient_id: String, rate: float) -> Dictionary:
	return {"ingredient_id": ingredient_id, "rate": rate}


func _make_recipe(id: String, inputs: Array = [], outputs: Array = []) -> RecipeData:
	return RecipeData.from_dict({
		"id": id, "name": id.capitalize(), "heat_required": 1.0,
		"inputs": inputs, "outputs": outputs
	})


func _make_tool(id: String, recipes: Array = []) -> ToolData:
	return ToolData.from_dict({
		"id": id, "name": id.capitalize(),
		"width_m": 5.0, "length_m": 3.0,
		"allowed_recipes": recipes,
		"max_input_paths": 2, "max_output_paths": 2
	})


func _make_map(id: String, linked: bool = false, target: String = "") -> MapData:
	return MapData.from_dict({
		"id": id, "name": id.capitalize(),
		"width_m": 100.0, "length_m": 100.0,
		"link": {"is_linked_map": linked, "target_map_id": target}
	})


func _valid_data() -> Dictionary:
	# Build a minimal self-consistent data set
	var ingredients := {
		"water": _make_ingredient("water"),
		"ch4": _make_ingredient("ch4"),
		"h2": _make_ingredient("h2"),
		"co2": _make_ingredient("co2"),
	}
	var paths := {
		"pipeline": _make_path("pipeline", ["water", "ch4", "h2", "co2"])
	}
	var recipes := {
		"steam_reforming": _make_recipe("steam_reforming",
			[_make_recipe_io("ch4", 2.2), _make_recipe_io("water", 4.9)],
			[_make_recipe_io("h2", 1.1), _make_recipe_io("co2", 6.0)]
		)
	}
	var tools := {
		"reactor": _make_tool("reactor", ["steam_reforming"])
	}
	var maps := {
		"valley": _make_map("valley")
	}
	return {"i": ingredients, "p": paths, "r": recipes, "t": tools, "m": maps}


# ─────────────────────────────────────────────────────────────────────────────
# Valid data passes
# ─────────────────────────────────────────────────────────────────────────────

func test_valid_data_passes() -> void:
	var d := _valid_data()
	var validator := DataValidator.new()
	var errors := validator.validate_all(d["i"], d["p"], d["r"], d["t"], d["m"])
	assert_eq(errors.size(), 0, "Valid data should produce zero errors. Got: %s" % str(errors))


# ─────────────────────────────────────────────────────────────────────────────
# Referential integrity: missing ingredient in recipe
# ─────────────────────────────────────────────────────────────────────────────

func test_recipe_references_unknown_ingredient() -> void:
	var d := _valid_data()
	# Add a recipe referencing a nonexistent ingredient
	d["r"]["bad_recipe"] = _make_recipe("bad_recipe",
		[_make_recipe_io("unobtainium", 1.0)],
		[_make_recipe_io("water", 1.0)]
	)
	var validator := DataValidator.new()
	var errors := validator.validate_all(d["i"], d["p"], d["r"], d["t"], d["m"])
	assert_true(errors.size() > 0, "Should catch unknown ingredient reference")
	var found := false
	for e in errors:
		if "unobtainium" in e:
			found = true
	assert_true(found, "Error should mention 'unobtainium'")


# ─────────────────────────────────────────────────────────────────────────────
# Referential integrity: missing recipe in tool
# ─────────────────────────────────────────────────────────────────────────────

func test_tool_references_unknown_recipe() -> void:
	var d := _valid_data()
	d["t"]["bad_tool"] = _make_tool("bad_tool", ["nonexistent_recipe"])
	var validator := DataValidator.new()
	var errors := validator.validate_all(d["i"], d["p"], d["r"], d["t"], d["m"])
	assert_true(errors.size() > 0, "Should catch unknown recipe reference")
	var found := false
	for e in errors:
		if "nonexistent_recipe" in e:
			found = true
	assert_true(found, "Error should mention 'nonexistent_recipe'")


# ─────────────────────────────────────────────────────────────────────────────
# Referential integrity: missing ingredient in path
# ─────────────────────────────────────────────────────────────────────────────

func test_path_references_unknown_ingredient() -> void:
	var d := _valid_data()
	d["p"]["bad_path"] = _make_path("bad_path", ["water", "mystery_gas"])
	var validator := DataValidator.new()
	var errors := validator.validate_all(d["i"], d["p"], d["r"], d["t"], d["m"])
	assert_true(errors.size() > 0, "Should catch unknown ingredient in path")
	var found := false
	for e in errors:
		if "mystery_gas" in e:
			found = true
	assert_true(found, "Error should mention 'mystery_gas'")


# ─────────────────────────────────────────────────────────────────────────────
# Referential integrity: map cross-link to unknown map
# ─────────────────────────────────────────────────────────────────────────────

func test_map_links_to_unknown_map() -> void:
	var d := _valid_data()
	d["m"]["linked"] = _make_map("linked", true, "nonexistent_map")
	var validator := DataValidator.new()
	var errors := validator.validate_all(d["i"], d["p"], d["r"], d["t"], d["m"])
	assert_true(errors.size() > 0, "Should catch unknown target map reference")


func test_map_self_reference() -> void:
	var d := _valid_data()
	d["m"]["self_ref"] = _make_map("self_ref", true, "self_ref")
	var validator := DataValidator.new()
	var errors := validator.validate_all(d["i"], d["p"], d["r"], d["t"], d["m"])
	assert_true(errors.size() > 0, "Should catch self-referencing map")


# ─────────────────────────────────────────────────────────────────────────────
# Metric unit validation
# ─────────────────────────────────────────────────────────────────────────────

func test_invalid_base_unit() -> void:
	var d := _valid_data()
	d["i"]["bad_unit"] = _make_ingredient("bad_unit", "gallons", "ton")
	var validator := DataValidator.new()
	var errors := validator.validate_all(d["i"], d["p"], d["r"], d["t"], d["m"])
	assert_true(errors.size() > 0, "Should reject invalid base unit 'gallons'")
	var found := false
	for e in errors:
		if "gallons" in e:
			found = true
	assert_true(found, "Error should mention 'gallons'")


func test_invalid_measurement_unit() -> void:
	var d := _valid_data()
	d["i"]["bad_meas"] = _make_ingredient("bad_meas", "kg", "pounds")
	var validator := DataValidator.new()
	var errors := validator.validate_all(d["i"], d["p"], d["r"], d["t"], d["m"])
	assert_true(errors.size() > 0, "Should reject invalid measurement unit 'pounds'")


# ─────────────────────────────────────────────────────────────────────────────
# Positive value enforcement
# ─────────────────────────────────────────────────────────────────────────────

func test_negative_rate_in_recipe() -> void:
	var d := _valid_data()
	d["r"]["neg_rate"] = _make_recipe("neg_rate",
		[_make_recipe_io("water", -1.0)],
		[_make_recipe_io("ch4", 1.0)]
	)
	var validator := DataValidator.new()
	var errors := validator.validate_all(d["i"], d["p"], d["r"], d["t"], d["m"])
	assert_true(errors.size() > 0, "Should catch negative rate")


func test_zero_rate_in_recipe() -> void:
	var d := _valid_data()
	d["r"]["zero_rate"] = _make_recipe("zero_rate",
		[_make_recipe_io("water", 0.0)],
		[_make_recipe_io("ch4", 1.0)]
	)
	var validator := DataValidator.new()
	var errors := validator.validate_all(d["i"], d["p"], d["r"], d["t"], d["m"])
	assert_true(errors.size() > 0, "Should catch zero rate")


func test_negative_dimensions_on_tool() -> void:
	var d := _valid_data()
	d["t"]["bad_dim"] = ToolData.from_dict({
		"id": "bad_dim", "name": "Bad",
		"width_m": -1.0, "length_m": 3.0,
		"allowed_recipes": [], "max_input_paths": 0, "max_output_paths": 0
	})
	var validator := DataValidator.new()
	var errors := validator.validate_all(d["i"], d["p"], d["r"], d["t"], d["m"])
	assert_true(errors.size() > 0, "Should catch negative width")


func test_negative_dimensions_on_map() -> void:
	var d := _valid_data()
	d["m"]["bad_map"] = MapData.from_dict({
		"id": "bad_map", "name": "Bad",
		"width_m": 100.0, "length_m": -50.0
	})
	var validator := DataValidator.new()
	var errors := validator.validate_all(d["i"], d["p"], d["r"], d["t"], d["m"])
	assert_true(errors.size() > 0, "Should catch negative length")


# ─────────────────────────────────────────────────────────────────────────────
# Missing required fields
# ─────────────────────────────────────────────────────────────────────────────

func test_recipe_with_no_inputs_or_outputs() -> void:
	var d := _valid_data()
	d["r"]["empty_recipe"] = _make_recipe("empty_recipe", [], [])
	var validator := DataValidator.new()
	var errors := validator.validate_all(d["i"], d["p"], d["r"], d["t"], d["m"])
	assert_true(errors.size() > 0, "Should catch recipe with no inputs/outputs")


func test_negative_heat_required() -> void:
	var d := _valid_data()
	d["r"]["neg_heat"] = RecipeData.from_dict({
		"id": "neg_heat", "name": "Neg Heat", "heat_required": -5.0,
		"inputs": [{"ingredient_id": "water", "rate": 1.0}],
		"outputs": [{"ingredient_id": "ch4", "rate": 1.0}]
	})
	var validator := DataValidator.new()
	var errors := validator.validate_all(d["i"], d["p"], d["r"], d["t"], d["m"])
	assert_true(errors.size() > 0, "Should catch negative heat_required")
