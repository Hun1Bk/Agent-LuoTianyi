extends Control
## The composition root owns window lifecycle; no network services yet.


func _ready() -> void:
	get_window().min_size = Vector2i(960, 640)
