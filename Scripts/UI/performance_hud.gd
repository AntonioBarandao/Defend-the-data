class_name PerformanceHud
extends CanvasLayer

@onready var _fps_label: Label = $Root/StatusPanel/Margin/Content/FPSLabel
@onready var _virus_count_label: Label = $Root/StatusPanel/Margin/Content/VirusCountLabel


func set_fps(current_fps: int, target_fps: int) -> void:
	if _fps_label == null:
		return

	_fps_label.text = "FPS: %d / %d" % [current_fps, target_fps]


func set_virus_count(count: int) -> void:
	if _virus_count_label == null:
		return

	_virus_count_label.text = "Viruses: %d" % count
