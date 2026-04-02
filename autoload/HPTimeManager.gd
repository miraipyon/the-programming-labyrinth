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
	# TODO: Nếu timer_active == true:
	# - Giảm time_remaining đi delta
	# - Emit signal time_changed
	# - Nếu time_remaining <= 0 -> emit time_expired, timer_active = false
	pass


# --- Init ---
func init_for_stage(chapter: int) -> void:
	# TODO: Đặt max_hp = 100, current_hp = 100
	# time_remaining = thời gian theo chapter (360/480/600/720)
	# HINT: var time_map := {1: 360.0, 2: 480.0, 3: 600.0, 4: 720.0}
	pass


func start_timer() -> void:
	# TODO: timer_active = true
	pass


func stop_timer() -> void:
	# TODO: timer_active = false
	pass


# --- HP Operations ---
func take_damage(amount: int) -> void:
	# TODO: Trừ current_hp, clamp về [0, max_hp]
	# Emit hp_changed
	# Nếu current_hp <= 0 -> emit player_died
	pass


func heal(amount: int) -> void:
	# TODO: Cộng current_hp, clamp về [0, max_hp]
	# Emit hp_changed
	pass


# --- Combat Calculations (GDD §3) ---
func calculate_hp_loss(fix_rate: float, hit_base: int) -> int:
	# TODO: Trả về ceil((1.0 - fix_rate) * hit_base)
	# Đây là công thức HP_LOSS_TURN trong GDD
	# fix_rate = tỷ lệ fix đúng (0.0 đến 1.0)
	# hit_base = sát thương gốc của quái
	return 0


func apply_wrong_line_penalty() -> void:
	# TODO: Gọi take_damage(5) — penalty khi chọn sai dòng lỗi
	pass
