class_name CutsceneDemoDirector
extends Node

@export var game_path: NodePath = ^".."
@export var botnet_path: NodePath = ^"../BotnetLV3"
@export_range(1, 20, 1) var botnet_first_visible_wave := 6
@export_range(1, 20, 1) var botnet_cpu_wave := 10
@export var botnet_wave_six_position := Vector2(1054, 392)
@export var botnet_cpu_position := Vector2(1054, 448)

var _game: Node
var _botnet: BotnetLV


func _ready() -> void:
	_game = get_node_or_null(game_path)
	_botnet = get_node_or_null(botnet_path) as BotnetLV
	if _botnet != null:
		_botnet.deactivate()

	if _game == null:
		return

	if _game.has_signal("wave_started"):
		_game.connect("wave_started", Callable(self, "_on_wave_started"))
	if _game.has_signal("current_wave_changed"):
		_game.connect("current_wave_changed", Callable(self, "_on_current_wave_changed"))

	if _game.has_method("get_current_wave"):
		_update_botnet_for_wave(int(_game.call("get_current_wave")))


func _on_wave_started(wave_number: int) -> void:
	_update_botnet_for_wave(wave_number)


func _on_current_wave_changed(wave_number: int) -> void:
	_update_botnet_for_wave(wave_number)


func _update_botnet_for_wave(wave_number: int) -> void:
	if _botnet == null:
		return

	if wave_number < botnet_first_visible_wave:
		_botnet.deactivate()
		return

	var target_position := botnet_cpu_position if wave_number >= botnet_cpu_wave else botnet_wave_six_position
	_botnet.activate_at_position(target_position)
