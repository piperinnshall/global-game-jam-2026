extends Control

@onready var play_button = $MenuContainer/PlayButton
@onready var quit_button = $MenuContainer/QuitButton
@onready var title = $Title
@onready var decorations = $Decorations

var button_hover_scale = 1.1
var button_normal_scale = 1.0
var tween_duration = 0.15

func _ready():
	# Animate decorations
	decorations.modulate.a = 0
	var decor_tween = create_tween()
	decor_tween.tween_property(decorations, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT).set_delay(0.2)
	
	# Animate grass swaying
	_sway_all_grass()
	
	# Animate title on startup
	title.modulate.a = 0
	title.scale = Vector2(1.2, 1.2)
	
	var title_tween = create_tween().set_parallel(true)
	title_tween.tween_property(title, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)
	title_tween.tween_property(title, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Animate buttons on startup
	play_button.modulate.a = 0
	quit_button.modulate.a = 0
	play_button.position.x = -50
	quit_button.position.x = -50
	
	await get_tree().create_timer(0.3).timeout
	
	var play_tween = create_tween().set_parallel(true)
	play_tween.tween_property(play_button, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	play_tween.tween_property(play_button, "position:x", 0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	await get_tree().create_timer(0.1).timeout
	
	var quit_tween = create_tween().set_parallel(true)
	quit_tween.tween_property(quit_button, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	quit_tween.tween_property(quit_button, "position:x", 0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Title pulse effect
	_title_pulse()

func _title_pulse():
	while true:
		var pulse_tween = create_tween()
		pulse_tween.tween_property(title, "scale", Vector2(1.05, 1.05), 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		pulse_tween.tween_property(title, "scale", Vector2.ONE, 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		await pulse_tween.finished

func _sway_all_grass():
	# Animate all grass blades
	for i in range(1, 21):  # 20 grass blades
		var grass = get_node_or_null("Decorations/Grass" + str(i))
		if grass:
			_sway_single_grass(grass, i * 0.1)

func _sway_single_grass(grass: Line2D, delay: float):
	await get_tree().create_timer(delay).timeout
	var original_points = grass.points.duplicate()
	while true:
		var sway_amount = randf_range(6.0, 10.0)
		var sway_tween = create_tween()
		var swayed_points = original_points.duplicate()
		swayed_points[1].x += sway_amount
		sway_tween.tween_property(grass, "points", swayed_points, randf_range(0.8, 1.2)).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		
		await sway_tween.finished
		
		var return_tween = create_tween()
		var other_swayed = original_points.duplicate()
		other_swayed[1].x -= sway_amount * 0.5
		return_tween.tween_property(grass, "points", other_swayed, randf_range(0.8, 1.2)).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		
		await return_tween.finished
		
		var center_tween = create_tween()
		center_tween.tween_property(grass, "points", original_points, randf_range(0.8, 1.2)).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		await center_tween.finished


func _on_play_button_pressed():
	# Snap effect on press
	var press_tween = create_tween().set_parallel(true)
	press_tween.tween_property(play_button, "scale", Vector2(0.9, 0.9), 0.05).set_ease(Tween.EASE_OUT)
	press_tween.tween_property(play_button, "modulate", Color.BLACK, 0.05)
	
	await press_tween.finished
	
	# Screen transition
	var fade_rect = ColorRect.new()
	fade_rect.color = Color.WHITE
	fade_rect.modulate.a = 0
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fade_rect)
	
	var fade_tween = create_tween()
	fade_tween.tween_property(fade_rect, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	
	await fade_tween.finished
	
	get_tree().change_scene_to_file("res://scenes/comic_viewer.tscn")

func _on_quit_button_pressed():
	# Snap effect on press
	var press_tween = create_tween().set_parallel(true)
	press_tween.tween_property(quit_button, "scale", Vector2(0.9, 0.9), 0.05).set_ease(Tween.EASE_OUT)
	press_tween.tween_property(quit_button, "modulate", Color.BLACK, 0.05)
	
	await press_tween.finished
	
	# Screen flash then quit
	var flash_rect = ColorRect.new()
	flash_rect.color = Color.WHITE
	flash_rect.modulate.a = 0
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(flash_rect)
	
	var flash_tween = create_tween()
	flash_tween.tween_property(flash_rect, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)
	
	await flash_tween.finished
	
	get_tree().quit()

func _on_play_button_mouse_entered():
	_button_hover_effect(play_button)

func _on_play_button_mouse_exited():
	_button_normal_effect(play_button)

func _on_quit_button_mouse_entered():
	_button_hover_effect(quit_button)

func _on_quit_button_mouse_exited():
	_button_normal_effect(quit_button)

func _button_hover_effect(button: Button):
	var hover_tween = create_tween().set_parallel(true)
	hover_tween.tween_property(button, "scale", Vector2(button_hover_scale, button_hover_scale), tween_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	hover_tween.tween_property(button, "modulate", Color.WHITE, tween_duration).set_ease(Tween.EASE_OUT)
	
	# Add a subtle background flash
	var style = button.get_theme_stylebox("normal").duplicate()
	if style is StyleBoxFlat:
		style.bg_color = Color.WHITE

func _button_normal_effect(button: Button):
	var normal_tween = create_tween().set_parallel(true)
	normal_tween.tween_property(button, "scale", Vector2(button_normal_scale, button_normal_scale), tween_duration).set_ease(Tween.EASE_OUT)
	normal_tween.tween_property(button, "modulate", Color.WHITE, tween_duration).set_ease(Tween.EASE_OUT)
