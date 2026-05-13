## SpriteAnimator – autoload chứa toàn bộ metadata animation frame-by-frame.
## Cung cấp helper để load texture arrays và tính frame index theo thời gian.
extends Node

# ---------------------------------------------------------------------------
# PLAYER (MC) – paths
# ---------------------------------------------------------------------------

## Idle animations (4 hướng) – dùng trong Player.gd trên map
const MC_IDLE_DIRS := {
	"down":  {"base": "res://assets/MC/Animation/Idle/idle_down/idle",   "count": 7},
	"up":    {"base": "res://assets/MC/Animation/Idle/idle_up/idle",     "count": 7},
	"right": {"base": "res://assets/MC/Animation/Idle/idle_right/idle",  "count": 7},
	"left":  {"base": "res://assets/MC/Animation/Idle/idle_left/idle",   "count": 7},
}

## Walking animations (4 hướng) – dùng trong Player.gd
## Lưu ý: walking-right/left dùng prefix "right"/"left", down/up dùng "down"/"up"
const MC_WALK_DIRS := {
	"down":  {"base": "res://assets/MC/Animation/walking-downward/down",  "count": 9},
	"up":    {"base": "res://assets/MC/Animation/walking-upward/up",      "count": 12},
	"right": {"base": "res://assets/MC/Animation/walking-right/right",    "count": 12},
	"left":  {"base": "res://assets/MC/Animation/walking-left/left",      "count": 11},
}

## Combat attack-idle animations – dùng trong CombatConsole
const MC_ATTACK_IDLE_LEFT  := {
	"base": "res://assets/MC/Animation/Idle/attack_left_idle/attack_left_idle_animation",
	"count": 9,
}
const MC_ATTACK_IDLE_RIGHT := {
	"base": "res://assets/MC/Animation/Idle/attack_right_idle/attack_right_idle_animation",
	"count": 9,
}
const MC_HIT := {
	"base": "res://assets/MC/Animation/Hit/hit",
	"count": 11,
}

# ---------------------------------------------------------------------------
# ENEMIES – Idle & Attack frame sequences
# ---------------------------------------------------------------------------

const ENEMY_ANIM := {
	"syntax_slime": {
		"idle":   {"base": "res://assets/syntax_slime/Animation/Idle/idle",           "count": 6},
		"attack": {"base": "res://assets/syntax_slime/Animation/Attack/attackanimation","count": 14},
	},
	"semicolon_wisp": {
		"idle":   {"base": "res://assets/semicolon_wisp/Animation/Idle/idle",          "count": 7},
		"attack": {"base": "res://assets/semicolon_wisp/Animation/Attack/attack",      "count": 12},
	},
	"null_shadow": {
		"idle":   {"base": "res://assets/null_shadow/Animation/Idle/idle",             "count": 8},
		"attack": {"base": "res://assets/null_shadow/Animation/Attack/attack",         "count": 14},
	},
	"branch_phantom": {
		"idle":   {"base": "res://assets/branch_phantom/Animation/Idle/idle",          "count": 7},
		"attack": {"base": "res://assets/branch_phantom/Animation/Attack/attack",      "count": 12},
	},
	"type_mismatch_medusa": {
		"idle":   {"base": "res://assets/type_mismatch_medusa/Animation/Idle/idle",    "count": 9},
		"attack": {"base": "res://assets/type_mismatch_medusa/Animation/Attack/attack","count": 14},
	},
	"infinite_golem": {
		"idle":   {"base": "res://assets/infinite_golem/Animation/Idle/idle",          "count": 9},
		"attack": {"base": "res://assets/infinite_golem/Animation/Attack/attack",      "count": 12},
	},
	"boundary_hydra": {
		"idle":   {"base": "res://assets/boundary_hydra/Animation/Idle/idle",          "count": 8},
		"attack": {"base": "res://assets/boundary_hydra/Animation/Attack/attack",      "count": 15},
	},
	"flow_architect": {
		"idle":   {"base": "res://assets/flow_architect/Animation/Idle/idle",          "count": 12},
		"attack": {"base": "res://assets/flow_architect/Animation/Attack/attack",      "count": 16},
	},
	"logic_bomb_boss": {
		"idle":   {"base": "res://assets/logic_bomb_boss/Animation/Idle/idle",         "count": 7},
		"attack": {"base": "res://assets/logic_bomb_boss/Animation/Attack/attack",     "count": 17},
	},
}

# ---------------------------------------------------------------------------
# Texture cache – tránh load lại nhiều lần
# ---------------------------------------------------------------------------
var _cache: Dictionary = {}


func get_player_idle_dirs() -> Dictionary:
	return MC_IDLE_DIRS.duplicate(true)


func get_player_walk_dirs() -> Dictionary:
	return MC_WALK_DIRS.duplicate(true)


func get_player_combat_anims() -> Dictionary:
	return {
		"attack_idle_left": MC_ATTACK_IDLE_LEFT.duplicate(true),
		"attack_idle_right": MC_ATTACK_IDLE_RIGHT.duplicate(true),
		"hit": MC_HIT.duplicate(true),
	}


func get_enemy_anim_catalog() -> Dictionary:
	return ENEMY_ANIM.duplicate(true)


## Load một mảng Texture2D từ thông tin animation dict {base, count}.
## Trả về Array[Texture2D] (có thể rỗng nếu không tìm thấy file).
func load_frames(anim_info: Dictionary) -> Array[Texture2D]:
	var base: String = str(anim_info.get("base", ""))
	var count: int   = int(anim_info.get("count", 0))
	if base.is_empty() or count <= 0:
		return []

	var cache_key := "%s|%d" % [base, count]
	if _cache.has(cache_key):
		return _copy_frames(_cache[cache_key])

	var frames: Array[Texture2D] = []
	for i in range(1, count + 1):
		var path := "%s%d.png" % [base, i]
		var abs_path = ProjectSettings.globalize_path(path)
		if ResourceLoader.exists(path) or FileAccess.file_exists(abs_path) or FileAccess.file_exists(path):
			var tex = load(path) as Texture2D
			if tex == null and FileAccess.file_exists(abs_path):
				var img = Image.new()
				if img.load(abs_path) == OK:
					tex = ImageTexture.create_from_image(img)
			
			if tex != null:
				frames.append(tex)
	_cache[cache_key] = _copy_frames(frames)
	return _copy_frames(frames)


func _copy_frames(frames: Array) -> Array[Texture2D]:
	var copied: Array[Texture2D] = []
	for frame in frames:
		if frame is Texture2D:
			copied.append(frame)
	return copied


## Tính frame index từ elapsed time, fps và tổng số frames.
## Trả về -1 nếu frames rỗng.
func frame_index(elapsed: float, fps: float, frame_count: int) -> int:
	if frame_count <= 0:
		return -1
	var safe_fps := maxf(fps, 1.0)
	return int(floor(elapsed * safe_fps)) % frame_count


## Trả về texture hiện tại từ array frames theo elapsed time + fps.
func current_texture(frames: Array[Texture2D], elapsed: float, fps: float) -> Texture2D:
	if frames.is_empty():
		return null
	var idx := frame_index(elapsed, fps, frames.size())
	if idx < 0:
		return null
	return frames[idx]
