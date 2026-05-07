## SoundManager: Phát âm thanh hiệu ứng (SFX) cho các sự kiện game.
## Autoload singleton – gọi SoundManager.play("event_name") từ bất kỳ đâu.
class_name SoundManagerClass
extends Node

const SFX_DIR := "res://music/audio/"

# --- Mapping sự kiện → file âm thanh ---
const SFX_MAP := {
	# UI tổng quát
	"ui_click":         "click_001.ogg",
	"ui_back":          "back_001.ogg",
	"ui_open":          "open_001.ogg",
	"ui_close":         "close_001.ogg",
	"ui_select":        "select_001.ogg",
	"ui_toggle":        "toggle_001.ogg",
	"ui_switch":        "switch_001.ogg",
	"ui_scroll":        "scroll_001.ogg",
	"ui_question":      "question_001.ogg",

	# Hành động xác nhận / từ chối
	"confirm":          "confirmation_001.ogg",
	"error":            "error_001.ogg",

	# Item / Artifact
	"item_pickup":      "bong_001.ogg",
	"item_drop":        "drop_001.ogg",
	"item_use":         "pluck_001.ogg",
	"chest_open":       "maximize_001.ogg",

	# Combat
	"combat_start":     "maximize_002.ogg",
	"combat_submit":    "confirmation_002.ogg",
	"combat_correct":   "confirmation_003.ogg",
	"combat_wrong":     "error_002.ogg",
	"combat_penalty":   "glitch_001.ogg",
	"combat_end":       "minimize_001.ogg",

	# Portal / stage
	"portal_activate":  "glass_001.ogg",
	"stage_clear":      "maximize_005.ogg",
	"game_over":        "glitch_004.ogg",

	# Timer cảnh báo
	"tick_warn":        "tick_001.ogg",
	"tick_critical":    "tick_004.ogg",

	# Scratch noise khi viết code
	"code_scratch":     "scratch_001.ogg",
}

# Số lượng kênh song song tối đa (tránh bị cắt tiếng khi nhiều SFX liên tiếp)
const POOL_SIZE := 6

var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0
var _cache: Dictionary = {}   # path → AudioStream
var sfx_enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_pool()


func play(event: String) -> void:
	if not sfx_enabled:
		return
	var file_name: String = SFX_MAP.get(event, "")
	if file_name.is_empty():
		return
	var path := SFX_DIR + file_name
	_play_path(path)


func play_path(path: String) -> void:
	if not sfx_enabled:
		return
	_play_path(path)


func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled


# ── Nội bộ ──────────────────────────────────────────────────────────────────

func _play_path(path: String) -> void:
	var stream: AudioStream = _get_stream(path)
	if stream == null:
		return
	var player := _pool[_pool_index]
	player.stop()
	player.stream = stream
	player.play()
	_pool_index = (_pool_index + 1) % POOL_SIZE


func _get_stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		push_warning("[SoundManager] SFX not found: %s" % path)
		return null
	var res: Resource = load(path)
	if res is AudioStream:
		_cache[path] = res
		return res
	return null


func _build_pool() -> void:
	for _i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = -6.0
		add_child(p)
		_pool.append(p)
