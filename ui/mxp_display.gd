extends Control
class_name MXPDisplay

## Displays the current Monster XP (MXP) available to all chatters

var mxp_label: Label
var timer_label: Label

func _ready():
	# Set up container
	custom_minimum_size = Vector2(200, 60)
	
	# Create background panel
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	
	# Create container for labels
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)
	
	# MXP amount label
	mxp_label = Label.new()
	mxp_label.text = "Monster XP: 0"
	mxp_label.add_theme_font_size_override("font_size", 20)
	mxp_label.add_theme_color_override("font_color", Color.GOLD)
	mxp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(mxp_label)
	
	# Timer label
	timer_label = Label.new()
	timer_label.text = "Next MXP: 10s"
	timer_label.add_theme_font_size_override("font_size", 14)
	timer_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(timer_label)
	
	# Connect to MXP manager signals
	if MXPManager.instance:
		MXPManager.instance.mxp_granted.connect(_on_mxp_granted)

func _process(_delta):
	# Update timer display
	if MXPManager.instance:
		# Only update countdown if not paused
		if not get_tree().paused:
			var time_until_next = MXPManager.MXP_GRANT_INTERVAL - MXPManager.instance.grant_timer
			timer_label.text = "Next MXP: %ds" % int(ceil(time_until_next))
		
		# Always update MXP amount (even when paused)
		mxp_label.text = "Monster XP: %d" % MXPManager.instance.total_mxp_available

func _on_mxp_granted(_amount: int):
	# Flash effect when MXP is granted
	var tween = create_tween()
	tween.tween_property(mxp_label, "modulate", Color(2, 2, 0), 0.2)
	tween.tween_property(mxp_label, "modulate", Color.WHITE, 0.3)
