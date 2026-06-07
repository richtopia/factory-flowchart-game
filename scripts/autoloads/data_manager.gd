## DataManager — Global autoload that loads and validates all TOML data at startup.
##
## Registered as an autoload singleton in project.godot. Scans the res://data/
## directory tree for .toml files, parses them into typed data model instances,
## and runs validation checks. Access loaded data via the dictionaries:
##   DataManager.ingredients, .paths, .recipes, .tools, .maps
class_name DataManagerClass
extends Node

## Emitted after all data is successfully loaded and validated.
signal data_loaded
## Emitted when validation errors are found. Passes the error list.
signal validation_failed(errors: Array[String])

## All loaded data, keyed by their string ID.
var ingredients: Dictionary = {}  # String -> IngredientData
var paths: Dictionary = {}        # String -> PathData
var recipes: Dictionary = {}      # String -> RecipeData
var tools: Dictionary = {}        # String -> ToolData
var maps: Dictionary = {}         # String -> MapData

## Base directory for all data files.
const DATA_ROOT := "res://data"

## Directory names for each entity type.
const DIR_INGREDIENTS := "ingredients"
const DIR_PATHS := "paths"
const DIR_RECIPES := "recipes"
const DIR_TOOLS := "tools"
const DIR_MAPS := "maps"


func _ready() -> void:
	_load_all_data()
	_run_validation()


## Loads all TOML data files from the data directory tree.
func _load_all_data() -> void:
	print("DataManager: Loading data from %s ..." % DATA_ROOT)

	# Load in dependency order: ingredients first (referenced by recipes and paths),
	# then paths, recipes, tools, and finally maps.
	_load_entity_directory(DIR_INGREDIENTS, _parse_ingredient)
	_load_entity_directory(DIR_PATHS, _parse_path)
	_load_entity_directory(DIR_RECIPES, _parse_recipe)
	_load_entity_directory(DIR_TOOLS, _parse_tool)
	_load_entity_directory(DIR_MAPS, _parse_map)

	print("DataManager: Loaded %d ingredients, %d paths, %d recipes, %d tools, %d maps." % [
		ingredients.size(), paths.size(), recipes.size(), tools.size(), maps.size()
	])


## Scans a subdirectory under DATA_ROOT for .toml files and calls the parser
## callback for each one.
func _load_entity_directory(subdir: String, parse_callback: Callable) -> void:
	var dir_path := DATA_ROOT.path_join(subdir)

	if not DirAccess.dir_exists_absolute(dir_path):
		push_warning("DataManager: Data directory not found: %s" % dir_path)
		return

	var files := DirAccess.get_files_at(dir_path)
	for filename in files:
		if not filename.ends_with(".toml"):
			continue
		var full_path := dir_path.path_join(filename)
		var parsed := TOMLParser.parse_file(full_path)
		if parsed.is_empty():
			push_error("DataManager: Failed to parse %s" % full_path)
			continue
		parse_callback.call(parsed, full_path)


## Parse callback: creates an IngredientData and stores it.
func _parse_ingredient(data: Dictionary, source_path: String) -> void:
	var ingredient := IngredientData.from_dict(data)
	if ingredient.id.is_empty():
		push_error("DataManager: Ingredient missing 'id' in %s" % source_path)
		return
	if ingredients.has(ingredient.id):
		push_error("DataManager: Duplicate ingredient id '%s' in %s" % [ingredient.id, source_path])
		return
	ingredients[ingredient.id] = ingredient


## Parse callback: creates a PathData and stores it.
func _parse_path(data: Dictionary, source_path: String) -> void:
	var path_data := PathData.from_dict(data)
	if path_data.id.is_empty():
		push_error("DataManager: Path missing 'id' in %s" % source_path)
		return
	if paths.has(path_data.id):
		push_error("DataManager: Duplicate path id '%s' in %s" % [path_data.id, source_path])
		return
	paths[path_data.id] = path_data


## Parse callback: creates a RecipeData and stores it.
func _parse_recipe(data: Dictionary, source_path: String) -> void:
	var recipe := RecipeData.from_dict(data)
	if recipe.id.is_empty():
		push_error("DataManager: Recipe missing 'id' in %s" % source_path)
		return
	if recipes.has(recipe.id):
		push_error("DataManager: Duplicate recipe id '%s' in %s" % [recipe.id, source_path])
		return
	recipes[recipe.id] = recipe


## Parse callback: creates a ToolData and stores it.
func _parse_tool(data: Dictionary, source_path: String) -> void:
	var tool_data := ToolData.from_dict(data)
	if tool_data.id.is_empty():
		push_error("DataManager: Tool missing 'id' in %s" % source_path)
		return
	if tools.has(tool_data.id):
		push_error("DataManager: Duplicate tool id '%s' in %s" % [tool_data.id, source_path])
		return
	tools[tool_data.id] = tool_data


## Parse callback: creates a MapData and stores it.
func _parse_map(data: Dictionary, source_path: String) -> void:
	var map_data := MapData.from_dict(data)
	if map_data.id.is_empty():
		push_error("DataManager: Map missing 'id' in %s" % source_path)
		return
	if maps.has(map_data.id):
		push_error("DataManager: Duplicate map id '%s' in %s" % [map_data.id, source_path])
		return
	maps[map_data.id] = map_data


## Runs all validation checks after data is fully loaded.
func _run_validation() -> void:
	var validator := DataValidator.new()
	var errors := validator.validate_all(ingredients, paths, recipes, tools, maps)

	if errors.is_empty():
		print("DataManager: All validation checks passed.")
		data_loaded.emit()
	else:
		push_error("DataManager: %d validation error(s) found:" % errors.size())
		for error_msg in errors:
			push_error("  - %s" % error_msg)
		validation_failed.emit(errors)
