## ToolNode — Visual GraphNode script representing a machine in the flowchart UI.
##
## Dynamically creates slots for inputs (left) and outputs (right) based on recipe,
## colors ports by ingredient type, and renders real-time throughput metrics.
class_name ToolNode
extends GraphNode

## Reference to the simulation tool instance.
var runtime_tool: RuntimeTool

# UI Control references
@onready var status_label: Label = $StatusLabel
@onready var recipe_button: OptionButton = $RecipeButton

# Port-to-ingredient ID registry (slot_idx -> ingredient_id)
var input_ingredients: Dictionary = {}
var output_ingredients: Dictionary = {}

# Label references for updating flow rates dynamically
var input_labels: Dictionary = {}  # slot_idx -> Label
var output_labels: Dictionary = {} # slot_idx -> Label

# Index of the dynamic slot container children start line
var slots_start_index: int = 3


func _ready() -> void:
	# Enable custom styling/resizing
	resizable = true
	# Setup title
	title = runtime_tool.tool_data.name if runtime_tool else "Tool"


## Sets up the node with its runtime tool reference and allowed recipes.
func setup_node(tool_instance: RuntimeTool) -> void:
	runtime_tool = tool_instance
	title = runtime_tool.tool_data.name
	
	# Populate recipes OptionButton
	recipe_button.clear()
	recipe_button.add_item("No Recipe", 0)
	
	var select_idx := 0
	var idx := 1
	for recipe_id: String in runtime_tool.tool_data.allowed_recipes:
		var recipe: RecipeData = DataManager.recipes.get(recipe_id)
		if recipe:
			recipe_button.add_item(recipe.name, idx)
			recipe_button.set_item_metadata(idx, recipe_id)
			if runtime_tool.selected_recipe and runtime_tool.selected_recipe.id == recipe_id:
				select_idx = idx
			idx += 1
			
	recipe_button.selected = select_idx
	
	# Connect recipe selection change
	if not recipe_button.is_connected("item_selected", _on_recipe_selected):
		recipe_button.connect("item_selected", _on_recipe_selected)
		
	# Disable recipe button if importer or exporter
	if runtime_tool.is_importer or runtime_tool.is_exporter:
		recipe_button.visible = false
		$Separator.visible = false
		
	# Initial build of slot controls
	rebuild_slots()
	update_metrics()


## Rebuilds the input and output slots based on the selected recipe.
func rebuild_slots() -> void:
	# 1. Clear existing dynamic slot children
	var children = get_children()
	for i in range(slots_start_index, children.size()):
		children[i].queue_free()
		
	input_ingredients.clear()
	output_ingredients.clear()
	input_labels.clear()
	output_labels.clear()
	clear_all_slots()

	var inputs: Array = []
	var outputs: Array = []
	
	if runtime_tool.is_importer:
		# Importer has one output port
		var ing_name := "Import"
		var ing_data: IngredientData = DataManager.ingredients.get(runtime_tool.import_ingredient_id)
		if ing_data:
			ing_name = ing_data.name
		outputs.append({
			"ingredient_id": runtime_tool.import_ingredient_id,
			"rate": 0.0, # Rate is dynamic
			"name": ing_name
		})
	elif runtime_tool.is_exporter:
		# Exporter has one input port
		var ing_name := "Export"
		var ing_data: IngredientData = DataManager.ingredients.get(runtime_tool.import_ingredient_id)
		if ing_data:
			ing_name = ing_data.name
		inputs.append({
			"ingredient_id": runtime_tool.import_ingredient_id,
			"rate": 0.0,
			"name": ing_name
		})
	elif runtime_tool.selected_recipe != null:
		# Standard recipe-based ports
		var recipe := runtime_tool.selected_recipe
		for inp: RecipeIO in recipe.inputs:
			var ing: IngredientData = DataManager.ingredients.get(inp.ingredient_id)
			inputs.append({
				"ingredient_id": inp.ingredient_id,
				"rate": inp.rate,
				"name": ing.name if ing else inp.ingredient_id
			})
		for out: RecipeIO in recipe.outputs:
			var ing: IngredientData = DataManager.ingredients.get(out.ingredient_id)
			outputs.append({
				"ingredient_id": out.ingredient_id,
				"rate": out.rate,
				"name": ing.name if ing else out.ingredient_id
			})

	# 2. Build the slot UI controls
	var num_slots = max(inputs.size(), outputs.size())
	for i in range(num_slots):
		var container := HBoxContainer.new()
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(container)
		
		# Set up left (input) slot
		var has_left := i < inputs.size()
		var left_type := 0
		var left_color := Color.GRAY
		if has_left:
			var inp_data: Dictionary = inputs[i]
			var ing_id: String = inp_data["ingredient_id"]
			input_ingredients[i] = ing_id
			left_type = _get_ingredient_port_type(ing_id)
			left_color = _get_ingredient_color(ing_id)
			
			var lbl := Label.new()
			lbl.text = inp_data["name"]
			container.add_child(lbl)
			input_labels[i] = lbl
			
		# Add flexible spacer between left and right labels
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_child(spacer)
		
		# Set up right (output) slot
		var has_right := i < outputs.size()
		var right_type := 0
		var right_color := Color.GRAY
		if has_right:
			var out_data: Dictionary = outputs[i]
			var ing_id: String = out_data["ingredient_id"]
			output_ingredients[i] = ing_id
			right_type = _get_ingredient_port_type(ing_id)
			right_color = _get_ingredient_color(ing_id)
			
			var lbl := Label.new()
			lbl.text = out_data["name"]
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			container.add_child(lbl)
			output_labels[i] = lbl
			
		# Configure slot inside GraphNode
		set_slot(
			i,
			has_left,
			left_type,
			left_color,
			has_right,
			right_type,
			right_color
		)


## Refreshes the real-time metrics (operating rate and port flow rate labels).
func update_metrics() -> void:
	if not is_inside_tree():
		return
		
	# Update efficiency text and state colors
	if runtime_tool.selected_recipe == null and not runtime_tool.is_importer and not runtime_tool.is_exporter:
		status_label.text = "Idle (Select Recipe)"
		status_label.add_theme_color_override("font_color", Color.GRAY)
	else:
		var efficiency = int(runtime_tool.operating_rate * 100)
		status_label.text = "Efficiency: %d%%" % efficiency
		
		if efficiency == 100:
			status_label.add_theme_color_override("font_color", Color.GREEN)
		elif efficiency > 0:
			status_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			status_label.add_theme_color_override("font_color", Color.RED)

	# Update input port labels
	for slot_idx: int in input_labels:
		var lbl: Label = input_labels[slot_idx]
		var ing_id: String = input_ingredients[slot_idx]
		var ing: IngredientData = DataManager.ingredients.get(ing_id)
		
		var rate: float = runtime_tool.input_port_flows.get(slot_idx, 0.0)
		var unit := ing.measurement_unit if ing else "t"
		lbl.text = "%s [%.1f %s/h]" % [ing.name if ing else ing_id, rate, unit]

	# Update output port labels
	for slot_idx: int in output_labels:
		var lbl: Label = output_labels[slot_idx]
		var ing_id: String = output_ingredients[slot_idx]
		var ing: IngredientData = DataManager.ingredients.get(ing_id)
		
		var rate: float = runtime_tool.output_port_flows.get(slot_idx, 0.0)
		# For importers, use the current active flow rate
		if runtime_tool.is_importer:
			rate = runtime_tool.output_port_flows.get(0, 0.0)
			
		var unit := ing.measurement_unit if ing else "t"
		lbl.text = "[%.1f %s/h] %s" % [rate, unit, ing.name if ing else ing_id]


## Triggers when a new recipe is selected in the dropdown.
func _on_recipe_selected(idx: int) -> void:
	if idx == 0:
		runtime_tool.set_recipe(null)
	else:
		var recipe_id: String = recipe_button.get_item_metadata(idx)
		var recipe: RecipeData = DataManager.recipes.get(recipe_id)
		runtime_tool.set_recipe(recipe)
		
	# Notify the main editor that connections might have changed/been invalidated
	var parent = get_parent()
	if parent and parent.has_method("on_tool_recipe_changed"):
		parent.on_tool_recipe_changed(self)
		
	rebuild_slots()
	update_metrics()


# Gets a color based on ingredient type for visual contrast.
func _get_ingredient_color(ing_id: String) -> Color:
	match ing_id.to_lower():
		"water":
			return Color(0.2, 0.5, 1.0) # Vibrant Blue
		"ch4":
			return Color(0.2, 0.8, 0.2) # Methane Green
		"h2":
			return Color(0.4, 0.8, 1.0) # Light Hydrogen Blue
		"co2":
			return Color(0.9, 0.4, 0.1) # Carbon Dioxide Orange
		"alumina", "aluminum_ore", "bauxite":
			return Color(0.8, 0.5, 0.3) # Ore Brown
		"molten_aluminum", "aluminum", "extruded_bar":
			return Color(0.8, 0.8, 0.8) # Silver Metal
		"electricity":
			return Color(1.0, 0.9, 0.1) # Bright yellow
		_:
			return Color(0.6, 0.6, 0.6) # Default Grey


# Dynamically maps ingredient strings to unique port type integer codes.
func _get_ingredient_port_type(ing_id: String) -> int:
	var keys = DataManager.ingredients.keys()
	keys.sort()
	var idx = keys.find(ing_id)
	if idx != -1:
		return idx + 1 # Use 1-indexed to avoid 0 (default/generic)
	return 999
