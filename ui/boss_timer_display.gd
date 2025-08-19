extends Control
class_name BossTimerDisplay

## Displays countdown to next boss vote

var timer_label: Label

func _ready():
	# Make sure this pauses properly
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# Create container
	var panel = PanelContainer.new()
	panel.modulate = Color(1, 1, 1, 0.8)
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "Next Boss Vote"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0))
	vbox.add_child(title)
	
	# Timer
	timer_label = Label.new()
	timer_label.text = "2:00"
	timer_label.add_theme_font_size_override("font_size", 24)
	timer_label.add_theme_color_override("font_color", Color(1, 1, 1))
	vbox.add_child(timer_label)

func _process(_delta):
	if not BossVoteManager.instance:
		return
		
	# Update timer display
	var time_to_vote = BossVoteManager.instance.get_time_until_next_vote()
	if time_to_vote > 0:
		var minutes = int(time_to_vote / 60.0)
		var seconds = int(time_to_vote) % 60
		timer_label.text = "%d:%02d" % [minutes, seconds]
		timer_label.modulate = Color.WHITE
		
		# Flash when under 10 seconds
		if time_to_vote <= 10:
			timer_label.modulate = (Color(1, 0.5, 0.5) if int(time_to_vote * 2.0) % 2 == 0 else Color.WHITE)
	else:
		# During voting
		var vote_time = BossVoteManager.instance.get_voting_time_remaining()
		if vote_time > 0:
			timer_label.text = "VOTE! %d" % int(vote_time)
			timer_label.modulate = Color(0.5, 1, 0.5)
		else:
			timer_label.text = "Soon..."
			timer_label.modulate = Color(0.7, 0.7, 0.7)
