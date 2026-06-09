class_name LaserTurret
extends AnimatedSprite2D

signal placed(turret: AnimatedSprite2D)
signal upgraded(turret: AnimatedSprite2D, level: int)

const TOWER_GRAB_SIZE := Vector2(180, 180)
const PLACEMENT_HIGHLIGHT_SIZE := Vector2(180, 120)
const PLATFORM_VALID_COLOR := Color(0.1, 0.9, 0.25, 0.45)
const PLATFORM_INVALID_COLOR := Color(1.0, 0.1, 0.08, 0.45)
const MAX_LEVEL := 5
const LEVEL_POWERS := [1, 2, 3, 4, 5]
const LEVEL_RANGES := [260.0, 310.0, 360.0, 420.0, 480.0]
const LEVEL_COOLDOWNS := [0.82, 0.72, 0.62, 0.52, 0.42]
const LEVEL_LASER_WIDTHS := [7.0, 8.5, 10.0, 11.5, 13.0]
const LASER_COLOR := Color(0.1, 1.0, 0.72, 1.0)
const SHOT_RETURN_DELAY := 3.0

@export var default_scale := 0.3
@export_range(1, MAX_LEVEL, 1) var level := 1
@export var placement_area_prefix := "TowerPlacementArea"
@export var platform_highlight_path: NodePath = ^"../../PlatformHighlight"
@export var forward_rotation_offset := PI * 0.5

var _home_position := Vector2.ZERO
var _dragging := false
var _placed := false
var _drag_start_position := Vector2.ZERO
var _drag_offset := Vector2.ZERO
var _drag_is_valid := false
var _current_placement_shape: CollisionShape2D
var _platform_highlight: ColorRect
var _shot_cooldown_remaining := 0.0
var _rest_rotation := 0.0
var _shot_pose_active := false
var _shot_return_tween: Tween


func _ready() -> void:
	scale = Vector2.ONE * default_scale
	_home_position = global_position
	_rest_rotation = rotation
	_platform_highlight = get_node_or_null(platform_highlight_path) as ColorRect
	if _platform_highlight != null:
		_platform_highlight.hide()
	_apply_level_animation()


func _input(event: InputEvent) -> void:
	if _placed:
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return

		var pointer_position := _screen_to_canvas_position(mouse_button.position)
		if mouse_button.pressed:
			_try_start_drag(pointer_position)
		elif _dragging:
			_finish_drag()
		return

	if event is InputEventMouseMotion and _dragging:
		var mouse_motion := event as InputEventMouseMotion
		_update_drag(_screen_to_canvas_position(mouse_motion.position))
		return

	if event is InputEventScreenTouch:
		var screen_touch := event as InputEventScreenTouch
		var pointer_position := _screen_to_canvas_position(screen_touch.position)
		if screen_touch.pressed:
			_try_start_drag(pointer_position)
		elif _dragging:
			_finish_drag()
		return

	if event is InputEventScreenDrag and _dragging:
		var screen_drag := event as InputEventScreenDrag
		_update_drag(_screen_to_canvas_position(screen_drag.position))


func is_placed() -> bool:
	return _placed


func can_upgrade() -> bool:
	return level < MAX_LEVEL


func upgrade() -> bool:
	if not can_upgrade():
		return false

	level += 1
	_shot_cooldown_remaining = 0.0
	_apply_level_animation()
	upgraded.emit(self, level)
	return true


func reset_tower() -> void:
	level = 1
	global_position = _home_position
	rotation = _rest_rotation
	_dragging = false
	_placed = false
	_drag_is_valid = false
	_drag_offset = Vector2.ZERO
	_drag_start_position = _home_position
	_current_placement_shape = null
	_shot_cooldown_remaining = 0.0
	_shot_pose_active = false
	if _shot_return_tween != null:
		_shot_return_tween.kill()
		_shot_return_tween = null
	if _platform_highlight != null:
		_platform_highlight.hide()
	_apply_level_animation()


func get_level() -> int:
	return level


func get_max_level() -> int:
	return MAX_LEVEL


func get_shot_power() -> int:
	return LEVEL_POWERS[level - 1]


func get_attack_range() -> float:
	return LEVEL_RANGES[level - 1]


func get_shot_cooldown() -> float:
	return LEVEL_COOLDOWNS[level - 1]


func get_laser_width() -> float:
	return LEVEL_LASER_WIDTHS[level - 1]


func get_laser_color() -> Color:
	return LASER_COLOR


func update_attack(delta: float, active_viruses: Array[PathFollow2D]) -> Array[PathFollow2D]:
	var targets: Array[PathFollow2D] = []
	if not _placed:
		_return_to_rest_state_if_not_shooting()
		return targets

	_shot_cooldown_remaining = maxf(0.0, _shot_cooldown_remaining - delta)
	if _shot_cooldown_remaining > 0.0:
		_return_to_rest_state_if_not_shooting()
		return targets

	targets = _find_nearest_viruses_in_range(active_viruses, get_shot_power())
	if targets.is_empty():
		_return_to_rest_state_if_not_shooting()
		return targets

	_shot_cooldown_remaining = get_shot_cooldown()
	return targets


func contains_global_point(pointer_position: Vector2) -> bool:
	return _get_tower_rect().has_point(pointer_position)


func aim_at(target_position: Vector2) -> void:
	var direction := target_position - global_position
	if direction.length_squared() > 0.0:
		rotation = direction.angle() - forward_rotation_offset


func mark_shot_fired() -> void:
	_schedule_return_to_rest_state()


func _try_start_drag(pointer_position: Vector2) -> void:
	if not contains_global_point(pointer_position):
		return

	_dragging = true
	_drag_start_position = global_position
	_drag_offset = global_position - pointer_position
	if _platform_highlight != null:
		_platform_highlight.show()
	_update_drag(pointer_position)
	get_viewport().set_input_as_handled()


func _update_drag(pointer_position: Vector2) -> void:
	global_position = pointer_position + _drag_offset
	_update_platform_highlight()
	get_viewport().set_input_as_handled()


func _finish_drag() -> void:
	if _drag_is_valid:
		global_position = _get_placement_area_center()
		_placed = true
		placed.emit(self)
	else:
		global_position = _drag_start_position

	if _platform_highlight != null:
		_platform_highlight.hide()
	_dragging = false
	get_viewport().set_input_as_handled()


func _apply_level_animation() -> void:
	level = clampi(level, 1, MAX_LEVEL)
	var animation_name := StringName("level_%d" % level)
	if sprite_frames == null or not sprite_frames.has_animation(animation_name):
		return

	animation = animation_name
	frame = 0
	frame_progress = 0.0
	play()


func _update_platform_highlight() -> void:
	if _platform_highlight == null:
		return

	_platform_highlight.size = PLACEMENT_HIGHLIGHT_SIZE
	_platform_highlight.global_position = global_position - PLACEMENT_HIGHLIGHT_SIZE * 0.5
	_current_placement_shape = _find_placement_shape_at_position(global_position)
	_drag_is_valid = _current_placement_shape != null
	_platform_highlight.color = PLATFORM_VALID_COLOR if _drag_is_valid else PLATFORM_INVALID_COLOR


func _find_placement_shape_at_position(global_position_to_test: Vector2) -> CollisionShape2D:
	var game_root := _get_game_root()
	if game_root == null:
		return null

	for child in game_root.get_children():
		var area := child as Area2D
		if area == null or not String(area.name).begins_with(placement_area_prefix):
			continue

		for area_child in area.get_children():
			var collision_shape := area_child as CollisionShape2D
			if collision_shape == null or collision_shape.disabled:
				continue

			var rectangle_shape := collision_shape.shape as RectangleShape2D
			if rectangle_shape == null:
				continue

			var local_position := collision_shape.global_transform.affine_inverse() * global_position_to_test
			var rectangle := Rect2(-rectangle_shape.size * 0.5, rectangle_shape.size)
			if rectangle.has_point(local_position):
				return collision_shape

	return null


func _get_placement_area_center() -> Vector2:
	if _current_placement_shape != null:
		return _current_placement_shape.global_position

	return global_position


func _find_nearest_viruses_in_range(active_viruses: Array[PathFollow2D], max_targets: int) -> Array[PathFollow2D]:
	var targets: Array[PathFollow2D] = []
	if max_targets <= 0:
		return targets

	while targets.size() < max_targets:
		var target := _find_nearest_virus_in_range_excluding(active_viruses, targets)
		if target == null:
			break
		targets.append(target)

	return targets


func _find_nearest_virus_in_range_excluding(
	active_viruses: Array[PathFollow2D],
	excluded_targets: Array[PathFollow2D]
) -> PathFollow2D:
	var best_target: PathFollow2D
	var best_distance_squared := INF
	var range := get_attack_range()
	var range_squared := range * range

	for follow in active_viruses:
		if not is_instance_valid(follow) or excluded_targets.has(follow):
			continue

		var distance_squared := global_position.distance_squared_to(follow.global_position)
		if distance_squared > range_squared or distance_squared >= best_distance_squared:
			continue

		best_target = follow
		best_distance_squared = distance_squared

	return best_target


func _get_game_root() -> Node:
	var node: Node = self
	while node != null:
		if node.get_node_or_null(^"TowerPlacementArea") != null:
			return node
		node = node.get_parent()

	return get_tree().current_scene


func _get_tower_rect() -> Rect2:
	var size := TOWER_GRAB_SIZE
	if sprite_frames != null and sprite_frames.has_animation(animation):
		var texture := sprite_frames.get_frame_texture(animation, frame)
		if texture != null:
			var current_scale := global_scale
			size = texture.get_size() * Vector2(abs(current_scale.x), abs(current_scale.y))

	size.x = max(size.x, TOWER_GRAB_SIZE.x)
	size.y = max(size.y, TOWER_GRAB_SIZE.y)

	var top_left := global_position - size * 0.5
	if not centered:
		top_left = global_position

	return Rect2(top_left, size)


func _screen_to_canvas_position(screen_position: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_position


func _schedule_return_to_rest_state() -> void:
	if _shot_return_tween != null:
		_shot_return_tween.kill()

	_shot_pose_active = true
	_shot_return_tween = create_tween()
	_shot_return_tween.tween_interval(SHOT_RETURN_DELAY)
	_shot_return_tween.tween_callback(Callable(self, "_return_to_rest_state"))


func _return_to_rest_state_if_not_shooting() -> void:
	if _shot_pose_active:
		return

	_return_to_rest_state()


func _return_to_rest_state() -> void:
	_shot_pose_active = false
	rotation = _rest_rotation
