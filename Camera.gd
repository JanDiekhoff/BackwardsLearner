extends Camera2D

func update_size(rect,cell_size):
	limit_left = rect.position.x * cell_size.x
	limit_right = rect.end.x * cell_size.x
	limit_top = rect.position.y * cell_size.y
	limit_bottom = rect.end.y * cell_size.y
