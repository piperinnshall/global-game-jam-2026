extends Node

@export var wait_time := 1.0
@export var fade_time := 0.5

var covers := []

func _ready():
	for i in range(8):
		covers.append(get_node("Cover%d" % i))

	reveal_comic()

func reveal_comic() -> void:
	for cover in covers:
		await get_tree().create_timer(wait_time).timeout
		await fade_out(cover)

	# final pause before completion
	await get_tree().create_timer(wait_time + 3).timeout
	complete()

func fade_out(cover: Sprite2D) -> void:
	var tween = create_tween()
	tween.tween_property(cover, "modulate:a", 0.0, fade_time)
	await tween.finished
	cover.visible = false

func complete() -> void:
	get_tree().change_scene_to_file("res://scenes/level1.tscn")

	print("Comic reveal complete!")
