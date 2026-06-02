extends Control

func _ready():
	$BackButton.pressed.connect(_on_back_pressed)
	$RegisterButton.pressed.connect(_on_register_pressed)

func _on_back_pressed():
	get_tree().change_scene_to_file(
        "res://scenes/MainMenu.tscn"
	)

func _on_register_pressed():
	get_tree().change_scene_to_file(
        "res://scenes/RegisterScene.tscn"
	)
