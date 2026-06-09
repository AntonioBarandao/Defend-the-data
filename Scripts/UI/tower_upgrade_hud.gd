class_name TowerUpgradeHud
extends CanvasLayer

signal guardian_scale_changed(value: float)
signal laser_upgrade_pressed

@onready var _guardian_panel: PanelContainer = $Root/GuardianPanel
@onready var _guardian_scale_slider: HSlider = $Root/GuardianPanel/Margin/Content/ScaleRow/GuardianScaleSlider
@onready var _guardian_scale_value_label: Label = $Root/GuardianPanel/Margin/Content/ScaleRow/GuardianScaleValue
@onready var _laser_panel: PanelContainer = $Root/LaserPanel
@onready var _laser_level_label: Label = $Root/LaserPanel/Margin/Content/LevelLabel
@onready var _laser_power_label: Label = $Root/LaserPanel/Margin/Content/PowerLabel
@onready var _laser_range_label: Label = $Root/LaserPanel/Margin/Content/RangeLabel
@onready var _laser_upgrade_button: Button = $Root/LaserPanel/Margin/Content/UpgradeButton


func _ready() -> void:
	_guardian_panel.hide()
	_laser_panel.hide()
	_guardian_scale_slider.value_changed.connect(func(value: float) -> void: guardian_scale_changed.emit(value))
	_laser_upgrade_button.pressed.connect(func() -> void: laser_upgrade_pressed.emit())


func configure_guardian_scale(min_value: float, max_value: float, step: float, value: float) -> void:
	_guardian_scale_slider.min_value = min_value
	_guardian_scale_slider.max_value = max_value
	_guardian_scale_slider.step = step
	set_guardian_scale(value)


func set_guardian_scale(value: float) -> void:
	_guardian_scale_slider.set_value_no_signal(value)
	_guardian_scale_value_label.text = "%.2fx" % value


func set_laser_stats(level: int, max_level: int, power: int, attack_range: float, can_upgrade: bool) -> void:
	_laser_level_label.text = "Level %d / %d" % [level, max_level]
	_laser_power_label.text = "Power: %d" % power
	_laser_range_label.text = "Range: %d px" % roundi(attack_range)
	_laser_upgrade_button.disabled = not can_upgrade


func show_guardian_panel() -> void:
	_laser_panel.hide()
	_guardian_panel.show()


func hide_guardian_panel() -> void:
	_guardian_panel.hide()


func is_guardian_panel_visible() -> bool:
	return _guardian_panel.visible


func guardian_panel_has_point(screen_position: Vector2) -> bool:
	return _guardian_panel.visible and _guardian_panel.get_global_rect().has_point(screen_position)


func show_laser_panel() -> void:
	_guardian_panel.hide()
	_laser_panel.show()


func hide_laser_panel() -> void:
	_laser_panel.hide()


func is_laser_panel_visible() -> bool:
	return _laser_panel.visible


func laser_panel_has_point(screen_position: Vector2) -> bool:
	return _laser_panel.visible and _laser_panel.get_global_rect().has_point(screen_position)


func hide_all() -> void:
	_guardian_panel.hide()
	_laser_panel.hide()
