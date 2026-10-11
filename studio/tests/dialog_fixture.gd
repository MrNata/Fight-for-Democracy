extends "res://editor/studio_app.gd"
## Tests supply the chosen file; decoding, copying and validation stay real.
var chosen_file = ""

func file_picker(_mode: int, _filters: Array, callback: Callable) -> void:
	callback.call(chosen_file)
