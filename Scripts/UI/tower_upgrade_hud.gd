class_name TowerUpgradeHud
extends CanvasLayer

signal laser_upgrade_pressed

enum MenuMode {
	NONE,
	GUARDIAN,
	LASER
}

@onready var _menu_panel: PanelContainer = $Root/MenuPanel
@onready var _title_label: Label = $Root/MenuPanel/Margin/Content/Title
@onready var _portrait_row: Control = $Root/MenuPanel/Margin/Content/PortraitRow
@onready var _guardian_mode_container: Control = $Root/MenuPanel/Margin/Content/VBoxContainer
@onready var _upgrade_path_container: Control = $Root/MenuPanel/Margin/Content/VBoxContainer2
@onready var _laser_level_label: Label = $Root/MenuPanel/Margin/Content/VBoxContainer2/LevelLabel
@onready var _laser_power_label: Label = $Root/MenuPanel/Margin/Content/VBoxContainer2/PowerLabel
@onready var _laser_range_label: Label = $Root/MenuPanel/Margin/Content/VBoxContainer2/RangeLabel
@onready var _laser_cost_row: Control = $Root/MenuPanel/Margin/Content/VBoxContainer2/CostRow
@onready var _laser_cost_label: Label = $Root/MenuPanel/Margin/Content/VBoxContainer2/CostRow/CostAmount
@onready var _laser_upgrade_button: Button = $Root/MenuPanel/Margin/Content/VBoxContainer2/ButtonPath4

var _current_mode := MenuMode.NONE


func _ready() -> void:
	_menu_panel.hide()
	_laser_upgrade_button.pressed.connect(func() -> void: laser_upgrade_pressed.emit())


func set_laser_stats(
	level: int,
	max_level: int,
	power: int,
	attack_range: float,
	can_upgrade: bool,
	upgrade_cost: int = 0
) -> void:
	_laser_level_label.text = "Level %d / %d" % [level, max_level]
	_laser_power_label.text = "Power: %d" % power
	_laser_range_label.text = "Range: %d px" % roundi(attack_range)

	var at_max_level := level >= max_level
	_laser_cost_row.visible = not at_max_level
	_laser_upgrade_button.disabled = at_max_level or not can_upgrade
	_laser_upgrade_button.text = "Max Level" if at_max_level else "Upgrade"
	if at_max_level:
		_laser_cost_label.text = ""
	else:
		_laser_cost_label.text = str(maxi(0, upgrade_cost))


func show_guardian_panel() -> void:
	_current_mode = MenuMode.GUARDIAN
	_title_label.text = "Cyber Guardian"
	_portrait_row.show()
	_guardian_mode_container.show()
	_upgrade_path_container.hide()
	_menu_panel.show()


func hide_guardian_panel() -> void:
	if _current_mode == MenuMode.GUARDIAN:
		hide_all()


func is_guardian_panel_visible() -> bool:
	return _menu_panel.visible and _current_mode == MenuMode.GUARDIAN


func guardian_panel_has_point(screen_position: Vector2) -> bool:
	return is_guardian_panel_visible() and _menu_panel.get_global_rect().has_point(screen_position)


func show_laser_panel() -> void:
	_current_mode = MenuMode.LASER
	_title_label.text = "Laser Turret"
	_portrait_row.hide()
	_guardian_mode_container.hide()
	_upgrade_path_container.show()
	_menu_panel.show()


func hide_laser_panel() -> void:
	if _current_mode == MenuMode.LASER:
		hide_all()


func is_laser_panel_visible() -> bool:
	return _menu_panel.visible and _current_mode == MenuMode.LASER


func laser_panel_has_point(screen_position: Vector2) -> bool:
	return is_laser_panel_visible() and _menu_panel.get_global_rect().has_point(screen_position)


func hide_all() -> void:
	_current_mode = MenuMode.NONE
	_menu_panel.hide()
