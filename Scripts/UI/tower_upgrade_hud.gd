class_name TowerUpgradeHud
extends CanvasLayer

signal laser_upgrade_pressed

@onready var _guardian_panel: PanelContainer = $Root/GuardianPanel
@onready var _laser_panel: PanelContainer = $Root/LaserPanel
@onready var _laser_level_label: Label = $Root/LaserPanel/Margin/Content/LevelLabel
@onready var _laser_power_label: Label = $Root/LaserPanel/Margin/Content/PowerLabel
@onready var _laser_range_label: Label = $Root/LaserPanel/Margin/Content/RangeLabel
@onready var _laser_upgrade_button: Button = $Root/LaserPanel/Margin/Content/UpgradeButton


func _ready() -> void:
	_guardian_panel.hide()
	_laser_panel.hide()
	_laser_upgrade_button.pressed.connect(func() -> void: laser_upgrade_pressed.emit())


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
