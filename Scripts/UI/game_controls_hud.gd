class_name GameControlsHud
extends CanvasLayer

signal reset_pressed
signal start_wave_pressed
signal add_ten_pressed
signal add_hundred_pressed
signal exit_pressed

@onready var _reset_button: Button = $Root/BottomRightControls/ResetTowerButton
@onready var _wave_button: Button = $Root/BottomRightControls/StartWaveButton
@onready var _add_ten_button: Button = $Root/VirusBatchControls/AddTenVirusesButton
@onready var _add_hundred_button: Button = $Root/VirusBatchControls/AddHundredVirusesButton
@onready var _menu_button: Button = $Root/MainMenuButton
@onready var _menu_panel: PanelContainer = $Root/MainMenuPanel
@onready var _continue_button: Button = $Root/MainMenuPanel/Margin/Options/ContinueButton
@onready var _settings_button: Button = $Root/MainMenuPanel/Margin/Options/SettingsButton
@onready var _exit_button: Button = $Root/MainMenuPanel/Margin/Options/ExitButton


func _ready() -> void:
	_menu_panel.hide()
	_reset_button.pressed.connect(func() -> void: reset_pressed.emit())
	_wave_button.pressed.connect(func() -> void: start_wave_pressed.emit())
	_add_ten_button.pressed.connect(func() -> void: add_ten_pressed.emit())
	_add_hundred_button.pressed.connect(func() -> void: add_hundred_pressed.emit())
	_menu_button.pressed.connect(toggle_menu)
	_continue_button.pressed.connect(hide_menu)
	_settings_button.pressed.connect(hide_menu)
	_exit_button.pressed.connect(func() -> void: exit_pressed.emit())


func set_wave_button(text: String, disabled: bool) -> void:
	_wave_button.text = text
	_wave_button.disabled = disabled


func set_spawn_buttons_disabled(disabled: bool) -> void:
	_add_ten_button.disabled = disabled
	_add_hundred_button.disabled = disabled


func toggle_menu() -> void:
	if _menu_panel.visible:
		hide_menu()
	else:
		show_menu()


func show_menu() -> void:
	_menu_panel.show()


func hide_menu() -> void:
	_menu_panel.hide()
