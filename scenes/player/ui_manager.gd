extends Control

@onready var credit = $credit_label

func _ready() -> void:
	Wallet.money_changed.connect(update_credit)
	update_credit()
	get_viewport().size_changed.connect(resize_ui)
	resize_ui()

func resize_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(1920, 1080)
	var viewport_size = get_viewport_rect().size
	var factor = minf(viewport_size.x / 1920.0, viewport_size.y / 1080.0)
	scale = Vector2.ONE * factor
	position = (viewport_size - size * factor) / 2


func update_credit() -> void:
	credit.text = str("Money: $", Wallet.money)
