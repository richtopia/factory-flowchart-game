## FlowchartEditor — Visual flowchart canvas extending GraphEdit.
##
## Synchronizes UI drag-and-drop connections with the backend SimulationEngine.
## Overrides native connection rendering to draw colored dashed lines according to path data.
class_name FlowchartEditor
extends GraphEdit

## Preloaded visual tool node scene.
var tool_node_scene := preload("res://scenes/ui/tool_node.tscn")

## Active map simulation being displayed.
var current_map_sim: MapSimulation = null

# Counter to generate unique path IDs
var _path_counter: int = 0


func _ready() -> void:
	# Enable scrolling/zooming
	right_disconnects = true
	
	# Register valid connections for each ingredient
	_register_valid_connections()
	
	# Connect GraphEdit signals
	connect("connection_request", _on_connection_request)
	connect("disconnection_request", _on_disconnection_request)


# Registers that ports of the same ingredient type are compatible.
func _register_valid_connections() -> void:
	for ing_id: String in DataManager.ingredients:
		var type_id = _get_ingredient_port_type(ing_id)
		add_valid_connection_type(type_id, type_id)


## Loads a MapSimulation and instantiates its visual GraphNodes and connections.
func load_map(map_id: String) -> void:
	# 1. Clear existing nodes
	clear_connections()
	for child in get_children():
		if child is GraphNode:
			child.queue_free()
			
	# Fetch map simulation
	var sim_engine: SimulationEngineClass = Engine.get_meta("SimulationEngine")
	if not sim_engine or not sim_engine.active_simulations.has(map_id):
		push_error("Map simulation not registered: %s" % map_id)
		return
		
	current_map_sim = sim_engine.active_simulations[map_id]
	
	# 2. Instantiate Tool Nodes
	var index := 0
	for tool_id: String in current_map_sim.tools:
		var r_tool: RuntimeTool = current_map_sim.tools[tool_id]
		var node: ToolNode = tool_node_scene.instantiate()
		
		# Set instance name and offset
		node.name = r_tool.id
		node.position_offset = Vector2(150 + index * 320, 150 + (index % 2) * 220)
		
		add_child(node)
		node.setup_node(r_tool)
		
		# Connect node dragged signal to update tool position offset if needed
		index += 1

	# 3. Restore connections
	# Wait a frame for children to enter tree so port positions are valid
	await get_tree().process_frame
	
	for path_id: String in current_map_sim.paths:
		var r_path: RuntimePath = current_map_sim.paths[path_id]
		var src_node_name = r_path.source_tool.id
		var tgt_node_name = r_path.target_tool.id
		
		connect_node(src_node_name, r_path.source_port, tgt_node_name, r_path.target_port)
		
	queue_redraw()


## Called periodically to sync simulation metrics with visual labels.
func update_ui() -> void:
	for child in get_children():
		if child is ToolNode:
			child.update_metrics()
	queue_redraw()


## Intercepts native GraphEdit connections to build backend paths.
func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if current_map_sim == null:
		return
		
	var src_node: ToolNode = get_node(str(from_node)) as ToolNode
	var tgt_node: ToolNode = get_node(str(to_node)) as ToolNode
	
	if not src_node or not tgt_node:
		return
		
	# Verify that the ports are compatible
	var src_ing = src_node.runtime_tool.get_output_port_ingredient(from_port)
	var tgt_ing = tgt_node.runtime_tool.get_input_port_ingredient(to_port)
	
	if src_ing != tgt_ing or src_ing.is_empty():
		push_warning("Incompatible ports: %s -> %s" % [src_ing, tgt_ing])
		return
		
	# Check if the connection already exists in GraphEdit
	for conn in get_connection_list():
		if conn.from_node == from_node and conn.from_port == from_port and conn.to_node == to_node and conn.to_port == to_port:
			return # Duplicate connection

	# Instantiate RuntimePath in simulation
	_path_counter += 1
	var path_id = "path_%d" % _path_counter
	
	var raw_path_data := PathData.new()
	raw_path_data.id = "pipeline"
	raw_path_data.allowed_ingredients = [src_ing]
	raw_path_data.visual_style = "dense_dashed" if src_ing != "electricity" else "sparse_dashed"
	
	# Determine visual style based on ingredient properties
	if src_ing == "electricity" or src_ing == "heat":
		raw_path_data.visual_style = "sparse_dashed"
	elif src_ing == "bauxite" or src_ing == "alumina" or src_ing == "aluminum" or src_ing == "extruded_bar":
		raw_path_data.visual_style = "solid"
		
	var r_path := RuntimePath.new(path_id, raw_path_data, src_node.runtime_tool, from_port, tgt_node.runtime_tool, to_port)
	
	current_map_sim.add_path(r_path)
	connect_node(from_node, from_port, to_node, to_port)
	queue_redraw()


## Intercepts native GraphEdit disconnections to delete backend paths.
func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if current_map_sim == null:
		return
		
	# Find path in MapSimulation
	var found_path_id := ""
	for path_id: String in current_map_sim.paths:
		var p: RuntimePath = current_map_sim.paths[path_id]
		if p.source_tool.id == from_node and p.source_port == from_port and p.target_tool.id == to_node and p.target_port == to_port:
			found_path_id = path_id
			break
			
	if not found_path_id.is_empty():
		current_map_sim.remove_path(found_path_id)
		
	disconnect_node(from_node, from_port, to_node, to_port)
	queue_redraw()


## Triggered when a tool node changes its recipe. Cleans up orphaned connections.
func on_tool_recipe_changed(node: ToolNode) -> void:
	# Scan all active connections and disconnect any that are now out-of-bounds or incompatible
	var conns = get_connection_list()
	for conn: Dictionary in conns:
		if conn.from_node == node.name:
			var ing = node.runtime_tool.get_output_port_ingredient(conn.from_port)
			var target_node: ToolNode = get_node(str(conn.to_node)) as ToolNode
			var tgt_ing = target_node.runtime_tool.get_input_port_ingredient(conn.to_port) if target_node else ""
			if ing.is_empty() or ing != tgt_ing:
				_on_disconnection_request(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
				
		elif conn.to_node == node.name:
			var ing = node.runtime_tool.get_input_port_ingredient(conn.to_port)
			var source_node: ToolNode = get_node(str(conn.from_node)) as ToolNode
			var src_ing = source_node.runtime_tool.get_output_port_ingredient(conn.from_port) if source_node else ""
			if ing.is_empty() or ing != src_ing:
				_on_disconnection_request(conn.from_node, conn.from_port, conn.to_node, conn.to_port)




# Maps ingredient ID string to integer port type.
func _get_ingredient_port_type(ing_id: String) -> int:
	var keys = DataManager.ingredients.keys()
	keys.sort()
	var idx = keys.find(ing_id)
	if idx != -1:
		return idx + 1
	return 999
