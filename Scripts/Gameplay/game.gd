extends Node2D

const CyberGuardianTowerScript := preload("res://Scripts/Towers/cyber_guardian_idle_sprite.gd")
const LaserTurretScript := preload("res://Scripts/Towers/laser_turret.gd")
const RedVirusScript := preload("res://Scripts/Enemies/red_virus.gd")
const CyberQuestionHudScript := preload("res://Scripts/UI/cyber_question_hud.gd")
const PerformanceHudScript := preload("res://Scripts/UI/performance_hud.gd")
const GameControlsHudScript := preload("res://Scripts/UI/game_controls_hud.gd")
const TowerUpgradeHudScript := preload("res://Scripts/UI/tower_upgrade_hud.gd")
const TARGET_FPS := 60
const FPS_UPDATE_INTERVAL := 0.25
const GUARDIAN_MIN_SCALE := 0.12
const GUARDIAN_MAX_SCALE := 0.36
const GUARDIAN_SCALE_STEP := 0.01
const VIRUS_BATCH_TEN_COUNT := 10
const VIRUS_BATCH_HUNDRED_COUNT := 100
const VIRUS_BATCH_SPACING := 10.0
const PATH_GUIDE_SAMPLE_SPACING := 16.0
const PATH_GUIDE_ARROW_SPACING := 90.0
const PATH_GUIDE_ARROW_SIZE := 18.0
const PATH_GUIDE_WIDTH := 5.0
const PATH_GUIDE_COLOR := Color(0.62, 0.25, 1.0, 0.95)
const WAVE_BASE_VIRUS_COUNT := 5
const WAVE_VIRUS_COUNT_STEP := 2
const WAVE_SPAWN_INTERVAL := 0.6
const LASER_DURATION := 0.24

@export var guardian_path: NodePath = ^"Sprites/Cybersec Guardian"
@export var laser_turret_path: NodePath = ^"Sprites/Laser Turret"
@export var virus_template_path: NodePath = ^"Sprites/BasicVirus"
@export var virus_path_path: NodePath = ^"VirusElements/Path2D"
@export var virus_spawn_path: NodePath = ^"VirusElements/Marker2D"
@export var question_hud_path: NodePath = ^"CyberQuestionHud"
@export var performance_hud_path: NodePath = ^"PerformanceHud"
@export var game_controls_hud_path: NodePath = ^"GameControlsHud"
@export var tower_upgrade_hud_path: NodePath = ^"TowerUpgradeHud"
@export_range(GUARDIAN_MIN_SCALE, GUARDIAN_MAX_SCALE, GUARDIAN_SCALE_STEP) var guardian_default_scale := 0.3

var _fps_update_elapsed := 0.0
var _guardian: CyberGuardianTowerScript
var _laser_turret: LaserTurretScript
var _virus_template: RedVirusScript
var _virus_path: Path2D
var _virus_spawn: Node2D
var _question_hud: CyberQuestionHudScript
var _performance_hud: PerformanceHudScript
var _game_controls_hud: GameControlsHudScript
var _tower_upgrade_hud: TowerUpgradeHudScript
var _path_guide_container: Node2D
var _guardian_scale := 0.3
var _active_viruses: Array[PathFollow2D] = []
var _current_wave := 0
var _wave_in_progress := false
var _wave_question_pending := false
var _wave_spawns_remaining := 0
var _wave_spawn_cooldown_remaining := 0.0

func _ready() -> void:
	Engine.max_fps = TARGET_FPS
	_guardian = get_node_or_null(guardian_path) as CyberGuardianTowerScript
	_laser_turret = get_node_or_null(laser_turret_path) as LaserTurretScript
	_virus_template = get_node_or_null(virus_template_path) as RedVirusScript
	_virus_path = get_node_or_null(virus_path_path) as Path2D
	_virus_spawn = get_node_or_null(virus_spawn_path) as Node2D
	_question_hud = get_node_or_null(question_hud_path) as CyberQuestionHudScript
	_performance_hud = get_node_or_null(performance_hud_path) as PerformanceHudScript
	_game_controls_hud = get_node_or_null(game_controls_hud_path) as GameControlsHudScript
	_tower_upgrade_hud = get_node_or_null(tower_upgrade_hud_path) as TowerUpgradeHudScript
	if _virus_spawn == null:
		_virus_spawn = get_node_or_null(^"VirusElements/Spawn2D") as Node2D

	if _guardian == null:
		push_warning("Cybersec Guardian drag target was not found.")
	else:
		_set_guardian_scale(guardian_default_scale)
	if _laser_turret == null:
		push_warning("Laser Turret drag target was not found.")
	if _virus_template == null:
		push_warning("Basic virus spawn button was not found.")
	if _virus_path == null:
		push_warning("Virus Path2D was not found.")
	if _virus_spawn == null:
		push_warning("Virus spawn marker was not found.")
	if _question_hud == null:
		push_warning("CyberQuestionHud was not found.")
	else:
		_question_hud.question_solved.connect(Callable(self, "_on_wave_question_solved"))
	if _performance_hud == null:
		push_warning("PerformanceHud was not found.")
	if _game_controls_hud == null:
		push_warning("GameControlsHud was not found.")
	else:
		_game_controls_hud.reset_pressed.connect(Callable(self, "_reset_tower"))
		_game_controls_hud.start_wave_pressed.connect(Callable(self, "_start_next_wave"))
		_game_controls_hud.add_ten_pressed.connect(Callable(self, "_spawn_virus_batch").bind(VIRUS_BATCH_TEN_COUNT))
		_game_controls_hud.add_hundred_pressed.connect(Callable(self, "_spawn_virus_batch").bind(VIRUS_BATCH_HUNDRED_COUNT))
		_game_controls_hud.exit_pressed.connect(Callable(self, "_exit_game"))
	if _tower_upgrade_hud == null:
		push_warning("TowerUpgradeHud was not found.")
	else:
		_tower_upgrade_hud.configure_guardian_scale(GUARDIAN_MIN_SCALE, GUARDIAN_MAX_SCALE, GUARDIAN_SCALE_STEP, _guardian_scale)
		_tower_upgrade_hud.guardian_scale_changed.connect(Callable(self, "_on_guardian_scale_changed"))
		_tower_upgrade_hud.laser_upgrade_pressed.connect(Callable(self, "_upgrade_laser_turret"))
	_create_path_guide()

	_update_fps_label()
	_update_virus_count_label()
	_update_wave_button()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return

		var pointer_position := _screen_to_canvas_position(mouse_button.position)
		if mouse_button.pressed:
			if _try_spawn_virus_from_press(pointer_position):
				get_viewport().set_input_as_handled()
				return

			if _handle_laser_turret_press(pointer_position, mouse_button.position):
				return

			if _guardian == null:
				return

			if _guardian.is_placed():
				_handle_placed_tower_press(pointer_position, mouse_button.position)
			else:
				_guardian.try_start_drag(pointer_position)
		elif _guardian != null and _guardian.is_dragging():
			_guardian.finish_drag()
		return

	if _guardian != null and not _guardian.is_placed() and event is InputEventMouseMotion and _guardian.is_dragging():
		var mouse_motion := event as InputEventMouseMotion
		_guardian.update_drag(_screen_to_canvas_position(mouse_motion.position))
		return

	if event is InputEventScreenTouch:
		var screen_touch := event as InputEventScreenTouch
		var pointer_position := _screen_to_canvas_position(screen_touch.position)
		if screen_touch.pressed:
			if _try_spawn_virus_from_press(pointer_position):
				get_viewport().set_input_as_handled()
				return

			if _handle_laser_turret_press(pointer_position, screen_touch.position):
				return

			if _guardian == null:
				return

			if _guardian.is_placed():
				_handle_placed_tower_press(pointer_position, screen_touch.position)
			else:
				_guardian.try_start_drag(pointer_position)
		elif _guardian != null and _guardian.is_dragging():
			_guardian.finish_drag()
		return

	if _guardian != null and not _guardian.is_placed() and event is InputEventScreenDrag and _guardian.is_dragging():
		var screen_drag := event as InputEventScreenDrag
		_guardian.update_drag(_screen_to_canvas_position(screen_drag.position))


func _process(delta: float) -> void:
	_update_wave_spawner(delta)
	_update_active_viruses(delta)
	_update_tower_attack(delta)
	_update_laser_turret_attack(delta)

	_fps_update_elapsed += delta
	if _fps_update_elapsed < FPS_UPDATE_INTERVAL:
		return

	_fps_update_elapsed = 0.0
	_update_fps_label()


func _update_fps_label() -> void:
	if _performance_hud == null:
		return

	var current_fps := roundi(Performance.get_monitor(Performance.TIME_FPS))
	_performance_hud.set_fps(current_fps, TARGET_FPS)


func _handle_placed_tower_press(pointer_position: Vector2, screen_position: Vector2) -> void:
	if _tower_upgrade_hud != null and _tower_upgrade_hud.guardian_panel_has_point(screen_position):
		return

	if _guardian != null and _guardian.contains_global_point(pointer_position):
		_show_upgrade_panel()
		get_viewport().set_input_as_handled()
	elif _tower_upgrade_hud != null and _tower_upgrade_hud.is_guardian_panel_visible():
		_hide_upgrade_panel()


func _handle_laser_turret_press(pointer_position: Vector2, screen_position: Vector2) -> bool:
	if _tower_upgrade_hud != null and _tower_upgrade_hud.laser_panel_has_point(screen_position):
		return true

	if _laser_turret != null and _laser_turret.is_placed() and _laser_turret.contains_global_point(pointer_position):
		_show_laser_upgrade_panel()
		get_viewport().set_input_as_handled()
		return true

	if _tower_upgrade_hud != null and _tower_upgrade_hud.is_laser_panel_visible():
		_hide_laser_upgrade_panel()

	return false


func _reset_tower() -> void:
	if _guardian != null:
		_guardian.reset_tower()
	if _laser_turret != null:
		_laser_turret.reset_tower()
	if _tower_upgrade_hud != null:
		_tower_upgrade_hud.hide_all()


func _upgrade_laser_turret() -> void:
	if _laser_turret == null:
		return

	_laser_turret.upgrade()
	_sync_laser_upgrade_panel()


func _sync_laser_upgrade_panel() -> void:
	if _laser_turret == null or _tower_upgrade_hud == null:
		return

	var level := _laser_turret.get_level()
	var max_level := _laser_turret.get_max_level()
	var power := _laser_turret.get_shot_power()
	var range := _laser_turret.get_attack_range()
	_tower_upgrade_hud.set_laser_stats(level, max_level, power, range, _laser_turret.can_upgrade())


func _on_guardian_scale_changed(value: float) -> void:
	_set_guardian_scale(value)


func _set_guardian_scale(value: float) -> void:
	_guardian_scale = snappedf(clampf(value, GUARDIAN_MIN_SCALE, GUARDIAN_MAX_SCALE), GUARDIAN_SCALE_STEP)
	if _guardian != null:
		_guardian.set_tower_scale(_guardian_scale)

	_sync_guardian_scale_controls()


func _sync_guardian_scale_controls() -> void:
	if _tower_upgrade_hud != null:
		_tower_upgrade_hud.set_guardian_scale(_guardian_scale)


func _start_next_wave() -> void:
	if _wave_in_progress or _wave_question_pending:
		return

	_current_wave += 1
	_wave_in_progress = true
	_wave_spawns_remaining = WAVE_BASE_VIRUS_COUNT + ((_current_wave - 1) * WAVE_VIRUS_COUNT_STEP)
	_wave_spawn_cooldown_remaining = 0.0
	_update_wave_button()


func _update_wave_spawner(delta: float) -> void:
	if not _wave_in_progress:
		return

	if _wave_spawns_remaining > 0:
		_wave_spawn_cooldown_remaining -= delta
		if _wave_spawn_cooldown_remaining <= 0.0:
			_spawn_virus()
			_wave_spawns_remaining -= 1
			_wave_spawn_cooldown_remaining = WAVE_SPAWN_INTERVAL

	if _wave_spawns_remaining <= 0 and _active_viruses.is_empty():
		_wave_in_progress = false
		_show_wave_question()
		_update_wave_button()


func _update_wave_button() -> void:
	if _game_controls_hud == null:
		return

	if _wave_question_pending:
		_game_controls_hud.set_wave_button("Answer Question", true)
		_set_spawn_buttons_disabled(true)
		return

	if _wave_in_progress:
		_game_controls_hud.set_wave_button("Wave %d Running" % _current_wave, true)
		_set_spawn_buttons_disabled(false)
		return

	_game_controls_hud.set_wave_button("Start Wave %d" % (_current_wave + 1), false)
	_set_spawn_buttons_disabled(false)


func _set_spawn_buttons_disabled(disabled: bool) -> void:
	if _game_controls_hud != null:
		_game_controls_hud.set_spawn_buttons_disabled(disabled)


func _show_wave_question() -> void:
	if _question_hud == null:
		return

	_wave_question_pending = true
	_question_hud.show_wave_question(_current_wave)


func _on_wave_question_solved(_reward: int) -> void:
	_wave_question_pending = false
	_update_wave_button()


func _exit_game() -> void:
	get_tree().quit()


func _try_spawn_virus_from_press(pointer_position: Vector2) -> bool:
	if _virus_template == null:
		return false

	if not _virus_template.contains_global_point(pointer_position):
		return false

	_spawn_virus()
	return true


func _spawn_virus(start_progress: float = -1.0, update_count: bool = true) -> void:
	if _virus_path == null or _virus_path.curve == null:
		push_warning("Cannot spawn virus because VirusElements/Path2D is missing a curve.")
		return
	if _virus_template == null:
		push_warning("Cannot spawn virus because BasicVirus was not found.")
		return

	var follow := PathFollow2D.new()
	follow.name = "SpawnedVirusFollow"
	follow.loop = false
	follow.progress = _get_virus_spawn_progress() if start_progress < 0.0 else start_progress
	_virus_path.add_child(follow)

	var virus := _virus_template.duplicate() as RedVirusScript
	virus.name = "SpawnedVirus"
	virus.position = Vector2.ZERO
	virus.reset_for_spawn()
	follow.add_child(virus)

	_active_viruses.append(follow)
	if update_count:
		_update_virus_count_label()


func _spawn_virus_batch(count: int) -> void:
	if count <= 0:
		return
	if _virus_path == null or _virus_path.curve == null:
		push_warning("Cannot spawn virus batch because VirusElements/Path2D is missing a curve.")
		return

	var spawn_progress := _get_virus_spawn_progress()
	var path_length := _virus_path.curve.get_baked_length()
	var available_path_distance := maxf(0.0, path_length - spawn_progress)
	var rightmost_offset := minf(float(count - 1) * VIRUS_BATCH_SPACING, available_path_distance)
	var rightmost_progress := spawn_progress + rightmost_offset
	for index in range(count):
		var progress := maxf(spawn_progress, rightmost_progress - float(index) * VIRUS_BATCH_SPACING)
		_spawn_virus(progress, false)

	_update_virus_count_label()


func _update_active_viruses(delta: float) -> void:
	if _virus_path == null or _virus_path.curve == null:
		return

	var path_length := _virus_path.curve.get_baked_length()
	if path_length <= 0.0:
		return

	var count_changed := false
	for index in range(_active_viruses.size() - 1, -1, -1):
		var follow := _active_viruses[index]
		if not is_instance_valid(follow):
			_active_viruses.remove_at(index)
			count_changed = true
			continue

		follow.progress += _get_virus_speed(follow) * delta
		if follow.progress >= path_length:
			_despawn_virus(follow, false)
			count_changed = true

	if count_changed:
		_update_virus_count_label()


func _update_tower_attack(delta: float) -> void:
	if _guardian == null:
		return

	var target := _guardian.update_attack(delta, _active_viruses)
	if target == null:
		return

	_shoot_virus(target)


func _update_laser_turret_attack(delta: float) -> void:
	if _laser_turret == null:
		return

	var targets := _laser_turret.update_attack(delta, _active_viruses)
	if targets.is_empty():
		return

	_shoot_laser_turret_targets(targets)


func _shoot_virus(target: PathFollow2D) -> void:
	if not is_instance_valid(target):
		return

	var target_position := target.global_position
	_guardian.aim_at(target_position)
	_guardian.play_shoot()
	_spawn_colored_laser(_guardian.global_position, target_position, Color(0.1, 0.55, 1.0, 1.0), _guardian.get_laser_width())
	_despawn_virus(target)


func _shoot_laser_turret_targets(targets: Array[PathFollow2D]) -> void:
	if _laser_turret == null:
		return

	var origin_position := _laser_turret.global_position
	var laser_width := _laser_turret.get_laser_width()
	var laser_color := _laser_turret.get_laser_color()
	var count_changed := false
	for target in targets:
		if not is_instance_valid(target):
			continue

		var target_position := target.global_position
		_laser_turret.aim_at(target_position)
		_spawn_colored_laser(origin_position, target_position, laser_color, laser_width)
		_despawn_virus(target, false)
		count_changed = true

	if count_changed:
		_laser_turret.mark_shot_fired()
		_update_virus_count_label()


func _spawn_colored_laser(start_position: Vector2, end_position: Vector2, color: Color, width: float) -> void:
	var glow := Line2D.new()
	glow.name = "TowerLaserGlow"
	glow.width = width * 2.25
	glow.default_color = Color(color.r, color.g, color.b, 0.35)
	glow.z_index = 99
	glow.points = PackedVector2Array([
		to_local(start_position),
		to_local(end_position)
	])
	add_child(glow)

	var laser := Line2D.new()
	laser.name = "TowerLaser"
	laser.width = width
	laser.default_color = color
	laser.z_index = 100
	laser.points = PackedVector2Array([
		to_local(start_position),
		to_local(end_position)
	])
	add_child(laser)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(glow, "modulate", Color(1, 1, 1, 0), LASER_DURATION)
	tween.tween_property(laser, "modulate", Color(1, 1, 1, 0), LASER_DURATION)
	tween.set_parallel(false)
	tween.tween_callback(Callable(glow, "queue_free"))
	tween.tween_callback(Callable(laser, "queue_free"))


func _despawn_virus(follow: PathFollow2D, update_count: bool = true) -> void:
	var index := _active_viruses.find(follow)
	if index != -1:
		_active_viruses.remove_at(index)

	if is_instance_valid(follow):
		var virus := _get_red_virus(follow)
		if virus != null:
			virus.play_destroy_and_queue_owner(follow)
		else:
			follow.queue_free()

	if update_count:
		_update_virus_count_label()


func _get_red_virus(follow: PathFollow2D) -> RedVirusScript:
	for child in follow.get_children():
		var virus := child as RedVirusScript
		if virus != null:
			return virus

	return null


func _get_virus_speed(follow: PathFollow2D) -> float:
	var virus := _get_red_virus(follow)
	if virus != null:
		return virus.get_path_speed()
	if _virus_template != null:
		return _virus_template.get_path_speed()

	return 0.0


func _update_virus_count_label() -> void:
	if _performance_hud == null:
		return

	_performance_hud.set_virus_count(_active_viruses.size())


func _get_virus_spawn_progress() -> float:
	if _virus_path == null or _virus_path.curve == null or _virus_spawn == null:
		return 0.0

	var spawn_position := _virus_path.to_local(_virus_spawn.global_position)
	return _virus_path.curve.get_closest_offset(spawn_position)


func _create_path_guide() -> void:
	if _virus_path == null or _virus_path.curve == null:
		return

	var old_dot_container := _virus_path.get_node_or_null(^"RuntimePathDots") as Node2D
	if old_dot_container != null:
		old_dot_container.queue_free()

	_path_guide_container = _virus_path.get_node_or_null(^"RuntimePathGuide") as Node2D
	if _path_guide_container == null:
		_path_guide_container = Node2D.new()
		_path_guide_container.name = "RuntimePathGuide"
		_virus_path.add_child(_path_guide_container)

	for child in _path_guide_container.get_children():
		child.queue_free()

	var path_length := _virus_path.curve.get_baked_length()
	if path_length <= 0.0:
		return

	var path_line := Line2D.new()
	path_line.name = "PathGuideLine"
	path_line.width = PATH_GUIDE_WIDTH
	path_line.default_color = PATH_GUIDE_COLOR
	path_line.joint_mode = Line2D.LINE_JOINT_ROUND
	path_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	path_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	path_line.antialiased = true
	path_line.z_index = 40
	path_line.points = _build_path_guide_points(path_length)
	_path_guide_container.add_child(path_line)

	var arrow_distance := minf(PATH_GUIDE_ARROW_SPACING * 0.5, path_length * 0.5)
	while arrow_distance < path_length:
		_add_path_guide_arrow(arrow_distance, path_length)
		arrow_distance += PATH_GUIDE_ARROW_SPACING


func _build_path_guide_points(path_length: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var distance := 0.0
	while distance < path_length:
		points.append(_virus_path.curve.sample_baked(distance))
		distance += PATH_GUIDE_SAMPLE_SPACING

	points.append(_virus_path.curve.sample_baked(path_length))
	return points


func _add_path_guide_arrow(distance: float, path_length: float) -> void:
	var center := _virus_path.curve.sample_baked(distance)
	var before := _virus_path.curve.sample_baked(maxf(0.0, distance - 6.0))
	var after := _virus_path.curve.sample_baked(minf(path_length, distance + 6.0))
	var direction := (after - before).normalized()
	if direction == Vector2.ZERO:
		return

	var half_size := PATH_GUIDE_ARROW_SIZE * 0.5
	var side := Vector2(-direction.y, direction.x)
	var arrow := Polygon2D.new()
	arrow.name = "PathGuideArrow"
	arrow.position = center
	arrow.polygon = PackedVector2Array([
		direction * half_size,
		-direction * half_size + side * half_size * 0.75,
		-direction * half_size - side * half_size * 0.75
	])
	arrow.color = PATH_GUIDE_COLOR
	arrow.z_index = 41
	_path_guide_container.add_child(arrow)


func _screen_to_canvas_position(screen_position: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_position


func _show_upgrade_panel() -> void:
	if _tower_upgrade_hud == null:
		return

	_tower_upgrade_hud.show_guardian_panel()


func _hide_upgrade_panel() -> void:
	if _tower_upgrade_hud == null:
		return

	_tower_upgrade_hud.hide_guardian_panel()


func _show_laser_upgrade_panel() -> void:
	if _tower_upgrade_hud == null or _laser_turret == null:
		return

	_sync_laser_upgrade_panel()
	_tower_upgrade_hud.show_laser_panel()


func _hide_laser_upgrade_panel() -> void:
	if _tower_upgrade_hud == null:
		return

	_tower_upgrade_hud.hide_laser_panel()
