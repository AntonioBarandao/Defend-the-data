class_name LaserTurret
extends AnimatedSprite2D

signal placed(turret: AnimatedSprite2D)
signal upgraded(turret: AnimatedSprite2D, level: int)

const TowerSummonEffectScript := preload("res://Scripts/Effects/tower_summon_effect.gd")
const TOWER_GRAB_SIZE := Vector2(180, 180)
const PLACEMENT_HIGHLIGHT_SIZE := Vector2(180, 120)
const PLATFORM_VALID_COLOR := Color(0.1, 0.9, 0.25, 0.45)
const PLATFORM_INVALID_COLOR := Color(1.0, 0.1, 0.08, 0.45)
const MAX_LEVEL := 5
const LEVEL_POWERS := [1, 2, 3, 4, 5]
const LEVEL_RANGES := [260.0, 310.0, 450.0, 650.0, 800.0]
const LEVEL_COOLDOWNS := [0.82, 0.62, 0.52, 0.32, 0.05]
const LEVEL_LASER_WIDTHS := [7.0, 8.5, 10.0, 11.5, 13.0]
const LEVEL_UPGRADE_COSTS := [0, 500, 2000, 5000, 12000]
const LASER_COLOR := Color(0.1, 1.0, 0.72, 1.0)
const SHOT_RETURN_DELAY := 3.0
const RANGE_PREVIEW_SEGMENTS := 96
const RANGE_PREVIEW_FILL_COLOR := Color(0.27, 0.55, 1.0, 0.16)
const RANGE_PREVIEW_OUTLINE_COLOR := Color(0.48, 0.83, 1.0, 0.78)
const SUMMON_EFFECT_Z_OFFSET := -2
const DRAG_VALID_MODULATE := Color(0.42, 1.0, 0.46, 0.84)
const DRAG_INVALID_MODULATE := Color(1.0, 0.22, 0.2, 0.84)
const LASER_FX_STARTUP_ANIMATION := &"Laser_Startup_Shoot"
const LASER_FX_STOP_ANIMATION := &"Laser_Continuous_Stop"
const TOWER_VISUAL_Z_INDEX := 60
const PLATE_VISUAL_Z_INDEX := 59
const LEVEL_PLATE_NODE_NAMES := [
	"Level1Plate",
	"Level2Plate",
	"Level3Plate",
	"Level4Plate",
	"Level5Plate"
]

@export_range(1, MAX_LEVEL, 1) var level := 1
@export var placement_area_prefix := "TowerPlacementArea"
@export var placement_area_group := "tower_placement_area"
@export var platform_highlight_path: NodePath = ^"../../PlatformHighlight"
@export var forward_rotation_offset := PI * 0.5
@export var has_scanner_ability := false
@export var show_attack_range_preview := true
@export var range_preview_fill_color := RANGE_PREVIEW_FILL_COLOR
@export var range_preview_outline_color := RANGE_PREVIEW_OUTLINE_COLOR
@export_group("Laser Beam FX")
@export var beam_fx_path: NodePath = ^"LaserBeamFx"
@export_range(1.0, 2000.0, 1.0) var beam_fx_source_length := 620.0
@export_range(0.05, 4.0, 0.01) var beam_fx_scale_multiplier := 1.0
@export_group("")
@export_group("Audio")
@export var deploy_sfx_path: NodePath = ^"Audio/DeploySfx"
@export var upgrade_sfx_path: NodePath = ^"Audio/UpgradeSfx"
@export var upgrade_lv5_sfx_path: NodePath = ^"Audio/UpgradeLv5Sfx"
@export var shoot_lv1_sfx_path: NodePath = ^"Audio/ShootLv1Sfx"
@export var shoot_lv2_sfx_path: NodePath = ^"Audio/ShootLv2Sfx"
@export var shoot_lv3_sfx_path: NodePath = ^"Audio/ShootLv3Sfx"
@export var shoot_lv4_sfx_path: NodePath = ^"Audio/ShootLv4Sfx"
@export var shoot_lv5_sfx_path: NodePath = ^"Audio/ShootLv5Sfx"
@export_group("")

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
var _range_preview_fill: Polygon2D
var _range_preview_outline: Line2D
var _range_preview_radius := -1.0
var _range_preview_forced_time_remaining := 0.0
var _menu_range_preview_active := false
var _beam_fx_reference: AnimatedSprite2D
var _level_plates: Array[Sprite2D] = []
var _level_plate_local_offsets: Array[Vector2] = []
var _level_plate_local_scales: Array[Vector2] = []
var _level_plate_base_modulates: Array[Color] = []
var _deploy_sfx: AudioStreamPlayer
var _upgrade_sfx: AudioStreamPlayer
var _upgrade_lv5_sfx: AudioStreamPlayer
var _shoot_sfx_players: Array[AudioStreamPlayer] = []
var _base_modulate := Color.WHITE


func _ready() -> void:
	add_to_group("Defender")
	add_to_group("OFFENSE_TOWER")
	_home_position = global_position
	_rest_rotation = rotation
	_base_modulate = modulate
	_platform_highlight = get_node_or_null(platform_highlight_path) as ColorRect
	_beam_fx_reference = get_node_or_null(beam_fx_path) as AnimatedSprite2D
	_cache_audio_players()
	_cache_level_plates()
	_configure_level_plates()
	if _platform_highlight != null:
		_platform_highlight.hide()
	if _beam_fx_reference != null:
		_beam_fx_reference.hide()
	_apply_level_animation()
	_sync_level_plates_transform()


func _process(delta: float) -> void:
	_range_preview_forced_time_remaining = maxf(0.0, _range_preview_forced_time_remaining - delta)
	_sync_level_plates_transform()
	_update_attack_range_preview()


func _input(event: InputEvent) -> void:
	if _is_cutscene_input_locked():
		return

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


func get_occupied_placement_shape() -> CollisionShape2D:
	return _current_placement_shape if _placed else null


func can_upgrade() -> bool:
	return level < MAX_LEVEL


func upgrade() -> bool:
	if not can_upgrade():
		return false

	level += 1
	_shot_cooldown_remaining = 0.0
	_apply_level_animation()
	_play_audio_player(_upgrade_lv5_sfx if level == MAX_LEVEL else _upgrade_sfx)
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
	_clear_drag_feedback()
	_shot_cooldown_remaining = 0.0
	_shot_pose_active = false
	if _shot_return_tween != null:
		_shot_return_tween.kill()
		_shot_return_tween = null
	if _platform_highlight != null:
		_platform_highlight.hide()
	_set_range_preview_visible(false)
	_apply_level_animation()
	_sync_level_plates_transform()


func get_level() -> int:
	return level


func get_max_level() -> int:
	return MAX_LEVEL


func get_shot_power() -> int:
	return LEVEL_POWERS[level - 1]


func get_attack_range() -> float:
	return LEVEL_RANGES[level - 1]


func set_menu_range_preview_active(active: bool) -> void:
	_menu_range_preview_active = active
	_update_attack_range_preview()


func get_shot_cooldown() -> float:
	return LEVEL_COOLDOWNS[level - 1]


func get_laser_width() -> float:
	return LEVEL_LASER_WIDTHS[level - 1]


func get_laser_color() -> Color:
	return LASER_COLOR


func can_scan_cloaked_viruses() -> bool:
	return has_scanner_ability


func get_upgrade_cost() -> int:
	if not can_upgrade():
		return 0

	return int(LEVEL_UPGRADE_COSTS[level])


func has_beam_fx() -> bool:
	return _beam_fx_reference != null \
		and _beam_fx_reference.sprite_frames != null \
		and _beam_fx_reference.sprite_frames.has_animation(LASER_FX_STARTUP_ANIMATION) \
		and _beam_fx_reference.sprite_frames.has_animation(LASER_FX_STOP_ANIMATION)


func spawn_beam_fx(target_position: Vector2, fx_parent: Node) -> bool:
	if fx_parent == null or not has_beam_fx():
		return false

	var distance := _beam_fx_reference.global_position.distance_to(target_position)
	if distance <= 0.0:
		return false

	var beam := _beam_fx_reference.duplicate() as AnimatedSprite2D
	if beam == null:
		return false

	beam.name = "LaserTurretBeamFx"
	beam.visible = true
	beam.frame = 0
	beam.frame_progress = 0.0
	fx_parent.add_child(beam)

	beam.global_position = _beam_fx_reference.global_position
	beam.global_rotation = _beam_fx_reference.global_rotation
	var reference_scale := _beam_fx_reference.global_scale
	var source_world_scale := maxf(absf(reference_scale.x), 0.001)
	var source_world_length := maxf(1.0, beam_fx_source_length * source_world_scale)
	var fx_scale := (distance / source_world_length) * beam_fx_scale_multiplier
	beam.global_scale = reference_scale * fx_scale
	beam.animation_finished.connect(func() -> void:
		if not is_instance_valid(beam):
			return

		if beam.animation == LASER_FX_STARTUP_ANIMATION:
			beam.play(LASER_FX_STOP_ANIMATION)
		else:
			beam.queue_free()
	)
	beam.play(LASER_FX_STARTUP_ANIMATION)
	return true


func preview_attack_range(duration: float = 1.15) -> void:
	if not show_attack_range_preview:
		return

	_range_preview_forced_time_remaining = maxf(_range_preview_forced_time_remaining, duration)
	_range_preview_radius = -1.0
	_update_attack_range_preview()


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
	_play_shoot_sfx()
	_schedule_return_to_rest_state()


func _try_start_drag(pointer_position: Vector2) -> void:
	if not contains_global_point(pointer_position):
		return

	_dragging = true
	_drag_start_position = global_position
	_drag_offset = global_position - pointer_position
	if _platform_highlight != null:
		_platform_highlight.hide()
	_update_drag(pointer_position)
	get_viewport().set_input_as_handled()


func _update_drag(pointer_position: Vector2) -> void:
	global_position = pointer_position + _drag_offset
	_sync_level_plates_transform()
	_update_platform_highlight()
	get_viewport().set_input_as_handled()


func _finish_drag() -> void:
	if _drag_is_valid:
		global_position = _get_placement_area_center()
		_placed = true
		_apply_level_plate()
		_sync_level_plates_transform()
		_clear_drag_feedback()
		_play_audio_player(_deploy_sfx)
		_spawn_summon_effect()
		placed.emit(self)
	else:
		global_position = _drag_start_position
		_sync_level_plates_transform()
		_clear_drag_feedback()

	if _platform_highlight != null:
		_platform_highlight.hide()
	_dragging = false
	get_viewport().set_input_as_handled()


func _apply_level_animation() -> void:
	level = clampi(level, 1, MAX_LEVEL)
	_apply_level_plate()
	var animation_name := StringName("level_%d" % level)
	if sprite_frames == null or not sprite_frames.has_animation(animation_name):
		return

	animation = animation_name
	frame = 0
	frame_progress = 0.0
	play()


func _cache_level_plates() -> void:
	_level_plates.clear()
	_level_plate_local_offsets.clear()
	_level_plate_local_scales.clear()
	_level_plate_base_modulates.clear()
	for plate_name in LEVEL_PLATE_NODE_NAMES:
		var plate := get_node_or_null(NodePath(plate_name)) as Sprite2D
		_level_plates.append(plate)
		_level_plate_local_offsets.append(plate.position if plate != null else Vector2.ZERO)
		_level_plate_local_scales.append(plate.scale if plate != null else Vector2.ONE)
		_level_plate_base_modulates.append(plate.modulate if plate != null else Color.WHITE)


func _cache_audio_players() -> void:
	_deploy_sfx = get_node_or_null(deploy_sfx_path) as AudioStreamPlayer
	_upgrade_sfx = get_node_or_null(upgrade_sfx_path) as AudioStreamPlayer
	_upgrade_lv5_sfx = get_node_or_null(upgrade_lv5_sfx_path) as AudioStreamPlayer
	_shoot_sfx_players = [
		get_node_or_null(shoot_lv1_sfx_path) as AudioStreamPlayer,
		get_node_or_null(shoot_lv2_sfx_path) as AudioStreamPlayer,
		get_node_or_null(shoot_lv3_sfx_path) as AudioStreamPlayer,
		get_node_or_null(shoot_lv4_sfx_path) as AudioStreamPlayer,
		get_node_or_null(shoot_lv5_sfx_path) as AudioStreamPlayer
	]


func _configure_level_plates() -> void:
	z_index = maxi(z_index, TOWER_VISUAL_Z_INDEX)
	z_as_relative = false
	for plate in _level_plates:
		if plate == null:
			continue

		plate.top_level = true
		plate.show_behind_parent = false
		plate.z_index = PLATE_VISUAL_Z_INDEX
		plate.z_as_relative = false
		plate.global_rotation = 0.0

	_sync_level_plates_transform()


func _apply_level_plate() -> void:
	if _level_plates.is_empty():
		_cache_level_plates()
		_configure_level_plates()

	var target_index := clampi(level, 1, MAX_LEVEL) - 1
	for index in range(_level_plates.size()):
		var plate := _level_plates[index]
		if plate == null:
			continue

		plate.visible = index == target_index


func _sync_level_plates_transform() -> void:
	if _level_plates.is_empty():
		return

	for index in range(_level_plates.size()):
		var plate := _level_plates[index]
		if plate == null:
			continue

		var local_offset := Vector2.ZERO
		if index < _level_plate_local_offsets.size():
			local_offset = _level_plate_local_offsets[index]

		var local_scale := Vector2.ONE
		if index < _level_plate_local_scales.size():
			local_scale = _level_plate_local_scales[index]

		var scaled_offset := Vector2(local_offset.x * global_scale.x, local_offset.y * global_scale.y)
		var scaled_plate_scale := Vector2(global_scale.x * local_scale.x, global_scale.y * local_scale.y)
		plate.global_position = global_position + scaled_offset
		plate.global_rotation = 0.0
		plate.global_scale = scaled_plate_scale


func _play_shoot_sfx() -> void:
	var sound_index := clampi(level, 1, MAX_LEVEL) - 1
	if sound_index < 0 or sound_index >= _shoot_sfx_players.size():
		return

	_play_audio_player(_shoot_sfx_players[sound_index])


func _play_audio_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return

	player.stop()
	player.play()


func _update_platform_highlight() -> void:
	_current_placement_shape = _find_placement_shape_at_position(global_position)
	_drag_is_valid = _current_placement_shape != null and not _is_placement_shape_occupied(_current_placement_shape)
	_set_drag_feedback(_drag_is_valid)
	if _platform_highlight == null:
		return
	_platform_highlight.hide()


func _update_attack_range_preview() -> void:
	if not show_attack_range_preview:
		return

	var should_show := _range_preview_forced_time_remaining > 0.0 \
		or _dragging \
		or _menu_range_preview_active
	if not should_show:
		_set_range_preview_visible(false)
		return

	_ensure_range_preview()
	if _range_preview_fill == null or _range_preview_outline == null:
		return

	var attack_range := get_attack_range()
	if not is_equal_approx(_range_preview_radius, attack_range):
		_range_preview_radius = attack_range
		_range_preview_fill.polygon = _build_range_preview_points(attack_range, false)
		_range_preview_outline.points = _build_range_preview_points(attack_range, true)

	_range_preview_fill.global_position = global_position
	_range_preview_outline.global_position = global_position
	_set_range_preview_visible(true)


func _ensure_range_preview() -> void:
	if is_instance_valid(_range_preview_fill) and is_instance_valid(_range_preview_outline):
		return

	var game_root := _get_game_root()
	if game_root == null:
		return

	_range_preview_fill = Polygon2D.new()
	_range_preview_fill.name = "%sRangePreviewFill" % name
	_range_preview_fill.color = range_preview_fill_color
	_range_preview_fill.z_index = 42
	game_root.add_child(_range_preview_fill)

	_range_preview_outline = Line2D.new()
	_range_preview_outline.name = "%sRangePreviewOutline" % name
	_range_preview_outline.width = 3.0
	_range_preview_outline.default_color = range_preview_outline_color
	_range_preview_outline.joint_mode = Line2D.LINE_JOINT_ROUND
	_range_preview_outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_range_preview_outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	_range_preview_outline.antialiased = true
	_range_preview_outline.z_index = 43
	game_root.add_child(_range_preview_outline)

	_range_preview_radius = -1.0
	_set_range_preview_visible(false)


func _build_range_preview_points(radius: float, close_loop: bool) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(RANGE_PREVIEW_SEGMENTS):
		var angle := TAU * float(index) / float(RANGE_PREVIEW_SEGMENTS)
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	if close_loop and not points.is_empty():
		points.append(points[0])

	return points


func _set_range_preview_visible(visible: bool) -> void:
	if is_instance_valid(_range_preview_fill):
		_range_preview_fill.visible = visible
	if is_instance_valid(_range_preview_outline):
		_range_preview_outline.visible = visible


func _find_placement_shape_at_position(global_position_to_test: Vector2) -> CollisionShape2D:
	var game_root := _get_game_root()
	if game_root == null:
		return null

	for node in get_tree().get_nodes_in_group(placement_area_group):
		var area := node as Area2D
		if area == null or not game_root.is_ancestor_of(area):
			continue

		var grouped_shape := _find_placement_shape_in_area(area, global_position_to_test)
		if grouped_shape != null:
			return grouped_shape

	for child in game_root.get_children():
		var area := child as Area2D
		if area == null or not String(area.name).begins_with(placement_area_prefix):
			continue

		var prefixed_shape := _find_placement_shape_in_area(area, global_position_to_test)
		if prefixed_shape != null:
			return prefixed_shape

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


func _find_first_placement_shape_in_area(area: Area2D) -> CollisionShape2D:
	for area_child in area.get_children():
		var collision_shape := area_child as CollisionShape2D
		if collision_shape == null or collision_shape.disabled:
			continue

		if collision_shape.shape is RectangleShape2D:
			return collision_shape

	return null


func _get_platform_highlight_rect(placement_shape: CollisionShape2D) -> Rect2:
	if placement_shape != null:
		return _get_placement_shape_global_rect(placement_shape)

	var fallback_size := _get_default_placement_highlight_size()
	return Rect2(global_position - fallback_size * 0.5, fallback_size)


func _get_default_placement_highlight_size() -> Vector2:
	var game_root := _get_game_root()
	if game_root == null:
		return PLACEMENT_HIGHLIGHT_SIZE

	for node in get_tree().get_nodes_in_group(placement_area_group):
		var area := node as Area2D
		if area == null or not game_root.is_ancestor_of(area):
			continue

		var grouped_shape := _find_first_placement_shape_in_area(area)
		if grouped_shape != null:
			return _get_placement_shape_global_rect(grouped_shape).size

	for child in game_root.get_children():
		var area := child as Area2D
		if area == null or not String(area.name).begins_with(placement_area_prefix):
			continue

		var prefixed_shape := _find_first_placement_shape_in_area(area)
		if prefixed_shape != null:
			return _get_placement_shape_global_rect(prefixed_shape).size

	return PLACEMENT_HIGHLIGHT_SIZE


func _get_placement_shape_global_rect(placement_shape: CollisionShape2D) -> Rect2:
	var rectangle_shape := placement_shape.shape as RectangleShape2D
	if rectangle_shape == null:
		return Rect2(placement_shape.global_position - PLACEMENT_HIGHLIGHT_SIZE * 0.5, PLACEMENT_HIGHLIGHT_SIZE)

	var half_size := rectangle_shape.size * 0.5
	var corners := [
		placement_shape.global_transform * Vector2(-half_size.x, -half_size.y),
		placement_shape.global_transform * Vector2(half_size.x, -half_size.y),
		placement_shape.global_transform * Vector2(half_size.x, half_size.y),
		placement_shape.global_transform * Vector2(-half_size.x, half_size.y),
	]
	var rect := Rect2(corners[0], Vector2.ZERO)
	for corner in corners:
		rect = rect.expand(corner)

	return rect


func _get_placement_area_center() -> Vector2:
	if _current_placement_shape != null:
		return _current_placement_shape.global_position

	return global_position


func _is_placement_shape_occupied(placement_shape: CollisionShape2D) -> bool:
	if placement_shape == null:
		return false

	for node in get_tree().get_nodes_in_group("Defender"):
		if node == self or not is_instance_valid(node):
			continue
		if not node.has_method("get_occupied_placement_shape"):
			continue

		var occupied_shape := node.call("get_occupied_placement_shape") as CollisionShape2D
		if occupied_shape == placement_shape:
			return true

	return false


func _set_drag_feedback(valid: bool) -> void:
	var feedback_color := DRAG_VALID_MODULATE if valid else DRAG_INVALID_MODULATE
	modulate = feedback_color
	for plate in _level_plates:
		if plate != null:
			plate.modulate = feedback_color


func _clear_drag_feedback() -> void:
	modulate = _base_modulate
	for index in range(_level_plates.size()):
		var plate := _level_plates[index]
		if plate == null:
			continue

		var base_plate_modulate := Color.WHITE
		if index < _level_plate_base_modulates.size():
			base_plate_modulate = _level_plate_base_modulates[index]
		plate.modulate = base_plate_modulate


func _spawn_summon_effect() -> void:
	var game_root := _get_game_root()
	if game_root == null:
		return

	var effect := TowerSummonEffectScript.new() as Node2D
	effect.name = "%sSummonEffect" % name
	game_root.add_child(effect)
	effect.global_position = global_position
	effect.z_index = z_index + SUMMON_EFFECT_Z_OFFSET
	effect.z_as_relative = false


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
		if not _can_target_follow(follow):
			continue

		var target_position := _get_follow_target_position(follow)
		var distance_squared := global_position.distance_squared_to(target_position)
		if distance_squared > range_squared or distance_squared >= best_distance_squared:
			continue

		best_target = follow
		best_distance_squared = distance_squared

	return best_target


func _can_target_follow(follow: PathFollow2D) -> bool:
	var virus := _get_follow_virus(follow)
	return virus == null or virus.can_be_targeted_by(self)


func _get_follow_virus(follow: PathFollow2D) -> RedVirus:
	for child in follow.get_children():
		var virus := child as RedVirus
		if virus != null:
			return virus

	return null


func _get_follow_target_position(follow: PathFollow2D) -> Vector2:
	var virus := _get_follow_virus(follow)
	if virus != null:
		return virus.global_position

	return follow.global_position


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


func _is_cutscene_input_locked() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false

	var cutscene := scene.get_node_or_null(^"TextCutscene")
	return cutscene != null and cutscene.has_method("is_cutscene_running") and bool(cutscene.call("is_cutscene_running"))


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
