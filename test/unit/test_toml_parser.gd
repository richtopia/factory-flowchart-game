## Unit tests for the TOMLParser.
## Covers key-value pairs, strings, numbers, booleans, arrays,
## standard tables, array-of-tables, comments, and error handling.
extends GutTest


# ─────────────────────────────────────────────────────────────────────────────
# Basic key-value parsing
# ─────────────────────────────────────────────────────────────────────────────

func test_parse_string_value() -> void:
	var result := TOMLParser.parse_string('id = "water"')
	assert_eq(result.get("id"), "water", "Should parse basic string value")


func test_parse_integer_value() -> void:
	var result := TOMLParser.parse_string("max_paths = 3")
	assert_eq(result.get("max_paths"), 3, "Should parse integer value")


func test_parse_float_value() -> void:
	var result := TOMLParser.parse_string("rate = 2.2")
	assert_almost_eq(result.get("rate"), 2.2, 0.001, "Should parse float value")


func test_parse_boolean_true() -> void:
	var result := TOMLParser.parse_string("enabled = true")
	assert_true(result.get("enabled"), "Should parse boolean true")


func test_parse_boolean_false() -> void:
	var result := TOMLParser.parse_string("enabled = false")
	assert_false(result.get("enabled"), "Should parse boolean false")


func test_parse_negative_float() -> void:
	var result := TOMLParser.parse_string("offset = -3.5")
	assert_almost_eq(result.get("offset"), -3.5, 0.001, "Should parse negative float")


func test_parse_positive_sign_integer() -> void:
	var result := TOMLParser.parse_string("count = +42")
	assert_eq(result.get("count"), 42, "Should parse positive-signed integer")


# ─────────────────────────────────────────────────────────────────────────────
# String variants
# ─────────────────────────────────────────────────────────────────────────────

func test_parse_basic_string_with_escapes() -> void:
	var result := TOMLParser.parse_string('msg = "hello\\nworld"')
	assert_eq(result.get("msg"), "hello\nworld", "Should handle \\n escape")


func test_parse_literal_string() -> void:
	var result := TOMLParser.parse_string("path = 'C:\\Users\\test'")
	assert_eq(result.get("path"), "C:\\Users\\test", "Literal strings should not process escapes")


func test_parse_empty_string() -> void:
	var result := TOMLParser.parse_string('empty = ""')
	assert_eq(result.get("empty"), "", "Should handle empty string")


# ─────────────────────────────────────────────────────────────────────────────
# Arrays
# ─────────────────────────────────────────────────────────────────────────────

func test_parse_string_array() -> void:
	var result := TOMLParser.parse_string('tags = ["water", "ch4", "h2"]')
	var arr: Array = result.get("tags", [])
	assert_eq(arr.size(), 3, "Should have 3 elements")
	assert_eq(arr[0], "water")
	assert_eq(arr[1], "ch4")
	assert_eq(arr[2], "h2")


func test_parse_empty_array() -> void:
	var result := TOMLParser.parse_string("items = []")
	var arr: Array = result.get("items", [])
	assert_eq(arr.size(), 0, "Empty array should have 0 elements")


func test_parse_array_with_trailing_comma() -> void:
	var result := TOMLParser.parse_string('tags = ["a", "b",]')
	var arr: Array = result.get("tags", [])
	assert_eq(arr.size(), 2, "Trailing comma should not add extra element")


func test_parse_numeric_array() -> void:
	var result := TOMLParser.parse_string("values = [1, 2, 3]")
	var arr: Array = result.get("values", [])
	assert_eq(arr.size(), 3)
	assert_eq(arr[0], 1)
	assert_eq(arr[2], 3)


# ─────────────────────────────────────────────────────────────────────────────
# Comments
# ─────────────────────────────────────────────────────────────────────────────

func test_comments_are_ignored() -> void:
	var toml := '# This is a comment\nid = "test" # inline comment\n# Another comment'
	var result := TOMLParser.parse_string(toml)
	assert_eq(result.get("id"), "test", "Comments should be ignored")
	assert_eq(result.size(), 1, "Should only have one key")


# ─────────────────────────────────────────────────────────────────────────────
# Standard tables
# ─────────────────────────────────────────────────────────────────────────────

func test_parse_standard_table() -> void:
	var toml := 'id = "test"\n\n[link]\nis_linked = false\ntarget = ""'
	var result := TOMLParser.parse_string(toml)
	assert_eq(result.get("id"), "test")
	assert_true(result.has("link"), "Should have 'link' sub-table")
	var link: Dictionary = result.get("link", {})
	assert_false(link.get("is_linked"), "link.is_linked should be false")
	assert_eq(link.get("target"), "", "link.target should be empty string")


# ─────────────────────────────────────────────────────────────────────────────
# Array of tables
# ─────────────────────────────────────────────────────────────────────────────

func test_parse_array_of_tables() -> void:
	var toml := '[[items]]\nname = "a"\ncount = 1\n\n[[items]]\nname = "b"\ncount = 2'
	var result := TOMLParser.parse_string(toml)
	assert_true(result.has("items"), "Should have 'items' key")
	var items: Array = result.get("items", [])
	assert_eq(items.size(), 2, "Should have 2 entries")
	assert_eq(items[0].get("name"), "a")
	assert_eq(items[0].get("count"), 1)
	assert_eq(items[1].get("name"), "b")
	assert_eq(items[1].get("count"), 2)


# ─────────────────────────────────────────────────────────────────────────────
# Full schema tests (match PROJECT_SPEC examples)
# ─────────────────────────────────────────────────────────────────────────────

func test_parse_ingredient_schema() -> void:
	var toml := 'id = "water"\nname = "Water"\nbase_unit = "L"\nmeasurement_unit = "ton"\nicon_path = "res://assets/icons/water.png"'
	var result := TOMLParser.parse_string(toml)
	assert_eq(result.get("id"), "water")
	assert_eq(result.get("name"), "Water")
	assert_eq(result.get("base_unit"), "L")
	assert_eq(result.get("measurement_unit"), "ton")
	assert_eq(result.get("icon_path"), "res://assets/icons/water.png")


func test_parse_path_schema() -> void:
	var toml := 'id = "pipeline"\nname = "Pipeline"\nallowed_ingredients = ["water", "ch4", "h2", "co2"]\nvisual_style = "dense_dashed"'
	var result := TOMLParser.parse_string(toml)
	assert_eq(result.get("id"), "pipeline")
	var arr: Array = result.get("allowed_ingredients", [])
	assert_eq(arr.size(), 4)
	assert_true(arr.has("water"))
	assert_true(arr.has("co2"))


func test_parse_recipe_schema() -> void:
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
	var result := TOMLParser.parse_string(toml)
	assert_eq(result.get("id"), "steam_reforming")
	assert_almost_eq(result.get("heat_required"), 6.2, 0.001)
	var inputs: Array = result.get("inputs", [])
	assert_eq(inputs.size(), 2, "Should have 2 inputs")
	assert_eq(inputs[0].get("ingredient_id"), "ch4")
	assert_almost_eq(inputs[0].get("rate"), 2.2, 0.001)
	assert_eq(inputs[1].get("ingredient_id"), "water")
	var outputs: Array = result.get("outputs", [])
	assert_eq(outputs.size(), 2, "Should have 2 outputs")
	assert_eq(outputs[0].get("ingredient_id"), "h2")


func test_parse_map_schema() -> void:
	var toml := """id = "aluminum_valley"
name = "Aluminum Production Valley"
width_m = 500
length_m = 200

[link]
is_linked_map = false
target_map_id = \"\""""
	var result := TOMLParser.parse_string(toml)
	assert_eq(result.get("id"), "aluminum_valley")
	assert_eq(result.get("width_m"), 500)
	var link: Dictionary = result.get("link", {})
	assert_false(link.get("is_linked_map"))
	assert_eq(link.get("target_map_id"), "")


# ─────────────────────────────────────────────────────────────────────────────
# Error handling
# ─────────────────────────────────────────────────────────────────────────────

func test_malformed_missing_equals() -> void:
	var result := TOMLParser.parse_string('id "water"')
	assert_true(result.is_empty(), "Should return empty dict on missing '='")


func test_malformed_unclosed_string() -> void:
	var result := TOMLParser.parse_string('id = "unclosed')
	assert_true(result.is_empty(), "Should return empty dict on unclosed string")


func test_empty_input() -> void:
	var result := TOMLParser.parse_string("")
	assert_true(result.is_empty() or result.size() == 0, "Empty input should return empty dict")


func test_comments_only() -> void:
	var result := TOMLParser.parse_string("# just a comment\n# another comment")
	assert_eq(result.size(), 0, "Comments-only should return empty dict")


# ─────────────────────────────────────────────────────────────────────────────
# Multiple key-value pairs
# ─────────────────────────────────────────────────────────────────────────────

func test_multiple_key_values() -> void:
	var toml := 'a = "x"\nb = 42\nc = true\nd = 3.14'
	var result := TOMLParser.parse_string(toml)
	assert_eq(result.size(), 4, "Should have 4 keys")
	assert_eq(result.get("a"), "x")
	assert_eq(result.get("b"), 42)
	assert_true(result.get("c"))
	assert_almost_eq(result.get("d"), 3.14, 0.001)
