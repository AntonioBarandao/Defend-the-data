class_name CyberGuardianTower
extends AnimatedSprite2D

signal placed(tower: CyberGuardianTower)

const IDLE_ANIMATION := &"idle"
const SUMMON_ANIMATION := &"SummonAnim"
const SHOOT_ANIMATION := &"ShootAnim"
const GRAB_SIZE := Vector2(240, 180)
const PLACEMENT_HIGHLIGHT_SIZE := Vector2(180, 120)
const PLATFORM_VALID_COLOR := Color(0.1, 0.9, 0.25, 0.45)
const PLATFORM_INVALID_COLOR := Color(1.0, 0.1, 0.08, 0.45)
const ATTACK_RANGE := 250.0
const SHOT_COOLDOWN := 0.5
const SHOT_RETURN_DELAY := 3.0
const LASER_WIDTH := 10.0

@export var default_scale := 0.3
@export var placement_area_prefix := "TowerPlacementArea"
@export var platform_highlight_path: NodePath = ^"../../PlatformHighlight"
@export var forward_rotation_offset := PI * 0.5

var _asset_cache: Node
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
	_drag_start_position = _home_position
	_rest_rotation = rotation
	_platform_highlight = get_node_or_null(platform_highlight_path) as ColorRect
	if _platform_highlight != null:
		_platform_highlight.hide()

	if not animation_finished.is_connected(_return_to_idle):
		animation_finished.connect(_return_to_idle)

	if _has_required_animations(sprite_frames):
		play_animation(IDLE_ANIMATION)
		return

	_asset_cache = get_node_or_null("/root/AssetCache")
	if _asset_cache == null:
		push_error("AssetCache autoload was not found.")
		return

	if _asset_cache.has_cyber_guardian_animations():
		_apply_sprite_frames(_asset_cache.cyber_guardian_sprite_frames)
		return

	_asset_cache.cyber_guardian_animations_ready.connect(_apply_sprite_frames, CONNECT_ONE_SHOT)
	_asset_cache.load_startup_resources()


func is_placed() -> bool:
	return _placed


func is_dragging() -> bool:
	return _dragging


func try_start_drag(pointer_position: Vector2) -> bool:
	if _placed or not contains_global_point(pointer_position):
		return false

	_dragging = true
	_drag_start_position = global_position
	_drag_offset = global_position - pointer_position
	if _platform_highlight != null:
		_platform_highlight.show()
	update_drag(pointer_position)
	get_viewport().set_input_as_handled()
	return true


func update_drag(pointer_position: Vector2) -> void:
	if not _dragging:
		return

	global_position = pointer_position + _drag_offset
	_update_platform_highlight()
	get_viewport().set_input_as_handled()


func finish_drag() -> bool:
	if not _dragging:
		return false

	var was_placed := false
	if _drag_is_valid:
		global_position = _get_placement_area_center()
		_placed = true
		was_placed = true
		play_summon()
		placed.emit(self)
	else:
		global_position = _drag_start_position

	if _platform_highlight != null:
		_platform_highlight.hide()
	_dragging = false
	get_viewport().set_input_as_handled()
	return was_placed


func reset_tower() -> void:
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
	play_animation(IDLE_ANIMATION)


func set_tower_scale(value: float) -> void:
	default_scale = value
	scale = Vector2.ONE * default_scale
	if _dragging:
		_update_platform_highlight()


func get_tower_scale() -> float:
	return scale.x


func get_laser_width() -> float:
	return LASER_WIDTH


func update_attack(delta: float, active_viruses: Array[PathFollow2D]) -> PathFollow2D:
	if not _placed:
		_return_to_rest_state_if_not_shooting()
		return null

	_shot_cooldown_remaining = maxf(0.0, _shot_cooldown_remaining - delta)
	if _shot_cooldown_remaining > 0.0:
		_return_to_rest_state_if_not_shooting()
		return null

	var target := _find_nearest_virus_in_range(active_viruses)
	if target == null:
		_return_to_rest_state_if_not_shooting()
		return null

	_shot_cooldown_remaining = SHOT_COOLDOWN
	return target


func contains_global_point(pointer_position: Vector2) -> bool:
	return get_tower_rect().has_point(pointer_position)


func get_tower_rect() -> Rect2:
	var size := PLACEMENT_HIGHLIGHT_SIZE
	if sprite_frames != null and sprite_frames.has_animation(animation):
		var texture := sprite_frames.get_frame_texture(animation, frame)
		if texture != null:
			var current_scale := global_scale
			size = texture.get_size() * Vector2(abs(current_scale.x), abs(current_scale.y))

	size.x = max(size.x, GRAB_SIZE.x)
	size.y = max(size.y, GRAB_SIZE.y)

	var top_left := global_position - size * 0.5
	if not centered:
		top_left = global_position

	return Rect2(top_left, size)


func aim_at(target_position: Vector2) -> void:
	var direction := target_position - global_position
	if direction.length_squared() > 0.0:
		rotation = direction.angle() - forward_rotation_offset


func play_animation(animation_name: StringName) -> void:
	if sprite_frames == null or not sprite_frames.has_animation(animation_name):
		return

	animation = animation_name
	frame = 0
	frame_progress = 0.0
	play()


func play_summon() -> void:
	play_animation(SUMMON_ANIMATION)


func play_idle() -> void:
	play_animation(IDLE_ANIMATION)


func play_shoot() -> void:
	play_animation(SHOOT_ANIMATION)
	_schedule_return_to_rest_state()


func _find_nearest_virus_in_range(active_viruses: Array[PathFollow2D]) -> PathFollow2D:
	var best_target: PathFollow2D
	var best_distance_squared := INF
	var range_squared := ATTACK_RANGE * ATTACK_RANGE

	for follow in active_viruses:
		if not is_instance_valid(follow):
			continue

		var distance_squared := global_position.distance_squared_to(follow.global_position)
		if distance_squared > range_squared or distance_squared >= best_distance_squared:
			continue

		best_target = follow
		best_distance_squared = distance_squared

	return best_target


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

		var shape := _find_placement_shape_in_area(area, global_position_to_test)
		if shape != null:
			return shape

	return null


func _find_placement_shape_in_area(area: Area2D, global_position_to_test: Vector2) -> CollisionShape2D:
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


func _get_game_root() -> Node:
	var node: Node = self
	while node != null:
		if node.get_node_or_null(^"TowerPlacementArea") != null:
			return node
		node = node.get_parent()

	return get_tree().current_scene


func _apply_sprite_frames(frames: SpriteFrames) -> void:
	sprite_frames = frames
	play_animation(IDLE_ANIMATION)


func _has_required_animations(frames: SpriteFrames) -> bool:
	return frames != null \
		and frames.has_animation(IDLE_ANIMATION) \
		and frames.has_animation(SUMMON_ANIMATION) \
		and frames.has_animation(SHOOT_ANIMATION)


func _return_to_idle() -> void:
	if animation != IDLE_ANIMATION:
		play_animation(IDLE_ANIMATION)


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
	if animation == SHOOT_ANIMATION:
		play_idle()
