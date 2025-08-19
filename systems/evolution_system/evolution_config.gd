extends Resource
class_name EvolutionConfig

## Configuration for an evolution type
## Defines the requirements and properties of an evolution

@export var display_name: String = ""
@export var scene_path: String = ""
@export var mxp_cost: int = 10
@export var description: String = ""
@export var special_tags: Array = []  # Array of strings
@export var base_stats: Dictionary = {
	"health": 100,
	"damage": 10,
	"move_speed": 50,
	"size_scale": 1.0
}

func setup(name_text: String, path: String, cost: int, desc: String, tags: Array = []) -> EvolutionConfig:
	self.display_name = name_text
	scene_path = path
	mxp_cost = cost
	description = desc
	special_tags = tags
	return self
