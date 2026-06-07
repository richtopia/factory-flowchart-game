## FlowSolver — Iterative rate balancer for the simulation graph.
##
## Implements a flow relaxation algorithm that propagates available materials forward
## (supply/starvation checks) and capacity constraints backward (backpressure/throttling).
class_name FlowSolver
extends RefCounted

## Maximum number of relaxation iterations per tick.
const MAX_ITERATIONS := 10

## Convergence epsilon value. If changes across all tool operating rates
## are less than this, solver stops early.
const CONVERGENCE_EPSILON := 0.0001


## Solves the flow rates for the provided tools and paths.
static func solve_rates(tools: Dictionary, paths: Dictionary) -> void:
	# 1. Initialize all tool operating rates to 1.0 and clear ports
	for tool: RuntimeTool in tools.values():
		tool._clear_ports()
		tool.operating_rate = 1.0
		
	for path: RuntimePath in paths.values():
		path.flow_rate = 0.0
		path.update_carried_ingredient()

	# 2. Iterate to resolve rates and backpressure
	for iter in range(MAX_ITERATIONS):
		var max_change := 0.0
		
		# A. Reset input port flows on all tools before propagation
		for tool: RuntimeTool in tools.values():
			for i in range(tool.tool_data.max_input_paths):
				tool.input_port_flows[i] = 0.0
		
		# B. Setup inputs for importers and operating state of exporters/importers
		for tool: RuntimeTool in tools.values():
			if tool.is_importer:
				tool.operating_rate = 1.0
				tool.output_port_flows[0] = tool.import_available_rate
			elif tool.is_exporter:
				# Exporters act as infinite sinks
				tool.operating_rate = 1.0
				tool.output_port_flows[0] = 0.0 # No outputs

		# C. Calculate desired outputs for recipe-based tools using current operating_rate
		for tool: RuntimeTool in tools.values():
			if not tool.is_importer and not tool.is_exporter and tool.selected_recipe != null:
				for j in range(tool.selected_recipe.outputs.size()):
					tool.output_port_flows[j] = tool.selected_recipe.outputs[j].rate * tool.operating_rate

		# D. Forward Pass: Propagate output flows to connected paths
		# Group paths by their source key: "source_tool_id_port_index"
		var port_paths := {}
		for path: RuntimePath in paths.values():
			var key := "%s_%d" % [path.source_tool.id, path.source_port]
			if not port_paths.has(key):
				port_paths[key] = []
			port_paths[key].append(path)

		for key: String in port_paths:
			var plist: Array = port_paths[key]
			var src_tool: RuntimeTool = plist[0].source_tool
			var src_port: int = plist[0].source_port
			var total_output: float = src_tool.output_port_flows.get(src_port, 0.0)

			# Split output flow proportionally based on downstream demands
			var total_demand := 0.0
			var demands := []
			for path: RuntimePath in plist:
				var demand := 10000.0  # Large default demand for sinks/exporters
				if not path.target_tool.is_exporter and path.target_tool.selected_recipe != null:
					var tgt_port := path.target_port
					if tgt_port < path.target_tool.selected_recipe.inputs.size():
						demand = path.target_tool.selected_recipe.inputs[tgt_port].rate
				demands.append(demand)
				total_demand += demand

			for idx in range(plist.size()):
				var path: RuntimePath = plist[idx]
				var demand: float = demands[idx]
				if total_demand > 0.0:
					path.flow_rate = total_output * (demand / total_demand)
				else:
					path.flow_rate = total_output / plist.size()

				# Accumulate into target port's flow
				path.target_tool.input_port_flows[path.target_port] = path.target_tool.input_port_flows.get(path.target_port, 0.0) + path.flow_rate

		# E. Update supply operating rates (Starvation check)
		var new_rates := {}
		for tool: RuntimeTool in tools.values():
			if tool.is_importer or tool.is_exporter:
				new_rates[tool.id] = tool.operating_rate
				continue
				
			if tool.selected_recipe == null:
				new_rates[tool.id] = 0.0
				continue

			var min_ratio := 1.0
			var has_inputs := false
			for i in range(tool.selected_recipe.inputs.size()):
				has_inputs = true
				var req := tool.selected_recipe.inputs[i].rate
				var act: float = tool.input_port_flows.get(i, 0.0)
				if req > 0.0:
					var ratio := act / req
					if ratio < min_ratio:
						min_ratio = ratio
			
			if not has_inputs:
				new_rates[tool.id] = 1.0  # Raw producers (e.g. mines) run at 100%
			else:
				new_rates[tool.id] = clampf(min_ratio, 0.0, 1.0)

		# F. Backward Pass: Throttling & Backpressure
		# Adjust operating rates if downstream connections cannot accept the outputs
		for tool: RuntimeTool in tools.values():
			if tool.is_importer or tool.is_exporter or tool.selected_recipe == null:
				continue

			var min_out_ratio := 1.0
			var current_rate: float = new_rates[tool.id]

			for j in range(tool.selected_recipe.outputs.size()):
				var key := "%s_%d" % [tool.id, j]
				if not port_paths.has(key):
					# Unconnected output does not throttle (it vents/wastes)
					continue

				var plist: Array = port_paths[key]
				var total_path_capacity := 0.0
				for path: RuntimePath in plist:
					var path_cap := 0.0
					if path.target_tool.is_exporter:
						path_cap = 10000.0  # Exporters accept everything
					elif path.target_tool.selected_recipe != null:
						var tgt_port := path.target_port
						if tgt_port < path.target_tool.selected_recipe.inputs.size():
							var target_req := path.target_tool.selected_recipe.inputs[tgt_port].rate
							# Target can consume up to its requirement * its operating rate
							# (using the newly computed operating rate for this iteration)
							var target_rate: float = new_rates.get(path.target_tool.id, 0.0)
							path_cap = target_req * target_rate
					total_path_capacity += path_cap

				var req_out := tool.selected_recipe.outputs[j].rate
				if req_out > 0.0:
					var out_ratio := total_path_capacity / req_out
					if out_ratio < min_out_ratio:
						min_out_ratio = out_ratio

			# Clamp operating rate based on backpressure
			new_rates[tool.id] = clampf(minf(current_rate, min_out_ratio), 0.0, 1.0)

		# G. Apply changes and check for convergence
		for tool: RuntimeTool in tools.values():
			var rate_diff := absf(tool.operating_rate - new_rates[tool.id])
			if rate_diff > max_change:
				max_change = rate_diff
			tool.operating_rate = new_rates[tool.id]

		if max_change < CONVERGENCE_EPSILON:
			break
