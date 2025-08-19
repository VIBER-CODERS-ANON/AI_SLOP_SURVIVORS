extends Node

## Core Systems Initializer
## Autoload script that initializes and manages core game systems

func _ready() -> void:
	# Set up singleton instances
	_initialize_singletons()
	
	# Configure project settings
	_configure_project_settings()

func _initialize_singletons() -> void:
	# Initialize Resource Manager
	if not ResourceManager.instance:
		var resource_manager = ResourceManager.new()
		resource_manager.name = "ResourceManager"
		get_tree().root.add_child(resource_manager)
	
	print("✅ Core systems initialized")

func _configure_project_settings() -> void:
	# Set process priorities
	process_priority = -100  # Ensure core systems process first
	
	# Ensure we're in the correct process mode
	process_mode = Node.PROCESS_MODE_ALWAYS