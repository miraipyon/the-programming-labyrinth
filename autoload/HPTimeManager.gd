## Quản lý HP và Timer cho gameplay.
## Công thức combat theo GDD §3-4.
extends Node

# --- Signals ---
signal hp_changed(current_hp: int, max_hp: int)
signal time_changed(time_remaining: float)
signal player_died
signal time_expired

# --- State ---
var max_hp: int = 100
var current_hp: int = 100
var time_remaining: float = 0.0
var timer_active: bool = false

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
	
	# Emit signal để cập nhật UI ngay lập tức
	hp_changed.emit(current_hp, max_hp)
	time_changed.emit(time_remaining)


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

	# Trừ current_hp, clamp về [0, max_hp] [cite: 3]
	current_hp -= amount
	current_hp = clampi(current_hp, 0, max_hp)
	
	# Emit hp_changed [cite: 3]
	hp_changed.emit(current_hp, max_hp)
	
	# Nếu current_hp <= 0 -> emit player_died [cite: 3]
	if current_hp <= 0:
		player_died.emit()


func heal(amount: int) -> void:
	if amount <= 0:
		return

	# Cộng current_hp, clamp về [0, max_hp] [cite: 3]
	current_hp += amount
	current_hp = clampi(current_hp, 0, max_hp)
	
	# Emit hp_changed [cite: 3]
	hp_changed.emit(current_hp, max_hp)


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
