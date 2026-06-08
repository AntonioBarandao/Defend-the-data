extends Node2D

const TARGET_FPS := 60
const FPS_UPDATE_INTERVAL := 0.25
const PLATFORM_HIGHLIGHT_SIZE := Vector2(180, 120)
const GUARDIAN_GRAB_SIZE := Vector2(240, 180)
const UPGRADE_PANEL_WIDTH_RATIO := 0.28
const UPGRADE_PANEL_MIN_WIDTH := 360.0
const UPGRADE_PANEL_MAX_WIDTH := 480.0
const UPGRADE_PANEL_SLIDE_TIME := 0.22
const TOWER_NAME := "Cyber Guardian"
const MASCOT_TEXTURE_PATH := "res://assets/Towers/CyberGuardian/CybersecurityMascot.png"
const MASCOT_PORTRAIT_SIZE := Vector2(132, 132)
const GUARDIAN_MIN_SCALE := 0.12
const GUARDIAN_MAX_SCALE := 0.36
const GUARDIAN_SCALE_STEP := 0.01
const HUD_MARGIN := 24.0
const RESET_BUTTON_SIZE := Vector2(132, 48)
const MENU_BUTTON_SIZE := Vector2(56, 48)
const MENU_PANEL_SIZE := Vector2(220, 190)
const MENU_SLIDE_TIME := 0.2
const VIRUS_BATCH_BUTTON_SIZE := Vector2(96, 36)
const VIRUS_BATCH_BUTTON_GAP := 10.0
const VIRUS_BATCH_TEN_COUNT := 10
const VIRUS_BATCH_HUNDRED_COUNT := 100
const VIRUS_BATCH_SPACING := 10.0
const VIRUS_SPEED := 200.0
const VIRUS_GRAB_SIZE := Vector2(128, 128)
const PATH_DOT_SPACING := 42.0
const PATH_DOT_RADIUS := 7.0
const PATH_DOT_SEGMENTS := 16
const PATH_DOT_COLOR := Color(0.2, 0.75, 1.0, 0.95)
const TOWER_RANGE_LEVEL := 5
const TOWER_RANGE_PIXELS_PER_LEVEL := 50.0
const TOWER_SHOT_COOLDOWN := 0.5
const LASER_DURATION := 0.24
const LASER_WIDTH := 10.0
const GUARDIAN_FORWARD_ROTATION := PI * 0.5
const GUARDIAN_SUMMON_ANIMATION := &"SummonAnim"
const GUARDIAN_SHOOT_ANIMATION := &"ShootAnim"
const AVAILABLE_UPGRADES := [
	"Firewall Burst",
	"Signal Range",
	"Rapid Scan"
]
const PLATFORM_VALID_COLOR := Color(0.1, 0.9, 0.25, 0.45)
const PLATFORM_INVALID_COLOR := Color(1.0, 0.1, 0.08, 0.45)

@export var guardian_path: NodePath = ^"Sprites/Cybersec Guardian"
@export var placement_area_path: NodePath = ^"TowerPlacementArea"
@export var platform_highlight_path: NodePath = ^"PlatformHighlight"
@export var virus_template_path: NodePath = ^"Sprites/BasicVirus"
@export var virus_path_path: NodePath = ^"VirusElements/Path2D"
@export var virus_spawn_path: NodePath = ^"VirusElements/Marker2D"
@export_range(GUARDIAN_MIN_SCALE, GUARDIAN_MAX_SCALE, GUARDIAN_SCALE_STEP) var guardian_default_scale := 0.22

var _fps_label: Label
var _fps_update_elapsed := 0.0
var _guardian: AnimatedSprite2D
var _placement_area: Area2D
var _placement_areas: Array[Area2D] = []
var _current_placement_shape: CollisionShape2D
var _platform_highlight: ColorRect
var _virus_template: Sprite2D
var _virus_path: Path2D
var _virus_spawn: Node2D
var _virus_count_label: Label
var _path_dot_container: Node2D
var _upgrade_panel: PanelContainer
var _upgrade_panel_tween: Tween
var _upgrade_panel_visible := false
var _upgrade_panel_side := &""
var _guardian_scale := 0.22
var _guardian_scale_slider: HSlider
var _guardian_scale_value_label: Label
var _reset_button: Button
var _add_ten_button: Button
var _add_hundred_button: Button
var _menu_button: Button
var _menu_panel: PanelContainer
var _menu_tween: Tween
var _menu_visible := false
var _dragging_guardian := false
var _tower_is_placed := false
var _guardian_home_position := Vector2.ZERO
var _drag_offset := Vector2.ZERO
var _drag_start_position := Vector2.ZERO
var _drag_is_valid := false
var _tower_shot_cooldown_remaining := 0.0
var _active_viruses: Array[PathFollow2D] = []

func _ready() -> void:
	Engine.max_fps = TARGET_FPS
	_guardian = get_node_or_null(guardian_path) as AnimatedSprite2D
	_placement_area = get_node_or_null(placement_area_path) as Area2D
	_collect_placement_areas()
	_platform_highlight = _get_or_create_platform_highlight()
	_virus_template = get_node_or_null(virus_template_path) as Sprite2D
	_virus_path = get_node_or_null(virus_path_path) as Path2D
	_virus_spawn = get_node_or_null(virus_spawn_path) as Node2D
	if _virus_spawn == null:
		_virus_spawn = get_node_or_null(^"VirusElements/Spawn2D") as Node2D
	_configure_platform_highlight()

	if _guardian == null:
		push_warning("Cybersec Guardian drag target was not found.")
	else:
		_set_guardian_scale(guardian_default_scale)
		_guardian_home_position = _guardian.global_position
	if _placement_areas.is_empty():
		push_warning("No tower placement areas were found.")
	if _virus_template == null:
		push_warning("Basic virus spawn button was not found.")
	if _virus_path == null:
		push_warning("Virus Path2D was not found.")
	if _virus_spawn == null:
		push_warning("Virus spawn marker was not found.")
	_create_path_dots()

	_upgrade_panel = _create_upgrade_panel()
	_create_hud()
	_fps_label = _create_fps_label()
	_update_fps_label()
	get_viewport().size_changed.connect(Callable(self, "_layout_hud_controls"))


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

			if _guardian == null:
				return

			if _tower_is_placed:
				_handle_placed_tower_press(pointer_position, mouse_button.position)
			else:
				_try_start_guardian_drag(pointer_position)
		elif _dragging_guardian:
			_finish_guardian_drag()
		return

	if not _tower_is_placed and event is InputEventMouseMotion and _dragging_guardian:
		var mouse_motion := event as InputEventMouseMotion
		_update_guardian_drag(_screen_to_canvas_position(mouse_motion.position))
		return

	if event is InputEventScreenTouch:
		var screen_touch := event as InputEventScreenTouch
		var pointer_position := _screen_to_canvas_position(screen_touch.position)
		if screen_touch.pressed:
			if _try_spawn_virus_from_press(pointer_position):
				get_viewport().set_input_as_handled()
				return

			if _guardian == null:
				return

			if _tower_is_placed:
				_handle_placed_tower_press(pointer_position, screen_touch.position)
			else:
				_try_start_guardian_drag(pointer_position)
		elif _dragging_guardian:
			_finish_guardian_drag()
		return

	if not _tower_is_placed and event is InputEventScreenDrag and _dragging_guardian:
		var screen_drag := event as InputEventScreenDrag
		_update_guardian_drag(_screen_to_canvas_position(screen_drag.position))


func _process(delta: float) -> void:
	_update_active_viruses(delta)
	_update_tower_attack(delta)

	_fps_update_elapsed += delta
	if _fps_update_elapsed < FPS_UPDATE_INTERVAL:
		return

	_fps_update_elapsed = 0.0
	_update_fps_label()


func _create_fps_label() -> Label:
	var overlay := CanvasLayer.new()
	overlay.name = "PerformanceOverlay"
	overlay.layer = 100
	add_child(overlay)

	var label := Label.new()
	label.name = "FPSLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(24, 24)
	label.size = Vector2(220, 44)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	overlay.add_child(label)

	return label


func _update_fps_label() -> void:
	var current_fps := roundi(Performance.get_monitor(Performance.TIME_FPS))
	_fps_label.text = "FPS: %d / %d" % [current_fps, TARGET_FPS]


func _create_hud() -> void:
	var overlay := CanvasLayer.new()
	overlay.name = "GameHudOverlay"
	overlay.layer = 120
	add_child(overlay)

	_reset_button = Button.new()
	_reset_button.name = "ResetTowerButton"
	_reset_button.text = "Reset"
	_reset_button.focus_mode = Control.FOCUS_NONE
	_reset_button.custom_minimum_size = RESET_BUTTON_SIZE
	_reset_button.size = RESET_BUTTON_SIZE
	_reset_button.pressed.connect(Callable(self, "_reset_tower"))
	overlay.add_child(_reset_button)

	_add_ten_button = Button.new()
	_add_ten_button.name = "AddTenVirusesButton"
	_add_ten_button.text = "Add 10"
	_add_ten_button.focus_mode = Control.FOCUS_NONE
	_add_ten_button.custom_minimum_size = VIRUS_BATCH_BUTTON_SIZE
	_add_ten_button.size = VIRUS_BATCH_BUTTON_SIZE
	_add_ten_button.pressed.connect(Callable(self, "_spawn_virus_batch").bind(VIRUS_BATCH_TEN_COUNT))
	overlay.add_child(_add_ten_button)

	_add_hundred_button = Button.new()
	_add_hundred_button.name = "AddHundredVirusesButton"
	_add_hundred_button.text = "Add 100"
	_add_hundred_button.focus_mode = Control.FOCUS_NONE
	_add_hundred_button.custom_minimum_size = VIRUS_BATCH_BUTTON_SIZE
	_add_hundred_button.size = VIRUS_BATCH_BUTTON_SIZE
	_add_hundred_button.pressed.connect(Callable(self, "_spawn_virus_batch").bind(VIRUS_BATCH_HUNDRED_COUNT))
	overlay.add_child(_add_hundred_button)

	_menu_button = Button.new()
	_menu_button.name = "MainMenuButton"
	_menu_button.focus_mode = Control.FOCUS_NONE
	_menu_button.custom_minimum_size = MENU_BUTTON_SIZE
	_menu_button.size = MENU_BUTTON_SIZE
	_menu_button.pressed.connect(Callable(self, "_toggle_game_menu"))
	overlay.add_child(_menu_button)
	_add_hamburger_icon(_menu_button)

	_menu_panel = _create_game_menu_panel()
	overlay.add_child(_menu_panel)

	_virus_count_label = Label.new()
	_virus_count_label.name = "VirusCountLabel"
	_virus_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_virus_count_label.size = Vector2(260, 42)
	_virus_count_label.add_theme_font_size_override("font_size", 26)
	_virus_count_label.add_theme_color_override("font_color", Color.WHITE)
	_virus_count_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_virus_count_label.add_theme_constant_override("shadow_offset_x", 2)
	_virus_count_label.add_theme_constant_override("shadow_offset_y", 2)
	overlay.add_child(_virus_count_label)
	_update_virus_count_label()

	_layout_hud_controls()


func _add_hamburger_icon(button: Button) -> void:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.size = MENU_BUTTON_SIZE
	button.add_child(center)

	var bars := VBoxContainer.new()
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.custom_minimum_size = Vector2(24, 20)
	bars.add_theme_constant_override("separation", 5)
	center.add_child(bars)

	for index in range(3):
		var bar := ColorRect.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.custom_minimum_size = Vector2(24, 3)
		bar.color = Color(0.9, 0.96, 1.0, 1.0)
		bars.add_child(bar)


func _create_game_menu_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "MainMenuPanel"
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = MENU_PANEL_SIZE
	panel.size = MENU_PANEL_SIZE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.047, 0.07, 0.95)
	style.border_color = Color(0.46, 0.72, 1.0, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation", 10)
	margin.add_child(options)

	_add_menu_option(options, "Continue", Callable(self, "_hide_game_menu"))
	_add_menu_option(options, "Settings", Callable(self, "_hide_game_menu"))
	_add_menu_option(options, "Exit", Callable(self, "_exit_game"))

	return panel


func _add_menu_option(parent: VBoxContainer, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 44)
	button.pressed.connect(callback)
	parent.add_child(button)


func _layout_hud_controls() -> void:
	if _reset_button == null or _menu_button == null or _menu_panel == null:
		return

	var viewport_size := get_viewport_rect().size
	_reset_button.position = Vector2(viewport_size.x - RESET_BUTTON_SIZE.x - HUD_MARGIN, HUD_MARGIN)
	if _add_ten_button != null and _add_hundred_button != null and _virus_template != null:
		var virus_rect := _get_sprite_rect(_virus_template, VIRUS_GRAB_SIZE)
		var button_anchor := get_canvas_transform() * Vector2(virus_rect.get_center().x, virus_rect.end.y + 10.0)
		var button_group_width := VIRUS_BATCH_BUTTON_SIZE.x * 2.0 + VIRUS_BATCH_BUTTON_GAP
		var button_group_left := button_anchor.x - button_group_width * 0.5
		_add_ten_button.position = Vector2(button_group_left, button_anchor.y)
		_add_hundred_button.position = Vector2(
			button_group_left + VIRUS_BATCH_BUTTON_SIZE.x + VIRUS_BATCH_BUTTON_GAP,
			button_anchor.y
		)
	_menu_button.position = Vector2((viewport_size.x - MENU_BUTTON_SIZE.x) * 0.5, HUD_MARGIN)
	_menu_panel.position = _get_menu_panel_position(not _menu_visible)
	if _virus_count_label != null:
		_virus_count_label.position = Vector2(HUD_MARGIN, HUD_MARGIN + 58.0)

	if _upgrade_panel != null:
		_upgrade_panel.custom_minimum_size = _get_upgrade_panel_size()
		_upgrade_panel.size = _get_upgrade_panel_size()
		if _upgrade_panel_visible:
			_upgrade_panel.position = _get_upgrade_panel_position(_upgrade_panel_side, false)


func _create_upgrade_panel() -> PanelContainer:
	var overlay := CanvasLayer.new()
	overlay.name = "TowerUpgradeOverlay"
	overlay.layer = 80
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.name = "TowerUpgradePanel"
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = _get_upgrade_panel_size()
	panel.size = _get_upgrade_panel_size()

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.047, 0.07, 0.94)
	style.border_color = Color(0.18, 0.82, 0.42, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var title := Label.new()
	title.text = TOWER_NAME
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color.WHITE)
	content.add_child(title)

	var portrait_row := CenterContainer.new()
	content.add_child(portrait_row)

	var portrait := TextureRect.new()
	portrait.name = "MascotPortrait"
	portrait.custom_minimum_size = MASCOT_PORTRAIT_SIZE
	portrait.size = MASCOT_PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = load(MASCOT_TEXTURE_PATH) as Texture2D
	portrait_row.add_child(portrait)

	if portrait.texture == null:
		push_warning("Cybersecurity mascot popup image was not found: %s" % MASCOT_TEXTURE_PATH)

	var scale_row := HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 10)
	content.add_child(scale_row)

	var scale_label := Label.new()
	scale_label.text = "Size"
	scale_label.custom_minimum_size = Vector2(52, 0)
	scale_label.add_theme_font_size_override("font_size", 18)
	scale_label.add_theme_color_override("font_color", Color(0.72, 0.84, 0.92, 1.0))
	scale_row.add_child(scale_label)

	_guardian_scale_slider = HSlider.new()
	_guardian_scale_slider.min_value = GUARDIAN_MIN_SCALE
	_guardian_scale_slider.max_value = GUARDIAN_MAX_SCALE
	_guardian_scale_slider.step = GUARDIAN_SCALE_STEP
	_guardian_scale_slider.value = _guardian_scale
	_guardian_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_guardian_scale_slider.focus_mode = Control.FOCUS_NONE
	_guardian_scale_slider.value_changed.connect(Callable(self, "_on_guardian_scale_changed"))
	scale_row.add_child(_guardian_scale_slider)

	_guardian_scale_value_label = Label.new()
	_guardian_scale_value_label.custom_minimum_size = Vector2(62, 0)
	_guardian_scale_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_guardian_scale_value_label.add_theme_font_size_override("font_size", 18)
	_guardian_scale_value_label.add_theme_color_override("font_color", Color.WHITE)
	scale_row.add_child(_guardian_scale_value_label)
	_sync_guardian_scale_controls()

	var section_label := Label.new()
	section_label.text = "Available Upgrades"
	section_label.add_theme_font_size_override("font_size", 18)
	section_label.add_theme_color_override("font_color", Color(0.72, 0.84, 0.92, 1.0))
	content.add_child(section_label)

	for upgrade_name in AVAILABLE_UPGRADES:
		var upgrade_button := Button.new()
		upgrade_button.text = upgrade_name
		upgrade_button.focus_mode = Control.FOCUS_NONE
		upgrade_button.custom_minimum_size = Vector2(0, 48)
		content.add_child(upgrade_button)

	return panel


func _try_start_guardian_drag(pointer_position: Vector2) -> void:
	if not _get_guardian_rect().has_point(pointer_position):
		return

	_dragging_guardian = true
	_drag_start_position = _guardian.global_position
	_drag_offset = _guardian.global_position - pointer_position
	_platform_highlight.show()
	_update_guardian_drag(pointer_position)
	get_viewport().set_input_as_handled()


func _update_guardian_drag(pointer_position: Vector2) -> void:
	_guardian.global_position = pointer_position + _drag_offset
	_update_platform_highlight()
	get_viewport().set_input_as_handled()


func _finish_guardian_drag() -> void:
	if _drag_is_valid:
		_guardian.global_position = _get_placement_area_center()
		_tower_is_placed = true
		_play_guardian_animation(GUARDIAN_SUMMON_ANIMATION)
	else:
		_guardian.global_position = _drag_start_position

	_platform_highlight.hide()
	_dragging_guardian = false
	get_viewport().set_input_as_handled()


func _handle_placed_tower_press(pointer_position: Vector2, screen_position: Vector2) -> void:
	if _upgrade_panel_visible and _upgrade_panel.get_global_rect().has_point(screen_position):
		get_viewport().set_input_as_handled()
		return

	if _get_guardian_rect().has_point(pointer_position):
		_show_upgrade_panel()
		get_viewport().set_input_as_handled()
	elif _upgrade_panel_visible:
		_hide_upgrade_panel()


func _reset_tower() -> void:
	if _guardian == null:
		return

	_guardian.global_position = _guardian_home_position
	_guardian.rotation = 0.0
	_tower_is_placed = false
	_dragging_guardian = false
	_drag_is_valid = false
	_current_placement_shape = null
	_tower_shot_cooldown_remaining = 0.0
	_drag_offset = Vector2.ZERO
	_drag_start_position = _guardian_home_position

	if _platform_highlight != null:
		_platform_highlight.hide()
	_hide_upgrade_panel()


func _on_guardian_scale_changed(value: float) -> void:
	_set_guardian_scale(value)


func _set_guardian_scale(value: float) -> void:
	_guardian_scale = snappedf(clampf(value, GUARDIAN_MIN_SCALE, GUARDIAN_MAX_SCALE), GUARDIAN_SCALE_STEP)
	if _guardian != null:
		_guardian.scale = Vector2.ONE * _guardian_scale
		if _dragging_guardian:
			_update_platform_highlight()

	_sync_guardian_scale_controls()


func _sync_guardian_scale_controls() -> void:
	if _guardian_scale_slider != null:
		_guardian_scale_slider.set_value_no_signal(_guardian_scale)

	if _guardian_scale_value_label != null:
		_guardian_scale_value_label.text = "%.2fx" % _guardian_scale


func _toggle_game_menu() -> void:
	if _menu_visible:
		_hide_game_menu()
	else:
		_show_game_menu()


func _show_game_menu() -> void:
	if _menu_panel == null:
		return

	_menu_visible = true
	_menu_panel.size = MENU_PANEL_SIZE
	_menu_panel.position = _get_menu_panel_position(true)
	_menu_panel.show()
	_run_menu_tween(_get_menu_panel_position(false), true)


func _hide_game_menu() -> void:
	if _menu_panel == null or not _menu_visible:
		return

	_menu_visible = false
	_run_menu_tween(_get_menu_panel_position(true), false)


func _run_menu_tween(target_position: Vector2, keep_visible: bool) -> void:
	if _menu_tween != null:
		_menu_tween.kill()

	_menu_tween = create_tween()
	_menu_tween.tween_property(_menu_panel, "position", target_position, MENU_SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not keep_visible:
		_menu_tween.tween_callback(Callable(_menu_panel, "hide"))


func _get_menu_panel_position(hidden: bool) -> Vector2:
	var viewport_size := get_viewport_rect().size
	var x_position := (viewport_size.x - MENU_PANEL_SIZE.x) * 0.5
	var y_position := HUD_MARGIN + MENU_BUTTON_SIZE.y + 10.0
	if hidden:
		y_position = -MENU_PANEL_SIZE.y - HUD_MARGIN

	return Vector2(x_position, y_position)


func _exit_game() -> void:
	get_tree().quit()


func _try_spawn_virus_from_press(pointer_position: Vector2) -> bool:
	if _virus_template == null:
		return false

	if not _get_sprite_rect(_virus_template, VIRUS_GRAB_SIZE).has_point(pointer_position):
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

	var virus := _virus_template.duplicate() as Sprite2D
	virus.name = "SpawnedVirus"
	virus.position = Vector2.ZERO
	virus.show()
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

		follow.progress += VIRUS_SPEED * delta
		if follow.progress >= path_length:
			_despawn_virus(follow, false)
			count_changed = true

	if count_changed:
		_update_virus_count_label()


func _update_tower_attack(delta: float) -> void:
	if not _tower_is_placed or _guardian == null:
		return

	_tower_shot_cooldown_remaining = maxf(0.0, _tower_shot_cooldown_remaining - delta)
	if _tower_shot_cooldown_remaining > 0.0:
		return

	var target := _find_nearest_virus_in_range()
	if target == null:
		return

	_shoot_virus(target)
	_tower_shot_cooldown_remaining = TOWER_SHOT_COOLDOWN


func _find_nearest_virus_in_range() -> PathFollow2D:
	var best_target: PathFollow2D
	var best_distance_squared := INF
	var range := TOWER_RANGE_LEVEL * TOWER_RANGE_PIXELS_PER_LEVEL
	var range_squared := range * range

	for follow in _active_viruses:
		if not is_instance_valid(follow):
			continue

		var distance_squared := _guardian.global_position.distance_squared_to(follow.global_position)
		if distance_squared > range_squared or distance_squared >= best_distance_squared:
			continue

		best_target = follow
		best_distance_squared = distance_squared

	return best_target


func _shoot_virus(target: PathFollow2D) -> void:
	if not is_instance_valid(target):
		return

	var target_position := target.global_position
	var direction := target_position - _guardian.global_position
	if direction.length_squared() > 0.0:
		_guardian.rotation = direction.angle() - GUARDIAN_FORWARD_ROTATION

	_play_guardian_animation(GUARDIAN_SHOOT_ANIMATION)
	_spawn_laser(_guardian.global_position, target_position)
	_despawn_virus(target)


func _play_guardian_animation(animation_name: StringName) -> void:
	if _guardian == null:
		return

	if _guardian.has_method("play_animation"):
		_guardian.call("play_animation", animation_name)
		return

	if _guardian.sprite_frames == null or not _guardian.sprite_frames.has_animation(animation_name):
		return

	_guardian.animation = animation_name
	_guardian.frame = 0
	_guardian.frame_progress = 0.0
	_guardian.play()


func _spawn_laser(start_position: Vector2, end_position: Vector2) -> void:
	var glow := Line2D.new()
	glow.name = "BlueLaserGlow"
	glow.width = LASER_WIDTH * 2.25
	glow.default_color = Color(0.1, 0.55, 1.0, 0.35)
	glow.z_index = 99
	glow.points = PackedVector2Array([
		to_local(start_position),
		to_local(end_position)
	])
	add_child(glow)

	var laser := Line2D.new()
	laser.name = "BlueLaser"
	laser.width = LASER_WIDTH
	laser.default_color = Color(0.1, 0.55, 1.0, 1.0)
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
		follow.queue_free()

	if update_count:
		_update_virus_count_label()


func _update_virus_count_label() -> void:
	if _virus_count_label == null:
		return

	_virus_count_label.text = "Viruses: %d" % _active_viruses.size()


func _get_virus_spawn_progress() -> float:
	if _virus_path == null or _virus_path.curve == null or _virus_spawn == null:
		return 0.0

	var spawn_position := _virus_path.to_local(_virus_spawn.global_position)
	return _virus_path.curve.get_closest_offset(spawn_position)


func _create_path_dots() -> void:
	if _virus_path == null or _virus_path.curve == null:
		return

	_path_dot_container = _virus_path.get_node_or_null(^"RuntimePathDots") as Node2D
	if _path_dot_container == null:
		_path_dot_container = Node2D.new()
		_path_dot_container.name = "RuntimePathDots"
		_virus_path.add_child(_path_dot_container)

	for child in _path_dot_container.get_children():
		child.queue_free()

	var path_length := _virus_path.curve.get_baked_length()
	if path_length <= 0.0:
		return

	var circle_polygon := _build_circle_polygon(PATH_DOT_RADIUS, PATH_DOT_SEGMENTS)
	var distance := 0.0
	while distance <= path_length:
		_add_path_dot(_virus_path.curve.sample_baked(distance), circle_polygon)
		distance += PATH_DOT_SPACING

	_add_path_dot(_virus_path.curve.sample_baked(path_length), circle_polygon)


func _add_path_dot(local_position: Vector2, circle_polygon: PackedVector2Array) -> void:
	var dot := Polygon2D.new()
	dot.name = "PathDot"
	dot.position = local_position
	dot.polygon = circle_polygon
	dot.color = PATH_DOT_COLOR
	dot.z_index = 40
	_path_dot_container.add_child(dot)


func _build_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	return points


func _update_platform_highlight() -> void:
	_platform_highlight.size = PLATFORM_HIGHLIGHT_SIZE
	_platform_highlight.global_position = _guardian.global_position - PLATFORM_HIGHLIGHT_SIZE * 0.5
	_current_placement_shape = _find_placement_shape_at_position(_guardian.global_position)
	_drag_is_valid = _current_placement_shape != null
	_platform_highlight.color = PLATFORM_VALID_COLOR if _drag_is_valid else PLATFORM_INVALID_COLOR


func _get_or_create_platform_highlight() -> ColorRect:
	var highlight := get_node_or_null(platform_highlight_path) as ColorRect
	if highlight != null:
		return highlight

	highlight = ColorRect.new()
	highlight.name = "PlatformHighlight"
	add_child(highlight)
	return highlight


func _configure_platform_highlight() -> void:
	if _platform_highlight == null:
		return

	_platform_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_platform_highlight.size = PLATFORM_HIGHLIGHT_SIZE
	_platform_highlight.color = PLATFORM_INVALID_COLOR
	_platform_highlight.hide()


func _collect_placement_areas() -> void:
	_placement_areas.clear()
	if _placement_area != null:
		_placement_areas.append(_placement_area)

	for child in get_children():
		var area := child as Area2D
		if area == null or not String(area.name).begins_with("TowerPlacementArea"):
			continue
		if not _placement_areas.has(area):
			_placement_areas.append(area)


func _get_guardian_rect() -> Rect2:
	var size := PLATFORM_HIGHLIGHT_SIZE
	if _guardian.sprite_frames != null and _guardian.sprite_frames.has_animation(_guardian.animation):
		var texture := _guardian.sprite_frames.get_frame_texture(_guardian.animation, _guardian.frame)
		if texture != null:
			var scale := _guardian.global_scale
			size = texture.get_size() * Vector2(abs(scale.x), abs(scale.y))

	size.x = max(size.x, GUARDIAN_GRAB_SIZE.x)
	size.y = max(size.y, GUARDIAN_GRAB_SIZE.y)

	var top_left := _guardian.global_position - size * 0.5
	if not _guardian.centered:
		top_left = _guardian.global_position

	return Rect2(top_left, size)


func _get_sprite_rect(sprite: Sprite2D, minimum_size: Vector2) -> Rect2:
	var size := minimum_size
	if sprite.texture != null:
		var scale := sprite.global_scale
		size = sprite.texture.get_size() * Vector2(abs(scale.x), abs(scale.y))

	size.x = max(size.x, minimum_size.x)
	size.y = max(size.y, minimum_size.y)

	var top_left := sprite.global_position - size * 0.5
	if not sprite.centered:
		top_left = sprite.global_position

	return Rect2(top_left, size)


func _screen_to_canvas_position(screen_position: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_position


func _show_upgrade_panel() -> void:
	if _upgrade_panel == null:
		return

	var viewport_size := get_viewport_rect().size
	var tower_screen_position := get_canvas_transform() * _guardian.global_position
	var side := &"right"
	if tower_screen_position.x > viewport_size.x * 0.5:
		side = &"left"

	var shown_position := _get_upgrade_panel_position(side, false)
	var hidden_position := _get_upgrade_panel_position(side, true)
	_upgrade_panel_side = side
	_upgrade_panel_visible = true
	_upgrade_panel.custom_minimum_size = _get_upgrade_panel_size()
	_upgrade_panel.size = _get_upgrade_panel_size()
	_upgrade_panel.position = hidden_position
	_upgrade_panel.show()
	_run_upgrade_panel_tween(shown_position, true)


func _hide_upgrade_panel() -> void:
	if _upgrade_panel == null or not _upgrade_panel_visible:
		return

	_upgrade_panel_visible = false
	_run_upgrade_panel_tween(_get_upgrade_panel_position(_upgrade_panel_side, true), false)


func _run_upgrade_panel_tween(target_position: Vector2, keep_visible: bool) -> void:
	if _upgrade_panel_tween != null:
		_upgrade_panel_tween.kill()

	_upgrade_panel_tween = create_tween()
	_upgrade_panel_tween.tween_property(_upgrade_panel, "position", target_position, UPGRADE_PANEL_SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not keep_visible:
		_upgrade_panel_tween.tween_callback(Callable(_upgrade_panel, "hide"))


func _get_upgrade_panel_position(side: StringName, hidden: bool) -> Vector2:
	var viewport_size := get_viewport_rect().size
	var panel_size := _get_upgrade_panel_size()

	if side == &"left":
		var x_left := 0.0
		if hidden:
			x_left = -panel_size.x
		return Vector2(x_left, 0.0)

	var x_right := viewport_size.x - panel_size.x
	if hidden:
		x_right = viewport_size.x
	return Vector2(x_right, 0.0)


func _get_upgrade_panel_size() -> Vector2:
	var viewport_size := get_viewport_rect().size
	var max_width = min(UPGRADE_PANEL_MAX_WIDTH, viewport_size.x)
	var min_width = min(UPGRADE_PANEL_MIN_WIDTH, max_width)
	var width := clampf(
		viewport_size.x * UPGRADE_PANEL_WIDTH_RATIO,
		min_width,
		max_width
	)
	return Vector2(width, viewport_size.y)


func _find_placement_shape_at_position(global_position: Vector2) -> CollisionShape2D:
	for area in _placement_areas:
		for child in area.get_children():
			var collision_shape := child as CollisionShape2D
			if collision_shape == null or collision_shape.disabled:
				continue

			var rectangle_shape := collision_shape.shape as RectangleShape2D
			if rectangle_shape == null:
				continue

			var local_position := collision_shape.global_transform.affine_inverse() * global_position
			var rectangle := Rect2(-rectangle_shape.size * 0.5, rectangle_shape.size)
			if rectangle.has_point(local_position):
				return collision_shape

	return null


func _get_placement_area_center() -> Vector2:
	if _current_placement_shape != null:
		return _current_placement_shape.global_position

	if _placement_area == null:
		return _guardian.global_position

	return _placement_area.global_position
