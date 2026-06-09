class_name CyberQuestionHud
extends CanvasLayer

signal question_solved(reward: int)

const CATEGORY_CYBERSECURITY := "cybersecurity"
const CATEGORY_NETWORKING := "networking"
const DIFFICULTY_EASY := "easy"
const DIFFICULTY_MEDIUM := "medium"
const DIFFICULTY_HARD := "hard"
const REWARDS := {
	DIFFICULTY_EASY: 10,
	DIFFICULTY_MEDIUM: 25,
	DIFFICULTY_HARD: 50
}
const QUESTIONS := {
	CATEGORY_CYBERSECURITY: {
		DIFFICULTY_EASY: [
			{
				"prompt": "Which practice helps protect an account if a password is stolen?",
				"answers": ["Enable multi-factor authentication", "Reuse one simple password", "Share passwords in chat", "Turn off software updates"],
				"correct": 0
			}
		],
		DIFFICULTY_MEDIUM: [
			{
				"prompt": "What should you do before opening an unexpected email attachment?",
				"answers": ["Verify the sender and reason first", "Open it quickly", "Forward it to everyone", "Disable antivirus alerts"],
				"correct": 0
			}
		],
		DIFFICULTY_HARD: [
			{
				"prompt": "Why should passwords be hashed before storage?",
				"answers": ["To verify them without storing the original password", "To make them easier to read", "To remove the need for login checks", "To send them faster over Wi-Fi"],
				"correct": 0
			}
		]
	},
	CATEGORY_NETWORKING: {
		DIFFICULTY_EASY: [
			{
				"prompt": "Which device commonly directs traffic between different networks?",
				"answers": ["Router", "Keyboard", "Monitor", "Headphones"],
				"correct": 0
			}
		],
		DIFFICULTY_MEDIUM: [
			{
				"prompt": "Which protocol is used for encrypted web browsing?",
				"answers": ["HTTPS", "FTP", "Telnet", "HTTP only"],
				"correct": 0
			}
		],
		DIFFICULTY_HARD: [
			{
				"prompt": "What information does a firewall rule commonly inspect before allowing traffic?",
				"answers": ["IP addresses, ports, and protocols", "Screen brightness", "Mouse speed", "Keyboard layout"],
				"correct": 0
			}
		]
	}
}

var cyberbucks := 0
var _selected_category := CATEGORY_CYBERSECURITY
var _current_wave := 0
var _current_reward := 0
var _current_question: Dictionary = {}

@onready var _question_panel: PanelContainer = $Root/QuestionPanel
@onready var _selection_view: VBoxContainer = $Root/QuestionPanel/Margin/Content/SelectionView
@onready var _question_view: VBoxContainer = $Root/QuestionPanel/Margin/Content/QuestionView
@onready var _cybersecurity_button: Button = $Root/QuestionPanel/Margin/Content/SelectionView/CategoryButtons/CybersecurityButton
@onready var _networking_button: Button = $Root/QuestionPanel/Margin/Content/SelectionView/CategoryButtons/NetworkingButton
@onready var _easy_button: Button = $Root/QuestionPanel/Margin/Content/SelectionView/DifficultyRow/EasyCard/EasyButton
@onready var _medium_button: Button = $Root/QuestionPanel/Margin/Content/SelectionView/DifficultyRow/MediumCard/MediumButton
@onready var _hard_button: Button = $Root/QuestionPanel/Margin/Content/SelectionView/DifficultyRow/HardCard/HardButton
@onready var _easy_reward_label: Label = $Root/QuestionPanel/Margin/Content/SelectionView/DifficultyRow/EasyCard/EasyReward/Amount
@onready var _medium_reward_label: Label = $Root/QuestionPanel/Margin/Content/SelectionView/DifficultyRow/MediumCard/MediumReward/Amount
@onready var _hard_reward_label: Label = $Root/QuestionPanel/Margin/Content/SelectionView/DifficultyRow/HardCard/HardReward/Amount
@onready var _question_label: Label = $Root/QuestionPanel/Margin/Content/QuestionView/QuestionText
@onready var _current_reward_label: Label = $Root/QuestionPanel/Margin/Content/QuestionView/CurrentReward/Amount
@onready var _answer_buttons := [
	$Root/QuestionPanel/Margin/Content/QuestionView/AnswerButtons/AnswerButton1,
	$Root/QuestionPanel/Margin/Content/QuestionView/AnswerButtons/AnswerButton2,
	$Root/QuestionPanel/Margin/Content/QuestionView/AnswerButtons/AnswerButton3,
	$Root/QuestionPanel/Margin/Content/QuestionView/AnswerButtons/AnswerButton4
]
@onready var _feedback_label: Label = $Root/QuestionPanel/Margin/Content/QuestionView/FeedbackLabel
@onready var _back_button: Button = $Root/QuestionPanel/Margin/Content/QuestionView/BackButton
@onready var _cyberbuck_amount_label: Label = $Root/CyberBuckCounter/CounterBox/Amount


func _ready() -> void:
	_question_panel.hide()
	_easy_reward_label.text = "+%d" % REWARDS[DIFFICULTY_EASY]
	_medium_reward_label.text = "+%d" % REWARDS[DIFFICULTY_MEDIUM]
	_hard_reward_label.text = "+%d" % REWARDS[DIFFICULTY_HARD]
	_update_cyberbuck_amount()
	_select_category(CATEGORY_CYBERSECURITY)

	_cybersecurity_button.pressed.connect(Callable(self, "_select_category").bind(CATEGORY_CYBERSECURITY))
	_networking_button.pressed.connect(Callable(self, "_select_category").bind(CATEGORY_NETWORKING))
	_easy_button.pressed.connect(Callable(self, "_start_question").bind(DIFFICULTY_EASY))
	_medium_button.pressed.connect(Callable(self, "_start_question").bind(DIFFICULTY_MEDIUM))
	_hard_button.pressed.connect(Callable(self, "_start_question").bind(DIFFICULTY_HARD))
	_back_button.pressed.connect(Callable(self, "_show_selection_view"))
	for index in _answer_buttons.size():
		_answer_buttons[index].pressed.connect(Callable(self, "_answer_selected").bind(index))


func show_wave_question(wave_number: int) -> void:
	_current_wave = wave_number
	_show_selection_view()
	_question_panel.show()


func add_cyberbucks(amount: int) -> void:
	cyberbucks += max(0, amount)
	_update_cyberbuck_amount()


func _select_category(category: String) -> void:
	_selected_category = category
	var cyber_selected := category == CATEGORY_CYBERSECURITY
	_cybersecurity_button.add_theme_color_override("font_color", Color(0.35, 0.75, 1.0, 1.0) if cyber_selected else Color.WHITE)
	_networking_button.add_theme_color_override("font_color", Color(1.0, 0.82, 0.22, 1.0) if not cyber_selected else Color.WHITE)


func _show_selection_view() -> void:
	_feedback_label.text = ""
	_selection_view.show()
	_question_view.hide()


func _start_question(difficulty: String) -> void:
	var question_set := QUESTIONS[_selected_category][difficulty] as Array
	if question_set.is_empty():
		return

	var question_index: int = max(0, _current_wave - 1) % question_set.size()
	_current_question = question_set[question_index] as Dictionary
	_current_reward = int(REWARDS[difficulty])
	_question_label.text = String(_current_question["prompt"])
	_current_reward_label.text = "+%d CyberBucks" % _current_reward
	_feedback_label.text = ""

	var answers := _current_question["answers"] as Array
	for index in _answer_buttons.size():
		var button := _answer_buttons[index] as Button
		if index < answers.size():
			button.text = String(answers[index])
			button.show()
		else:
			button.hide()

	_selection_view.hide()
	_question_view.show()


func _answer_selected(answer_index: int) -> void:
	if _current_question.is_empty():
		return

	var correct_index := int(_current_question["correct"])
	if answer_index != correct_index:
		_feedback_label.text = "Not quite. Try again to unlock the next wave."
		return

	add_cyberbucks(_current_reward)
	_feedback_label.text = ""
	_question_panel.hide()
	question_solved.emit(_current_reward)


func _update_cyberbuck_amount() -> void:
	_cyberbuck_amount_label.text = str(cyberbucks)
