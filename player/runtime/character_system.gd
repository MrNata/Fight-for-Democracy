extends RefCounted
## Lazy visual resources; catalog entries never load all sprites simultaneously.
static func load_sprite(config: Dictionary, root: String) -> Texture2D:
	if str(config.get("sprite","")).is_empty():
		return null
	var asset = root.path_join(config.sprite)
	if asset.begins_with("res://") and ResourceLoader.exists(asset):
		return load(asset) as Texture2D
	var image = Image.load_from_file(asset)
	return ImageTexture.create_from_image(image) if image != null else null

static func frame_rect(texture: Texture2D, animation: Dictionary, tick: int) -> Rect2:
	var columns = int(animation.columns)
	var rows = int(animation.rows)
	var index = int(tick * float(animation.fps) / 60.0) % (columns*rows)
	var cell = texture.get_size() / Vector2(columns,rows)
	return Rect2(Vector2(index%columns,index/columns)*cell,cell)

static func attack_frame_rect(texture: Texture2D, animation: Dictionary, move: Dictionary, action_frame: int) -> Rect2:
	var columns = int(animation.columns)
	var sheet_size = columns*int(animation.rows)
	var clip: Dictionary = move.get("animation",{})
	var start = int(clip.get("start",0))
	var count = int(clip.get("count",sheet_size))
	var duration = int(move.startup+move.active+move.recovery)
	var index = start + mini(count-1,int(float(action_frame)*count/duration))
	var cell = texture.get_size()/Vector2(columns,int(animation.rows))
	return Rect2(Vector2(index%columns,index/columns)*cell,cell)
