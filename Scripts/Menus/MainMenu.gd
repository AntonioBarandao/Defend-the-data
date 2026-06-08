extends Control

@onready var background: TextureRect = $Background
@onready var scanline: ColorRect = $Scanline
@onready var start_button: Button = $MenuPanel/VBox/StartButton
@onready var login_button: Button = $MenuPanel/VBox/LoginButton
@onready var options_button: Button = $MenuPanel/VBox/OptionsButton
@onready var quit_button: Button = $MenuPanel/VBox/QuitButton
@onready var status_label: Label = $StatusLabel
@onready var sign_out_button: Button = $MenuPanel/VBox/SignOutButton

var scan_speed := 120.0
var background_zoom_amount := 0.015
var time_passed := 0.0

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	login_button.pressed.connect(_on_login_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	sign_out_button.pressed.connect(_on_sign_out_pressed)

func _process(delta: float) -> void:
	time_passed += delta


func _on_start_pressed() -> void:
	status_label.text = "Starting game..."
	get_tree().change_scene_to_file("res://Scenes/Gameplay/PresentationScene.tscn")

func _on_login_pressed() -> void:
	status_label.text = "Opening login..."
	get_tree().change_scene_to_file("res://Scenes/Menus/LoginScene.tscn")

func _on_options_pressed() -> void:
	status_label.text = "Options menu not connected yet."

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_sign_out_pressed():
	status_label.text = "Sign out functionality coming soon."
