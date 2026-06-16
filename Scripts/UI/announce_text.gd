class_name AnnounceText
extends CanvasLayer

@export_range(0.1, 2.0, 0.05) var entry_duration := 0.42
@export_range(0.1, 2.0, 0.05) var exit_duration := 0.34
@export_range(0.2, 8.0, 0.1) var default_hold_duration := 3.0
@export_range(0.0, 160.0, 1.0) var top_margin := 34.0

@onready var _root: Control = $Root
@onready var _panel: PanelContainer = $Root/MessagePanel
@onready var _label: Label = $Root/MessagePanel/Margin/Label

var _message_tween: Tween


func _ready() -> void:
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.hide()


func show_message(message: String, hold_duration: float = -1.0) -> void:
	if _message_tween != null:
		_message_tween.kill()

	_label.text = message
	_panel.show()
	await get_tree().process_frame

	var viewport_size := get_viewport().get_visible_rect().size
	var final_position := Vector2((viewport_size.x - _panel.size.x) * 0.5, top_margin)
	var hidden_position := final_position + Vector2(0.0, -_panel.size.y - top_margin - 16.0)
	var visible_duration := default_hold_duration if hold_duration < 0.0 else hold_duration

	_panel.position = hidden_position
	_panel.modulate = Color(1, 1, 1, 0)
	_message_tween = create_tween()
	_message_tween.tween_property(_panel, "position", final_position, entry_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_message_tween.parallel().tween_property(_panel, "modulate", Color.WHITE, entry_duration * 0.75)
	_message_tween.tween_interval(visible_duration)
	_message_tween.tween_property(_panel, "position", hidden_position, exit_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_message_tween.parallel().tween_property(_panel, "modulate", Color(1, 1, 1, 0), exit_duration * 0.75)
	_message_tween.tween_callback(_panel.hide)
