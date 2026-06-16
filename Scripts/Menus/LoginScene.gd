extends Control

var auth

<<<<<<< HEAD
func _ready():
	auth = AuthWrapper.new()

	$BackButton.pressed.connect(_on_back_pressed)
	$RegisterButton.pressed.connect(_on_register_pressed)
=======
func _on_login_pressed():
	get_tree().change_scene_to_file(
		"res://Scenes/Gameplay/Admin_Sandbox.tscn"
	)
>>>>>>> 4f184935da47f214ef9486204354f4d648908567

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_register_pressed():
	get_tree().change_scene_to_file("res://scenes/RegisterScene.tscn")

func _on_login_pressed():
	var username = $UsernameInput.text
	var password = $PasswordInput.text

	var success = auth.login(username, password)

	if success:
		print("Login successful")
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	else:
		print("Login failed")
