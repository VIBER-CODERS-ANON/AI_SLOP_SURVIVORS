class_name NodeUtils
extends RefCounted

## Utility class for common node operations
## Provides standardized methods for node references and searches

## Get a required child node with error handling
static func get_required_node(parent: Node, path: String, node_type: String = "Node") -> Node:
	var node = parent.get_node_or_null(path)
	if not node:
		push_error("%s: Required %s node not found at path: %s" % [parent.name, node_type, path])
		return null
	return node

## Get an optional child node (no error if missing)
static func get_optional_node(parent: Node, path: String) -> Node:
	return parent.get_node_or_null(path)

## Find first node in group with validation
static func find_node_in_group(tree: SceneTree, group_name: String) -> Node:
	if not tree:
		return null
	
	var nodes = tree.get_nodes_in_group(group_name)
	if nodes.is_empty():
		return null
	
	return nodes[0]

## Find all nodes in group
static func find_all_nodes_in_group(tree: SceneTree, group_name: String) -> Array:
	if not tree:
		return []
	
	return tree.get_nodes_in_group(group_name)

## Get component from entity (looks for specific node types)
static func get_component(entity: Node, component_name: String) -> Node:
	# First try direct child
	var component = entity.get_node_or_null(component_name)
	if component:
		return component
	
	# Try common paths
	var common_paths = [
		"Components/" + component_name,
		"Abilities/" + component_name,
		"Systems/" + component_name
	]
	
	for path in common_paths:
		component = entity.get_node_or_null(path)
		if component:
			return component
	
	return null

## Safely connect signal with validation
static func safe_connect(source: Object, signal_name: String, target: Object, method: String) -> bool:
	if not source or not target:
		push_error("NodeUtils: Cannot connect signal - source or target is null")
		return false
	
	if not source.has_signal(signal_name):
		push_error("NodeUtils: Source %s does not have signal: %s" % [source, signal_name])
		return false
	
	if not target.has_method(method):
		push_error("NodeUtils: Target %s does not have method: %s" % [target, method])
		return false
	
	if not source.is_connected(signal_name, Callable(target, method)):
		source.connect(signal_name, Callable(target, method))
		return true
	
	return false

## Safely disconnect signal
static func safe_disconnect(source: Object, signal_name: String, target: Object, method: String) -> bool:
	if not source or not target:
		return false
	
	if source.has_signal(signal_name) and source.is_connected(signal_name, Callable(target, method)):
		source.disconnect(signal_name, Callable(target, method))
		return true
	
	return false

## Find parent of specific type
static func find_parent_of_type(node: Node, type_name: String) -> Node:
	var current = node.get_parent()
	while current:
		if current.get_class() == type_name or current.is_class(type_name):
			return current
		current = current.get_parent()
	return null

## Get all children of specific type
static func get_children_of_type(parent: Node, type_name: String) -> Array:
	var result = []
	for child in parent.get_children():
		if child.get_class() == type_name or child.is_class(type_name):
			result.append(child)
	return result

## Defer node setup (useful for initialization)
static func defer_setup(node: Node, setup_method: String, wait_time: float = 0.1) -> void:
	if not node or not node.has_method(setup_method):
		push_error("NodeUtils: Cannot defer setup - invalid node or method")
		return
	
	var tree = node.get_tree()
	if tree:
		await tree.create_timer(wait_time).timeout
		if is_instance_valid(node):
			node.call(setup_method)

## Create and configure a node
static func create_node(node_class: GDScript, name: String, parent: Node = null) -> Node:
	var node = node_class.new()
	node.name = name
	
	if parent:
		parent.add_child(node)
	
	return node

## Batch get nodes with error handling
static func batch_get_nodes(parent: Node, paths: Dictionary) -> Dictionary:
	var result = {}
	
	for key in paths:
		var path = paths[key]
		var node = parent.get_node_or_null(path)
		if node:
			result[key] = node
		else:
			push_warning("NodeUtils: Node not found at path %s for key %s" % [path, key])
			result[key] = null
	
	return result

## Check if node is in scene tree and valid
static func is_node_ready(node: Node) -> bool:
	return node and is_instance_valid(node) and node.is_inside_tree()

## Get or create child node
static func get_or_create_child(parent: Node, child_name: String, child_class: GDScript) -> Node:
	var child = parent.get_node_or_null(child_name)
	if not child:
		child = child_class.new()
		child.name = child_name
		parent.add_child(child)
	return child