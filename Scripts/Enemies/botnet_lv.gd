class_name BotnetLV
extends Node2D

const MOVEMENT_PHASE_1 := &"Movement Phase 1: Scatter"
const MOVEMENT_PHASE_END := &"Movement Phase End: Return"

@export var max_health := 300
@export_range(0.2, 10.0, 0.1) var spawn_log_interval := 4.0
@export_range(4.0, 180.0, 1.0) var scatter_radius := 42.0
@export_range(0.1, 3.0, 0.05) var scatter_move_duration := 0.72
@export_range(0.1, 3.0, 0.05) var scatter_return_duration := 0.58
@export_group("Health Bar")
@export var health_bar_root_path: NodePath = ^"MinibossHealthBar"
@export var health_bar_follow_sprite_bounds := true
@export var health_bar_offset := Vector2.ZERO
@export_range(0.0, 220.0, 1.0) var health_bar_vertical_gap := 26.0
@export_group("")
@export var active := false:
	set(value):
		active = value
		visible = active
		set_process(active)
		_set_health_bar_visible(active)
		if active:
			_start_scatter_loop()
		else:
			_stop_scatter_loop()

var current_health := 300
var movement_phase: StringName = MOVEMENT_PHASE_END
var _elapsed_time := 0.0
var _spawn_log_elapsed := 0.0
var _anchor_global_position := Vector2.ZERO
var _movement_tween: Tween
var _health_bar: TrojanHorseProgressBar
@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_anchor_global_position = global_position
	current_health = maxi(1, max_health)
	_ensure_health_bar()
	_set_health_bar_health(current_health, max_health, false)
	visible = active
	_set_health_bar_visible(active)
	set_process(active)
	if active:
		_start_scatter_loop()


func _process(delta: float) -> void:
	if not active:
		return

	_position_health_bar()
	_elapsed_time += delta
	_spawn_log_elapsed += delta
	if _spawn_log_elapsed >= spawn_log_interval:
		_spawn_log_elapsed = 0.0
		print("botnet spawn at elapsed time %.2f" % _elapsed_time)


func activate_at_position(target_global_position: Vector2) -> void:
	global_position = target_global_position
	_anchor_global_position = target_global_position
	_elapsed_time = 0.0
	_spawn_log_elapsed = 0.0
	current_health = maxi(1, max_health)
	_ensure_health_bar()
	_set_health_bar_health(current_health, max_health, false)
	active = true
	_position_health_bar()


func deactivate() -> void:
	active = false
	global_position = _anchor_global_position


func _start_scatter_loop() -> void:
	_stop_scatter_loop()
	if not active or not is_inside_tree():
		return

	_start_movement_phase_1()


func _stop_scatter_loop() -> void:
	if _movement_tween != null:
		_movement_tween.kill()
		_movement_tween = null
	movement_phase = MOVEMENT_PHASE_END


func _start_movement_phase_1() -> void:
	if not active or not is_inside_tree():
		return

	movement_phase = MOVEMENT_PHASE_1
	var scatter_offset := Vector2(randf_range(-scatter_radius, scatter_radius), randf_range(-scatter_radius * 0.55, scatter_radius * 0.55))
	var target_position := _anchor_global_position + scatter_offset
	_movement_tween = create_tween()
	_movement_tween.tween_property(self, "global_position", target_position, scatter_move_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_movement_tween.tween_callback(Callable(self, "_start_movement_phase_end"))


func _start_movement_phase_end() -> void:
	if not active or not is_inside_tree():
		return

	movement_phase = MOVEMENT_PHASE_END
	_movement_tween = create_tween()
	_movement_tween.tween_property(self, "global_position", _anchor_global_position, scatter_return_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_movement_tween.tween_callback(Callable(self, "_start_movement_phase_1"))


func _ensure_health_bar() -> void:
	if is_instance_valid(_health_bar):
		return

	_health_bar = get_node_or_null(health_bar_root_path) as TrojanHorseProgressBar
	if not is_instance_valid(_health_bar):
		return

	_health_bar.top_level = true
	_health_bar.z_index = maxi(_health_bar.z_index, 700)
	_health_bar.modulate = Color.WHITE


func _set_health_bar_visible(value: bool) -> void:
	_ensure_health_bar()
	if not is_instance_valid(_health_bar):
		return

	_health_bar.set_bar_visible(value)


func _set_health_bar_health(current: int, maximum: int, animate: bool) -> void:
	_ensure_health_bar()
	if not is_instance_valid(_health_bar):
		return

	_health_bar.set_health(current, maxi(1, maximum), animate)


func _position_health_bar() -> void:
	if not is_instance_valid(_health_bar):
		return

	var target_position := global_position
	if health_bar_follow_sprite_bounds:
		target_position = _get_health_bar_follow_position()

	_health_bar.global_position = target_position + health_bar_offset
	_health_bar.global_rotation = 0.0


func _get_health_bar_follow_position() -> Vector2:
	var sprite_bounds := _get_sprite_global_bounds()
	return Vector2(
		sprite_bounds.position.x + sprite_bounds.size.x * 0.5,
		sprite_bounds.position.y - health_bar_vertical_gap
	)


func _get_sprite_global_bounds() -> Rect2:
	if _sprite == null or _sprite.texture == null:
		var fallback_size := Vector2(128, 128) * global_scale.abs()
		return Rect2(global_position - fallback_size * 0.5, fallback_size)

	var texture_size := _sprite.texture.get_size()
	var local_top_left := -texture_size * 0.5 if _sprite.centered else Vector2.ZERO
	local_top_left += _sprite.offset
	var corners := [
		local_top_left,
		local_top_left + Vector2(texture_size.x, 0.0),
		local_top_left + texture_size,
		local_top_left + Vector2(0.0, texture_size.y)
	]
	var bounds := Rect2(_sprite.global_transform * corners[0], Vector2.ZERO)
	for corner in corners:
		bounds = bounds.expand(_sprite.global_transform * corner)

	return bounds
