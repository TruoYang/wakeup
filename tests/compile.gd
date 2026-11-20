extends Node
## Nạp mọi file .gd để bắt lỗi cú pháp.
func _ready() -> void:
	var bad := 0
	var stack := ["res://scripts"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for d in DirAccess.get_directories_at(dir):
			stack.append(dir + "/" + d)
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				var s: GDScript = load(dir + "/" + f)
				if s == null or not s.can_instantiate():
					bad += 1
					print("LỖI: ", dir + "/" + f)
	print("file lỗi: ", bad)
	get_tree().quit()
