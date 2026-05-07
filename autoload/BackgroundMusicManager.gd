## Random background music playback shared by all scenes.
class_name BackgroundMusicManagerClass
extends Node

const MUSIC_DIR := "res://music/background_music"
const SUPPORTED_EXTENSIONS := ["mp3", "ogg", "wav"]

var tracks: Array[String] = []
var current_track_path: String = ""
var music_enabled := true

var _player: AudioStreamPlayer = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_player()
	refresh_tracks()
	if not tracks.is_empty():
		call_deferred("play_random_track")


func refresh_tracks() -> Array[String]:
	tracks.clear()

	var dir := DirAccess.open(MUSIC_DIR)
	if dir == null:
		push_warning("[BackgroundMusicManager] Missing music folder: %s" % MUSIC_DIR)
		return tracks.duplicate()

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and SUPPORTED_EXTENSIONS.has(file_name.get_extension().to_lower()):
			tracks.append("%s/%s" % [MUSIC_DIR, file_name])
		file_name = dir.get_next()
	dir.list_dir_end()

	tracks.sort()
	return tracks.duplicate()


func play_random_track() -> bool:
	if not music_enabled:
		return false

	if tracks.is_empty():
		refresh_tracks()
	if tracks.is_empty():
		return false

	_ensure_player()
	if _player == null:
		return false

	var candidates: Array[String] = tracks.duplicate()
	if candidates.size() > 1 and not current_track_path.is_empty():
		candidates.erase(current_track_path)

	while not candidates.is_empty():
		var index := _rng.randi_range(0, candidates.size() - 1)
		var path := candidates[index]
		candidates.remove_at(index)

		var stream: Resource = load(path)
		if stream is AudioStream:
			current_track_path = path
			_player.stop()
			_player.stream = stream
			_player.play()
			return true

	push_warning("[BackgroundMusicManager] No playable audio streams found in %s" % MUSIC_DIR)
	return false


func stop_music() -> void:
	if _player != null:
		_player.stop()


func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	if not music_enabled:
		stop_music()
	elif _player == null or not _player.playing:
		play_random_track()


func get_track_paths() -> Array[String]:
	if tracks.is_empty():
		refresh_tracks()
	return tracks.duplicate()


func is_playing_music() -> bool:
	return _player != null and _player.playing


func _ensure_player() -> void:
	if _player != null:
		return

	_player = AudioStreamPlayer.new()
	_player.name = "BackgroundMusicPlayer"
	_player.bus = "Master"
	_player.volume_db = -10.0
	add_child(_player)

	if not _player.finished.is_connected(_on_track_finished):
		_player.finished.connect(_on_track_finished)


func _on_track_finished() -> void:
	play_random_track()
