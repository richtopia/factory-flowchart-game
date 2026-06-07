## Unit tests for all data model classes.
## Tests from_dict() factory methods, default values, and edge cases.
extends GutTest


# ─────────────────────────────────────────────────────────────────────────────
# IngredientData
# ─────────────────────────────────────────────────────────────────────────────

func test_ingredient_from_dict_full() -> void:
	var d := {
		"id": "water",
		"name": "Water",
		"base_unit": "L",
		"measurement_unit": "ton",
		"icon_path": "res://assets/icons/water.png"
	}
	var ing := IngredientData.from_dict(d)
	assert_eq(ing.id, "water")
	assert_eq(ing.name, "Water")
	assert_eq(ing.base_unit, "L")
	assert_eq(ing.measurement_unit, "ton")
	assert_eq(ing.icon_path, "res://assets/icons/water.png")


func test_ingredient_from_dict_missing_fields() -> void:
	var ing := IngredientData.from_dict({"id": "test"})
	assert_eq(ing.id, "test")
	assert_eq(ing.name, "", "Missing name should default to empty")
	assert_eq(ing.base_unit, "", "Missing base_unit should default to empty")
	assert_eq(ing.measurement_unit, "", "Missing measurement_unit should default to empty")


func test_ingredient_from_dict_empty() -> void:
	var ing := IngredientData.from_dict({})
	assert_eq(ing.id, "", "Empty dict should produce empty id")


# ─────────────────────────────────────────────────────────────────────────────
# PathData
# ─────────────────────────────────────────────────────────────────────────────

func test_path_from_dict_full() -> void:
	var d := {
		"id": "pipeline",
		"name": "Pipeline",
		"allowed_ingredients": ["water", "ch4", "h2", "co2"],
		"visual_style": "dense_dashed"
	}
	var path := PathData.from_dict(d)
	assert_eq(path.id, "pipeline")
	assert_eq(path.name, "Pipeline")
	assert_eq(path.allowed_ingredients.size(), 4)
	assert_true(path.allowed_ingredients.has("water"))
	assert_true(path.allowed_ingredients.has("co2"))
	assert_eq(path.visual_style, "dense_dashed")


func test_path_from_dict_empty_ingredients() -> void:
	var path := PathData.from_dict({"id": "test", "allowed_ingredients": []})
	assert_eq(path.allowed_ingredients.size(), 0)


# ─────────────────────────────────────────────────────────────────────────────
# RecipeIO
# ─────────────────────────────────────────────────────────────────────────────

func test_recipe_io_from_dict() -> void:
	var d := {"ingredient_id": "ch4", "rate": 2.2}
	var io := RecipeIO.from_dict(d)
	assert_eq(io.ingredient_id, "ch4")
	assert_almost_eq(io.rate, 2.2, 0.001)


func test_recipe_io_defaults() -> void:
	var io := RecipeIO.from_dict({})
	assert_eq(io.ingredient_id, "")
	assert_almost_eq(io.rate, 0.0, 0.001)


# ─────────────────────────────────────────────────────────────────────────────
# RecipeData
# ─────────────────────────────────────────────────────────────────────────────

func test_recipe_from_dict_full() -> void:
	var d := {
		"id": "steam_reforming",
		"name": "Steam Reforming",
		"heat_required": 6.2,
		"inputs": [
			{"ingredient_id": "ch4", "rate": 2.2},
			{"ingredient_id": "water", "rate": 4.9}
		],
		"outputs": [
			{"ingredient_id": "h2", "rate": 1.1},
			{"ingredient_id": "co2", "rate": 6.0}
		]
	}
	var recipe := RecipeData.from_dict(d)
	assert_eq(recipe.id, "steam_reforming")
	assert_eq(recipe.name, "Steam Reforming")
	assert_almost_eq(recipe.heat_required, 6.2, 0.001)
	assert_eq(recipe.inputs.size(), 2, "Should have 2 inputs")
	assert_eq(recipe.outputs.size(), 2, "Should have 2 outputs")
	assert_eq(recipe.inputs[0].ingredient_id, "ch4")
	assert_almost_eq(recipe.inputs[0].rate, 2.2, 0.001)
	assert_eq(recipe.outputs[1].ingredient_id, "co2")


func test_recipe_from_dict_no_io() -> void:
	var recipe := RecipeData.from_dict({"id": "empty"})
	assert_eq(recipe.inputs.size(), 0, "Missing inputs should default to empty")
	assert_eq(recipe.outputs.size(), 0, "Missing outputs should default to empty")


func test_recipe_ignores_non_dict_io() -> void:
	var d := {
		"id": "bad",
		"inputs": ["not_a_dict", 42],
		"outputs": []
	}
	var recipe := RecipeData.from_dict(d)
	assert_eq(recipe.inputs.size(), 0, "Non-dict entries in inputs should be skipped")


# ─────────────────────────────────────────────────────────────────────────────
# ToolData
# ─────────────────────────────────────────────────────────────────────────────

func test_tool_from_dict_full() -> void:
	var d := {
		"id": "reactor",
		"name": "Chemical Reactor",
		"width_m": 5.0,
		"length_m": 3.0,
		"allowed_recipes": ["steam_reforming"],
		"max_input_paths": 3,
		"max_output_paths": 2
	}
	var tool := ToolData.from_dict(d)
	assert_eq(tool.id, "reactor")
	assert_eq(tool.name, "Chemical Reactor")
	assert_almost_eq(tool.width_m, 5.0, 0.001)
	assert_almost_eq(tool.length_m, 3.0, 0.001)
	assert_eq(tool.allowed_recipes.size(), 1)
	assert_eq(tool.allowed_recipes[0], "steam_reforming")
	assert_eq(tool.max_input_paths, 3)
	assert_eq(tool.max_output_paths, 2)


func test_tool_from_dict_defaults() -> void:
	var tool := ToolData.from_dict({})
	assert_eq(tool.id, "")
	assert_almost_eq(tool.width_m, 0.0, 0.001)
	assert_eq(tool.max_input_paths, 0)
	assert_eq(tool.allowed_recipes.size(), 0)


# ─────────────────────────────────────────────────────────────────────────────
# MapData
# ─────────────────────────────────────────────────────────────────────────────

func test_map_from_dict_full() -> void:
	var d := {
		"id": "aluminum_valley",
		"name": "Aluminum Production Valley",
		"width_m": 500.0,
		"length_m": 200.0,
		"link": {
			"is_linked_map": false,
			"target_map_id": ""
		}
	}
	var map := MapData.from_dict(d)
	assert_eq(map.id, "aluminum_valley")
	assert_eq(map.name, "Aluminum Production Valley")
	assert_almost_eq(map.width_m, 500.0, 0.001)
	assert_almost_eq(map.length_m, 200.0, 0.001)
	assert_false(map.is_linked_map)
	assert_eq(map.target_map_id, "")


func test_map_from_dict_linked() -> void:
	var d := {
		"id": "sub_map",
		"name": "Sub Map",
		"width_m": 100.0,
		"length_m": 100.0,
		"link": {
			"is_linked_map": true,
			"target_map_id": "main_map"
		}
	}
	var map := MapData.from_dict(d)
	assert_true(map.is_linked_map, "Should be linked")
	assert_eq(map.target_map_id, "main_map")


func test_map_from_dict_no_link() -> void:
	var map := MapData.from_dict({"id": "simple", "width_m": 50.0, "length_m": 50.0})
	assert_false(map.is_linked_map, "Default should be not linked")
	assert_eq(map.target_map_id, "", "Default target_map_id should be empty")


# ─────────────────────────────────────────────────────────────────────────────
# Integration: TOML parse → data model round-trip
# ─────────────────────────────────────────────────────────────────────────────

func test_toml_to_ingredient_round_trip() -> void:
	var toml := 'id = "water"\nname = "Water"\nbase_unit = "L"\nmeasurement_unit = "ton"\nicon_path = "res://assets/icons/water.png"'
	var parsed := TOMLParser.parse_string(toml)
	var ing := IngredientData.from_dict(parsed)
	assert_eq(ing.id, "water")
	assert_eq(ing.base_unit, "L")


func test_toml_to_recipe_round_trip() -> void:
	var toml := """id = "steam_reforming"
name = "Steam Reforming"
heat_required = 6.2

[[inputs]]
ingredient_id = "ch4"
rate = 2.2

[[inputs]]
ingredient_id = "water"
rate = 4.9

[[outputs]]
ingredient_id = "h2"
rate = 1.1

[[outputs]]
ingredient_id = "co2"
rate = 6.0"""
	var parsed := TOMLParser.parse_string(toml)
	var recipe := RecipeData.from_dict(parsed)
	assert_eq(recipe.id, "steam_reforming")
	assert_eq(recipe.inputs.size(), 2)
	assert_eq(recipe.outputs.size(), 2)
	assert_eq(recipe.inputs[0].ingredient_id, "ch4")
	assert_almost_eq(recipe.outputs[1].rate, 6.0, 0.001)


func test_toml_to_map_round_trip() -> void:
	var toml := """id = "aluminum_valley"
name = "Aluminum Production Valley"
width_m = 500
length_m = 200

[link]
is_linked_map = false
target_map_id = \"\""""
	var parsed := TOMLParser.parse_string(toml)
	var map := MapData.from_dict(parsed)
	assert_eq(map.id, "aluminum_valley")
	assert_almost_eq(map.width_m, 500.0, 0.001)
	assert_false(map.is_linked_map)
