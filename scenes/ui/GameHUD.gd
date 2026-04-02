## Hiển thị UI Thanh Máu và Thời Gian còn lại trên cao
extends CanvasLayer

func _ready() -> void:
	# TODO: Lắng nghe Signal "hp_changed" và "time_changed" từ `HPTimeManager`
	# Dùng `$Label.text = str(...)` để ghi ra màn hình
	pass

func update_hp(hp: int, max_hp: int) -> void:
	# TODO: Cập nhật giao diện thanh máu (TextureProgressBar)
	pass

func update_time(time_left: float) -> void:
	# TODO: Dịch giây thành phút:giây (05:00) cho đẹp mắt
	# Báo khung màu đỏ cảnh bảo nếu time_left < 30
	pass
