extends Control

func _ready():
	$FormPanel/VBox/LoginButton.pressed.connect(_on_login_pressed)
	$FormPanel/VBox/BackButton.pressed.connect(_on_back_pressed)
	$FormPanel/VBox/RegisterButton.pressed.connect(_on_register_pressed)

func _on_login_pressed():
	get_tree().change_scene_to_file(
		"res://Scenes/Gameplay/Demo_Game.tscn"
	)

func _on_back_pressed():
	get_tree().change_scene_to_file(
		"res://Scenes/Menus/MainMenu.tscn"
	)

func _on_register_pressed():
	get_tree().change_scene_to_file(
		"res://Scenes/Menus/RegisterScene.tscn"
	)
