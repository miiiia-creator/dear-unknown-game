class_name StampView
extends Control
## A passport stamp: double border, city name, country, date. Drawn rather than
## authored so every new destination gets one for free.

var city_id: String = ""
var tilt := -0.12          ## radians; hand-stamped things are never straight


func setup(id: String, tilt_radians: float = -0.12) -> void:
	city_id = id
	tilt = tilt_radians
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var city := GameData.city(city_id)
	if city.is_empty():
		return
	var ink: Color = GameData.city_palette(city_id)[1]
	ink.a = 0.85

	var side := minf(size.x, size.y)
	var centre := size * 0.5

	draw_set_transform(centre, tilt, Vector2.ONE)

	var half := side * 0.44
	var box := Rect2(-half, -half * 0.80, half * 2.0, half * 1.60)
	_ring(box, ink, maxf(1.5, side * 0.018))
	_ring(box.grow(-side * 0.045), ink, maxf(1.0, side * 0.010))

	var font: Font = Pal.ui_font
	var small := int(side * 0.072)
	var country: String = String(city["country"]).to_upper()
	var cw := font.get_string_size(country, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
	draw_string(font, Vector2(-cw * 0.5, -side * 0.14), country,
			HORIZONTAL_ALIGNMENT_LEFT, -1, small, ink)

	var name_size := int(side * 0.14)
	var city_name: String = String(city["name"]).to_upper()
	var nw := font.get_string_size(city_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
	draw_string(font, Vector2(-nw * 0.5, side * 0.05), city_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, ink)

	var date := SaveGame.stamp_date(city_id)
	if date != "":
		var dw := font.get_string_size(date, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
		draw_string(font, Vector2(-dw * 0.5, side * 0.24), date,
				HORIZONTAL_ALIGNMENT_LEFT, -1, small, ink)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ring(box: Rect2, col: Color, width: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = col
	sb.set_border_width_all(int(width))
	sb.set_corner_radius_all(int(box.size.y * 0.18))
	sb.corner_detail = 8
	draw_style_box(sb, box)
