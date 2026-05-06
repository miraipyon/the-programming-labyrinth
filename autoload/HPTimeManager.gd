## Quản lý HP và Timer cho gameplay.
## Công thức combat theo GDD §3-4.
extends Node

# --- Signals ---
signal hp_changed(current_hp: int, max_hp: int)
signal time_changed(time_remaining: float)
signal player_died
signal time_expired
signal artifact_changed(active_artifacts: Dictionary)

# --- State ---
var max_hp: int = 100
var current_hp: int = 100
var time_remaining: float = 0.0
var timer_active: bool = false
var active_artifacts: Dictionary = {}

# --- Constants (từ GDD) ---
# WRONG_LINE_PENALTY = 5 HP (mất máu khi chọn sai dòng)
# HP_LOSS_TURN = ceil((1 - FIX_RATE_TURN) * HIT_BASE)
# FIX_RATE_TURN = số bug fix đúng / tổng bugs trong snippet
# Time limit theo chapter: {1: 360s, 2: 480s, 3: 600s, 4: 720s}


func _process(delta: float) -> void:
	if timer_active:
		# Giảm time_remaining đi delta [cite: 2]
		time_remaining = maxf(0.0, time_remaining - delta)

		# Emit signal time_changed [cite: 2]
		time_changed.emit(time_remaining)

		# Nếu time_remaining <= 0 -> emit time_expired, timer_active = false [cite: 2, 3]
		if time_remaining <= 0.0:
			timer_active = false
			time_expired.emit()


# --- Init ---
func init_for_stage(chapter: int) -> void:
	# Đặt max_hp = 100, current_hp = 100 [cite: 3]
	max_hp = 100
	current_hp = max_hp

	# time_remaining = thời gian theo chapter [cite: 3]
	var time_map := {1: 360.0, 2: 480.0, 3: 600.0, 4: 720.0}

	# Dùng .get() để lấy giá trị an toàn, mặc định là 360.0 nếu chapter không tồn tại
	time_remaining = time_map.get(chapter, 360.0)

	timer_active = false # Đảm bảo timer chưa chạy ngay khi vừa init
	active_artifacts.clear()

	# Emit signal để cập nhật UI ngay lập tức
	hp_changed.emit(current_hp, max_hp)
	time_changed.emit(time_remaining)
	artifact_changed.emit(active_artifacts.duplicate(true))


func start_timer() -> void:
	# timer_active = true [cite: 3]
	timer_active = true


func stop_timer() -> void:
	# timer_active = false [cite: 3]
	timer_active = false


# --- HP Operations ---
func take_damage(amount: int) -> void:
	if amount <= 0:
		return

	_commit_damage(amount)


func heal(amount: int) -> void:
	if amount <= 0:
		return

	# Cộng current_hp, clamp về [0, max_hp] [cite: 3]
	current_hp += amount
	current_hp = clampi(current_hp, 0, max_hp)

	# Emit hp_changed [cite: 3]
	hp_changed.emit(current_hp, max_hp)


func restore_time(seconds: float) -> void:
	if seconds <= 0.0:
		return
	time_remaining = maxf(0.0, time_remaining + seconds)
	time_changed.emit(time_remaining)


# --- Combat Calculations (GDD §3) ---
func calculate_hp_loss(fix_rate: float, hit_base: int) -> int:
	# Trả về ceil((1.0 - fix_rate) * hit_base) [cite: 4]
	# ceil() trả về float, cần ép kiểu về int để đúng định dạng trả về của hàm
	var safe_fix_rate := clampf(fix_rate, 0.0, 1.0)
	var safe_hit_base := maxi(hit_base, 0)
	return int(ceil((1.0 - safe_fix_rate) * float(safe_hit_base)))


func apply_wrong_line_penalty() -> void:
	# Gọi take_damage(5) — penalty khi chọn sai dòng lỗi [cite: 4]
	take_damage(5)


## Activate a stage artifact.
## Artifacts can only be activated once per stage.
func activate_artifact(item_id: String) -> Dictionary:
	var key := item_id.strip_edges()
	var result := {
		"success": false,
		"item_id": key,
		"message": ""
	}

	if active_artifacts.has(key):
		result.message = "Artifact already activated for this stage."
		if key == "github_cape":
			var cape_state: Dictionary = active_artifacts[key]
			if int(cape_state.get("revives_left", 0)) <= 0:
				result.message = "GitHub Cape revive already used for this stage."
		elif key == "runtime_patch":
			var patch_state: Dictionary = active_artifacts[key]
			if int(patch_state.get("skips_left", 0)) <= 0:
				result.message = "Runtime Patch already used for this stage."
		return result

	match key:
		"github_cape":
			active_artifacts[key] = {"revives_left": 1}
			result.success = true
			result.message = "GitHub Cape revive is ready."
		"ide_armor":
			active_artifacts[key] = {"damage_reduction": 0.2}
			result.success = true
			result.message = "IDE Armor is reducing damage."
		"runtime_patch":
			active_artifacts[key] = {"skips_left": 1}
			result.success = true
			result.message = "Runtime Patch will block the next hit."
		_:
			result.message = "Invalid artifact."

	if bool(result.success):
		artifact_changed.emit(active_artifacts.duplicate(true))
	return result


func apply_turn_damage(fix_rate: float, hit_base: int, wrong_line_count: int = 0) -> Dictionary:
	var safe_wrong_lines := maxi(wrong_line_count, 0)
	var penalty_damage := safe_wrong_lines * 5
	var monster_damage := 0
	var artifact_effects: Array[String] = []

	if fix_rate < 1.0:
		monster_damage = calculate_hp_loss(fix_rate, hit_base)

	if monster_damage > 0 and active_artifacts.has("runtime_patch"):
		var runtime_state: Dictionary = active_artifacts["runtime_patch"]
		var skips_left := int(runtime_state.get("skips_left", 0))
		if skips_left > 0:
			monster_damage = 0
			runtime_state["skips_left"] = skips_left - 1
			active_artifacts["runtime_patch"] = runtime_state
			artifact_effects.append("runtime_patch")

	if monster_damage > 0 and active_artifacts.has("ide_armor"):
		var armor_state: Dictionary = active_artifacts["ide_armor"]
		var reduction := float(armor_state.get("damage_reduction", 0.2))
		monster_damage = int(ceil(float(monster_damage) * (1.0 - clampf(reduction, 0.0, 1.0))))
		artifact_effects.append("ide_armor")

	var total_damage := monster_damage + penalty_damage
	if total_damage > 0:
		_commit_damage(total_damage)

	artifact_changed.emit(active_artifacts.duplicate(true))
	return {
		"monster_damage": monster_damage,
		"penalty_damage": penalty_damage,
		"total_damage": total_damage,
		"artifact_effects": artifact_effects
	}


func _commit_damage(amount: int) -> void:
	current_hp = clampi(current_hp - amount, 0, max_hp)

	if current_hp <= 0 and _try_revive():
		hp_changed.emit(current_hp, max_hp)
		return

	hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		player_died.emit()


func _try_revive() -> bool:
	if not active_artifacts.has("github_cape"):
		return false

	var cape_state: Dictionary = active_artifacts["github_cape"]
	var revives_left := int(cape_state.get("revives_left", 0))
	if revives_left <= 0:
		return false

	cape_state["revives_left"] = revives_left - 1
	active_artifacts["github_cape"] = cape_state
	current_hp = maxi(1, int(ceil(float(max_hp) * 0.5)))
	artifact_changed.emit(active_artifacts.duplicate(true))
	return true
