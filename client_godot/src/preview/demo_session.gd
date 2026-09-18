extends RefCounted
signal changed

func select_scenario(_name: String) -> bool:
	return false

func get_messages() -> Array[Dictionary]:
	return []

func submit_text(_text: String) -> String:
	return ""

func settle(_id: String, _success: bool) -> bool:
	return false
