class_name IDSScannerTower
extends AnimatedSprite2D

signal placed(scanner: IDSScannerTower)

const TowerSummonEffectScript := preload("res://Scripts/Effects/tower_summon_effect.gd")
const IDLE_ANIMATION := &"idle"
const CYBER_GUARDIAN_LEVEL_ONE_RADIUS := 250.0
const RADAR_SEGMENTS := 96
const SWEEP_HALF_ANGLE := PI / 10.0
const TOWER_GRAB_SIZE := Vector2(180, 180)
const PLACEMENT_HIGHLIGHT_SIZE := Vector2(180, 120)
const SUMMON_EFFECT_Z_OFFSET := -2
const DRAG_VALID_MODULATE := Color(0.42, 1.0, 0.46, 0.84)
const DRAG_INVALID_MODULATE := Color(1.0, 0.22, 0.2, 0.84)

@export var deployed := false:
	set(value):
		deployed = value
		_sync_deployed_state()
@export var placement_area_prefix := "TowerPlacementArea"
@export var placement_area_group := "tower_placement_area"
@export var platform_highlight_path: NodePath = ^"../../PlatformHighlight"
@export_range(32.0, 1200.0, 1.0) var scan_radius := CYBER_GUARDIAN_LEVEL_ONE_RADIUS:
	set(value):
		scan_radius = value
		_rebuild_radar_geometry()
@export_range(0.1, 8.0, 0.05) var radar_rotation_speed := 1.35
@export var radar_fill_color := Color(0.0, 1.0, 0.35, 0.08)
@export var radar_outline_color := Color(0.28, 1.0, 0.48, 0.58)
@export var radar_sweep_color := Color(0.4, 1.0, 0.5, 0.34)
@export var radar_line_color := Color(0.65, 1.0, 0.68, 0.92)

var _radar_root: Node2D
var _radar_fill: Polygon2D
var _radar_outline: Line2D
var _radar_sweep: Polygon2D
var _radar_line: Line2D
var _sweep_angle := 0.0
var _home_position := Vector2.ZERO
var _dragging := false
var _drag_start_position := Vector2.ZERO
var _drag_offset := Vector2.ZERO
var _drag_is_valid := false
var _current_placement_shape: CollisionShape2D
var _platform_highlight: ColorRect
var _base_modulate := Color.WHITE


func _ready() -> void:
	add_to_group("Defender")
	add_to_group("SUPPORT_TOWER")
	_home_position = global_position
	_drag_start_position = _home_position
	_base_modulate = modulate
	_platform_highlight = get_node_or_null(platform_highlight_path) as ColorRect
	if _platform_highlight != null:
		_platform_highlight.hide()
	if sprite_frames != null and sprite_frames.has_animation(IDLE_ANIMATION):
		play(IDLE_ANIMATION)
	_ensure_radar_nodes()
	_sync_deployed_state()
	set_process(true)


func _process(delta: float) -> void:
	if not deployed:
		return

	_sweep_angle = wrapf(_sweep_angle + radar_rotation_speed * TAU * delta, 0.0, TAU)
	_update_radar_transform()
	_update_sweep_geometry()


func _input(event: InputEvent) -> void:
	if deployed or _is_cutscene_input_locked():
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


func deploy() -> void:
	deployed = true
	add_to_group("SUPPORT_TOWER")
	_sync_deployed_state()


func is_deployed() -> bool:
	return deployed


func is_dragging() -> bool:
	return _dragging


func get_occupied_placement_shape() -> CollisionShape2D:
	return _current_placement_shape if deployed else null


func reset_tower() -> void:
	global_position = _home_position
	deployed = false
	_dragging = false
	_drag_is_valid = false
	_drag_offset = Vector2.ZERO
	_drag_start_position = _home_position
	_current_placement_shape = null
	_clear_drag_feedback()
	if _platform_highlight != null:
		_platform_highlight.hide()
	_sync_deployed_state()


func can_scan_cloaked_viruses() -> bool:
	return true


func get_scan_radius() -> float:
	return scan_radius


func update_support_scan(active_viruses: Array[PathFollow2D], _delta: float) -> void:
	if not deployed:
		return

	var radius_squared := scan_radius * scan_radius
	for follow in active_viruses:
		if not is_instance_valid(follow):
			continue

		var trojan := _get_trojan_horse(follow)
		if trojan == null or not trojan.is_cloaked():
			continue
		if global_position.distance_squared_to(trojan.global_position) > radius_squared:
			continue

		trojan.reveal_from_scanner(self)


func contains_global_point(pointer_position: Vector2) -> bool:
	return _get_tower_rect().has_point(pointer_position)


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
	if not _dragging:
		return

	global_position = pointer_position + _drag_offset
	_update_platform_highlight()
	get_viewport().set_input_as_handled()


func _finish_drag() -> void:
	if not _dragging:
		return

	if _drag_is_valid:
		global_position = _get_placement_area_center()
		deploy()
		_clear_drag_feedback()
		_spawn_summon_effect()
		placed.emit(self)
	else:
		global_position = _drag_start_position
		_clear_drag_feedback()

	if _platform_highlight != null:
		_platform_highlight.hide()
	_dragging = false
	get_viewport().set_input_as_handled()


func _ensure_radar_nodes() -> void:
	if is_instance_valid(_radar_root):
		return

	_radar_root = Node2D.new()
	_radar_root.name = "RadarScannerRadius"
	_radar_root.top_level = true
	_radar_root.z_index = 45
	_radar_root.z_as_relative = false
	add_child(_radar_root)

	_radar_fill = Polygon2D.new()
	_radar_fill.name = "RadiusFill"
	_radar_fill.color = radar_fill_color
	_radar_root.add_child(_radar_fill)

	_radar_sweep = Polygon2D.new()
	_radar_sweep.name = "RotatingSweep"
	_radar_sweep.color = radar_sweep_color
	_radar_root.add_child(_radar_sweep)

	_radar_outline = Line2D.new()
	_radar_outline.name = "RadiusOutline"
	_radar_outline.width = 3.0
	_radar_outline.default_color = radar_outline_color
	_radar_outline.antialiased = true
	_radar_outline.joint_mode = Line2D.LINE_JOINT_ROUND
	_radar_root.add_child(_radar_outline)

	_radar_line = Line2D.new()
	_radar_line.name = "SweepLine"
	_radar_line.width = 4.0
	_radar_line.default_color = radar_line_color
	_radar_line.antialiased = true
	_radar_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_radar_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_radar_root.add_child(_radar_line)

	_rebuild_radar_geometry()


func _rebuild_radar_geometry() -> void:
	if not is_instance_valid(_radar_fill):
		return

	_radar_fill.polygon = _build_circle_points(scan_radius, false)
	_radar_outline.points = _build_circle_points(scan_radius, true)
	_update_sweep_geometry()


func _build_circle_points(radius: float, close_loop: bool) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(RADAR_SEGMENTS):
		var angle := TAU * float(index) / float(RADAR_SEGMENTS)
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	if close_loop and not points.is_empty():
		points.append(points[0])

	return points


func _update_radar_transform() -> void:
	_ensure_radar_nodes()
	if not is_instance_valid(_radar_root):
		return

	_radar_root.global_position = global_position
	_radar_root.global_rotation = 0.0


func _update_sweep_geometry() -> void:
	if not is_instance_valid(_radar_sweep):
		return

	var points := PackedVector2Array([Vector2.ZERO])
	var sweep_segments := 10
	for index in range(sweep_segments + 1):
		var t := float(index) / float(sweep_segments)
		var angle := _sweep_angle - SWEEP_HALF_ANGLE + (SWEEP_HALF_ANGLE * 2.0 * t)
		points.append(Vector2(cos(angle), sin(angle)) * scan_radius)

	_radar_sweep.polygon = points
	_radar_line.points = PackedVector2Array([
		Vector2.ZERO,
		Vector2(cos(_sweep_angle), sin(_sweep_angle)) * scan_radius
	])


func _sync_deployed_state() -> void:
	if not is_inside_tree():
		return

	_ensure_radar_nodes()
	if is_instance_valid(_radar_root):
		_radar_root.visible = deployed
	_update_radar_transform()


func _update_platform_highlight() -> void:
	_current_placement_shape = _find_placement_shape_at_position(global_position)
	_drag_is_valid = _current_placement_shape != null and not _is_placement_shape_occupied(_current_placement_shape)
	_set_drag_feedback(_drag_is_valid)
	if _platform_highlight != null:
		_platform_highlight.hide()


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
	modulate = DRAG_VALID_MODULATE if valid else DRAG_INVALID_MODULATE


func _clear_drag_feedback() -> void:
	modulate = _base_modulate


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


func _get_trojan_horse(follow: PathFollow2D) -> TrojanHorse:
	for child in follow.get_children():
		var trojan := child as TrojanHorse
		if trojan != null:
			return trojan

	return null
