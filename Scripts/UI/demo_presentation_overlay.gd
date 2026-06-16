class_name DemoPresentationOverlay
extends CanvasLayer

signal laser_upgrade_requested
signal guardian_upgrade_requested

const POPUP_DURATION := 1.45
const BUCKS_ICON_SIZE := Vector2(38, 38)
const UPGRADE_BUTTON_OFFSET := Vector2(0, -114)
const SPARKLE_DOT_COUNT := 22
const SPARKLE_RADIUS_MIN := 20.0
const SPARKLE_RADIUS_MAX := 118.0
const COST_READY_COLOR := Color(0.91, 0.98, 1.0, 1.0)
const COST_LOCKED_COLOR := Color(1.0, 0.48, 0.48, 1.0)

@export var naked_power_font: Font
@export var cyber_bucks_texture: Texture2D

@onready var _world_popups: Control = $Root/WorldPopups
@onready var _guardian_upgrade_button: Button = $Root/GuardianUpgradeButton
@onready var _guardian_upgrade_cost_label: Label = $Root/GuardianUpgradeButton/Content/CostRow/Amount
@onready var _laser_upgrade_button: Button = $Root/LaserUpgradeButton
@onready var _laser_upgrade_cost_label: Label = $Root/LaserUpgradeButton/Content/CostRow/Amount


func _ready() -> void:
	_configure_upgrade_button(_guardian_upgrade_button)
	_configure_upgrade_button(_laser_upgrade_button)
	_guardian_upgrade_button.pressed.connect(func() -> void: guardian_upgrade_requested.emit())
	_laser_upgrade_button.pressed.connect(func() -> void: laser_upgrade_requested.emit())


func show_guardian_destroy_popup(
	guardian_position: Vector2,
	damage_points: int,
	damage_cooldown: float
) -> void:
	show_tower_destroy_popup(guardian_position, 5, damage_points, damage_cooldown)


func show_tower_destroy_popup(
	tower_position: Vector2,
	cyberbuck_reward: int,
	damage_points: int,
	damage_cooldown: float
) -> void:
	var left_popup := HBoxContainer.new()
	left_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_popup.modulate = Color(1, 1, 1, 0)
	left_popup.scale = Vector2(0.84, 0.84)
	left_popup.add_theme_constant_override("separation", 8)

	var icon := TextureRect.new()
	icon.custom_minimum_size = BUCKS_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = cyber_bucks_texture
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_popup.add_child(icon)

	var bucks_label := _make_popup_label("+%d Cyber Bucks" % cyberbuck_reward, 28, Color(1.0, 0.88, 0.26, 1.0))
	left_popup.add_child(bucks_label)
	_world_popups.add_child(left_popup)
	_position_popup(left_popup, tower_position + Vector2(-150, -58), Vector2(1.0, 0.5))
	_animate_popup(left_popup, Vector2(-14, -70))

	var stats_label := _make_popup_label(
		"Damage: %d point\nCooldown: %.1fs" % [damage_points, damage_cooldown],
		24,
		Color(0.84, 0.92, 1.0, 1.0)
	)
	_world_popups.add_child(stats_label)
	_position_popup(stats_label, tower_position + Vector2(142, -54), Vector2(0.0, 0.5))
	_animate_popup(stats_label, Vector2(16, -64))


func set_guardian_upgrade_button_state(
	guardian_screen_position: Vector2,
	deployed: bool,
	can_upgrade: bool,
	hovered: bool,
	cost: int,
	affordable: bool
) -> void:
	_set_upgrade_button_state(
		_guardian_upgrade_button,
		_guardian_upgrade_cost_label,
		guardian_screen_position,
		deployed,
		can_upgrade,
		hovered,
		cost,
		affordable
	)


func set_laser_upgrade_button_state(
	laser_screen_position: Vector2,
	deployed: bool,
	can_upgrade: bool,
	hovered: bool,
	cost: int,
	affordable: bool
) -> void:
	_set_upgrade_button_state(
		_laser_upgrade_button,
		_laser_upgrade_cost_label,
		laser_screen_position,
		deployed,
		can_upgrade,
		hovered,
		cost,
		affordable
	)


func guardian_upgrade_button_has_point(screen_position: Vector2) -> bool:
	return _button_has_point(_guardian_upgrade_button, screen_position)


func laser_upgrade_button_has_point(screen_position: Vector2) -> bool:
	return _button_has_point(_laser_upgrade_button, screen_position)


func upgrade_button_has_point(screen_position: Vector2) -> bool:
	return guardian_upgrade_button_has_point(screen_position) or laser_upgrade_button_has_point(screen_position)


func show_laser_upgrade_fx(laser_position: Vector2) -> void:
	show_tower_upgrade_fx(laser_position)


func show_tower_upgrade_fx(tower_position: Vector2) -> void:
	var evolve_label := _make_popup_label("EVOLVED", 30, Color(0.48, 0.83, 1.0, 1.0))
	evolve_label.add_theme_color_override("font_outline_color", Color(0.02, 0.07, 0.22, 1.0))
	_world_popups.add_child(evolve_label)
	_position_popup(evolve_label, tower_position + Vector2(0, -138), Vector2(0.5, 0.5))
	_animate_popup(evolve_label, Vector2(0, -64))

	for index in range(SPARKLE_DOT_COUNT):
		_spawn_sparkle_dot(tower_position, index)


func _configure_upgrade_button(button: Button) -> void:
	button.hide()
	button.add_theme_font_override("font", naked_power_font)


func _set_upgrade_button_state(
	button: Button,
	cost_label: Label,
	screen_position: Vector2,
	deployed: bool,
	can_upgrade: bool,
	hovered: bool,
	cost: int,
	affordable: bool
) -> void:
	button.visible = deployed and can_upgrade and hovered
	if not button.visible:
		return

	button.disabled = not affordable
	cost_label.text = str(maxi(0, cost))
	cost_label.add_theme_color_override("font_color", COST_READY_COLOR if affordable else COST_LOCKED_COLOR)
	button.reset_size()
	button.global_position = screen_position + UPGRADE_BUTTON_OFFSET - button.size * 0.5


func _button_has_point(button: Button, screen_position: Vector2) -> bool:
	return button.is_visible_in_tree() and button.get_global_rect().has_point(screen_position)


func _make_popup_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", naked_power_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _spawn_sparkle_dot(laser_position: Vector2, index: int) -> void:
	var dot := Panel.new()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size = Vector2(8, 8)
	dot.modulate = Color(1, 1, 1, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.35, 0.82, 1.0, 0.96)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.72, 0.94, 1.0, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	dot.add_theme_stylebox_override("panel", style)

	var angle := TAU * float(index) / float(SPARKLE_DOT_COUNT)
	var start_radius := SPARKLE_RADIUS_MIN + float(index % 5) * 4.0
	var end_radius := SPARKLE_RADIUS_MAX + float(index % 4) * 10.0
	var direction := Vector2(cos(angle), sin(angle))
	var start_position := laser_position + direction * start_radius - dot.size * 0.5
	var end_position := laser_position + direction * end_radius - dot.size * 0.5
	dot.position = start_position
	_world_popups.add_child(dot)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(dot, "modulate:a", 1.0, 0.1)
	tween.tween_property(dot, "position", end_position, 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(dot, "scale", Vector2(0.15, 0.15), 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_property(dot, "modulate:a", 0.0, 0.18)
	tween.tween_callback(Callable(dot, "queue_free"))


func _position_popup(control: Control, world_position: Vector2, anchor: Vector2) -> void:
	control.reset_size()
	var popup_size := control.size
	if popup_size == Vector2.ZERO:
		popup_size = control.get_combined_minimum_size()

	control.global_position = world_position - popup_size * anchor


func _animate_popup(control: Control, travel: Vector2) -> void:
	var start_position := control.position
	control.pivot_offset = control.get_combined_minimum_size() * 0.5

	var motion_tween := create_tween()
	motion_tween.set_parallel(true)
	motion_tween.tween_property(control, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	motion_tween.tween_property(control, "position", start_position + travel, POPUP_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var fade_tween := create_tween()
	fade_tween.tween_property(control, "modulate:a", 1.0, 0.16)
	fade_tween.tween_interval(0.74)
	fade_tween.tween_property(control, "modulate:a", 0.0, 0.42)
	fade_tween.tween_callback(Callable(control, "queue_free"))
