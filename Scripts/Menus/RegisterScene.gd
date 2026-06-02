
extends Control

func _ready():
    $CreateButton.pressed.connect(_on_create_pressed)
    $BackButton.pressed.connect(_on_back_pressed)

func _on_create_pressed():
    var username = $UsernameInput.text
    var email = $EmailInput.text
    var password = $PasswordInput.text
    var confirm_password = $ConfirmPasswordInput.text

    if username == "" or email == "" or password == "":
        $StatusLabel.text = "Please fill in all fields."
        return

    if password != confirm_password:
        $StatusLabel.text = "Passwords do not match."
        return

    $StatusLabel.text = "Account created! (Database hookup later)"

func _on_back_pressed():
    get_tree().change_scene_to_file("res://scenes/LoginScene.tscn")
