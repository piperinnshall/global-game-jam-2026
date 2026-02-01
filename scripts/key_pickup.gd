extends Area2D

# Bob settings
@export var bob_height: float = 10.0
@export var bob_speed: float = 2.0

# Collection
var collected: bool = false

# Animation state
var bob_time: float = 0.0

# Node references
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	bob_time = randf() * TAU  # random starting phase
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if collected:
		return
	bob_time += delta * bob_speed
	sprite.position.y = sin(bob_time) * bob_height

func _on_body_entered(body: Node2D) -> void:
	if collected:
		return
	if body.name == "Player" or body.is_in_group("player"):
		collect()

func collect() -> void:
	collected = true
	
	# Hide sprite immediately
	sprite.visible = false
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

func is_collected() -> bool:
	return collected
