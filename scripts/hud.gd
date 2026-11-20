extends CanvasLayer
## Giao diện trong game: thanh chỉ số, mục tiêu, độ ồn.

@onready var hp_bar: ProgressBar = %HpBar
@onready var food_bar: ProgressBar = %FoodBar
@onready var water_bar: ProgressBar = %WaterBar
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var noise_bar: ProgressBar = %NoiseBar
@onready var objective_label: Label = %Objective
@onready var hint_label: Label = %Hint


func _ready() -> void:
	objective_label.text = "MỤC TIÊU · " + Game.objective
	Game.objective_changed.connect(func(t: String) -> void: objective_label.text = "MỤC TIÊU · " + t)


func _process(_delta: float) -> void:
	hp_bar.value = Game.hp
	food_bar.value = Game.food
	water_bar.value = Game.water
	stamina_bar.value = Game.stamina
	noise_bar.value = Game.noise * 100.0
	hint_label.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
