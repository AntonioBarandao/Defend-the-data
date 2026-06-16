
extends Control

func _ready():
    $FormPanel/VBox/CreateButton.pressed.connect(_on_create_pressed)
    $FormPanel/VBox/BackButton.pressed.connect(_on_back_pressed)

func _on_create_pressed():
    var username = $FormPanel/VBox/UsernameInput.text
    var email = $FormPanel/VBox/EmailInput.text
    var password = $FormPanel/VBox/PasswordInput.text
    var confirm_password = $FormPanel/VBox/ConfirmPasswordInput.text

    if username == "" or email == "" or password == "":
        $FormPanel/VBox/StatusLabel.text = "Please fill in all fields."
        return

    if password != confirm_password:
        $FormPanel/VBox/StatusLabel.text = "Passwords do not match."
        return

    $FormPanel/VBox/StatusLabel.text = "Account created! (Database hookup later)"

func _on_back_pressed():
    get_tree().change_scene_to_file("res://Scenes/Menus/LoginScene.tscn")
