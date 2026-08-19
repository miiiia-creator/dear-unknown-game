class_name PostcardView
extends Control
## A city postcard, drawn procedurally from the city palette and three of its
## discoveries. Has a front (the picture) and a back (stamp, postmark, message).

const RATIO := 1.5           ## 3:2, like a real postcard

var city_id: String = ""
var message: String = ""
var from_name: String = ""
var to_name: String = ""
var face := "front":
	set(value):
		face = value
		queue_redraw()

## The city's painting, if it has one. A postcard front should be a picture;
## three pixel icons in a row were a stand-in for not having one.
const ART_DIR := "res://assets/postcards/"

var _city: Dictionary = {}
var _palette: Array = []
var _art: Texture2D
var _art_luma := 1.0


func setup(id: String, msg: String = "", sender: String = "", recipient: String = "") -> void:
	city_id = id
	message = msg
	from_name = sender
	to_name = recipient
	_city = GameData.city(id)
	_palette = GameData.city_palette(id)
	_load_art(id)
	queue_redraw()


func _load_art(id: String) -> void:
	_art = null
	for ext in [".png", ".jpg", ".jpeg", ".webp"]:
		var path: String = ART_DIR + id + str(ext)
		if ResourceLoader.exists(path):
			_art = load(path)
			if _art != null:
				break
	if _art == null:
		return
	# Sample the band the title sits over so light artwork gets dark lettering
	# and dark artwork gets light.
	var img := _art.get_image()
	if img == null:
		return
	var w := img.get_width()
	var h := img.get_height()
	var total := 0.0
	var count := 0
	for y in range(int(h * 0.70), h, maxi(1, h / 16)):
		for x in range(0, w, maxi(1, w / 32)):
			total += img.get_pixel(x, y).get_luminance()
			count += 1
	_art_luma = total / maxf(1.0, float(count))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func flip() -> void:
	face = "back" if face == "front" else "front"


## Largest 3:2 rectangle that fits, centred.
func _card_rect() -> Rect2:
	var w := size.x
	var h := w / RATIO
	if h > size.y:
		h = size.y
		w = h * RATIO
	return Rect2(((size - Vector2(w, h)) * 0.5).floor(), Vector2(w, h).floor())


func _draw() -> void:
	if _city.is_empty():
		return
	var card := _card_rect()

	var paper: Color = _palette[0]
	var accent: Color = _palette[1]
	var deep: Color = _palette[2]

	# Soft drop shadow, then the card.
	var shadow := Color(0, 0, 0, 0.12)
	_rounded(card.grow(0.0).abs(), shadow, Color(0, 0, 0, 0), 14)
	_rounded(card.grow(-2.0), paper, deep.lerp(paper, 0.6), 12, 2)

	if face == "front":
		_draw_front(card, accent, deep)
	else:
		_draw_back(card, accent, deep, paper)


func _draw_front(card: Rect2, accent: Color, deep: Color) -> void:
	if _art != null:
		_draw_painted_front(card)
		return
	_draw_placeholder_front(card, accent, deep)


## The painting, cropped to the card and captioned.
func _draw_painted_front(card: Rect2) -> void:
	var inner := card.grow(-2.0)
	var tex_size := Vector2(_art.get_width(), _art.get_height())
	var img_aspect := tex_size.x / tex_size.y
	var box_aspect := inner.size.x / inner.size.y

	# Cover: fill the card, crop the overflow, never letterbox.
	var src := Rect2(Vector2.ZERO, tex_size)
	if box_aspect > img_aspect:
		var keep := tex_size.x / box_aspect
		src = Rect2(Vector2(0, (tex_size.y - keep) * 0.5), Vector2(tex_size.x, keep))
	else:
		var keep_w := tex_size.y * box_aspect
		src = Rect2(Vector2((tex_size.x - keep_w) * 0.5, 0), Vector2(keep_w, tex_size.y))
	draw_texture_rect_region(_art, inner, src)

	var font: Font = Pal.ui_font
	var dark := _art_luma < 0.45
	var type_col: Color = _palette[0].lightened(0.55) if dark else _palette[2]
	var halo := Color(0, 0, 0, 0.5) if dark else Color(_palette[0], 0.55)

	var name_size := int(card.size.y * 0.135)
	var city_name: String = String(_city["name"]).to_upper()
	_draw_tracked(font, city_name,
			Vector2(card.get_center().x, card.position.y + card.size.y * 0.82),
			name_size, type_col, card.size.y * 0.030, halo)

	var sub := "%s  %s" % [_city["flag"], String(_city["country"]).to_upper()]
	var sub_size := int(card.size.y * 0.052)
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size).x
	draw_string_outline(font, Vector2(card.get_center().x - sw * 0.5,
			card.position.y + card.size.y * 0.91), sub,
			HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, 4, halo)
	draw_string(font, Vector2(card.get_center().x - sw * 0.5,
			card.position.y + card.size.y * 0.91), sub,
			HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, type_col)


## Cities without artwork yet: three discoveries standing on a horizon.
func _draw_placeholder_front(card: Rect2, accent: Color, deep: Color) -> void:
	var puzzles: Array = _city.get("puzzles", [])
	if puzzles.is_empty():
		return
	var inner := card.grow(-card.size.y * 0.06)

	var hero: Dictionary = puzzles[-1]
	var hero_rect := Rect2(
		inner.position + Vector2(inner.size.x * 0.30, inner.size.y * 0.06),
		Vector2(inner.size.x * 0.40, inner.size.y * 0.56))
	_draw_art(hero["art"], hero_rect, deep)

	var left: Dictionary = puzzles[mini(2, puzzles.size() - 1)]
	var right: Dictionary = puzzles[mini(4, puzzles.size() - 1)]
	var side := Vector2(inner.size.x * 0.20, inner.size.y * 0.30)
	_draw_art(left["art"], Rect2(inner.position + Vector2(inner.size.x * 0.04,
			inner.size.y * 0.28), side), accent)
	_draw_art(right["art"], Rect2(inner.position + Vector2(inner.size.x * 0.76,
			inner.size.y * 0.28), side), accent)

	var y := inner.position.y + inner.size.y * 0.64
	draw_line(Vector2(inner.position.x, y),
			Vector2(inner.position.x + inner.size.x, y), accent, maxf(1.0, card.size.y * 0.006))

	var font: Font = Pal.ui_font
	_draw_tracked(font, String(_city["name"]).to_upper(),
			Vector2(card.get_center().x, y + card.size.y * 0.20),
			int(card.size.y * 0.155), deep, card.size.y * 0.035)

	var sub := "%s  %s" % [_city["flag"], String(_city["country"]).to_upper()]
	var sub_size := int(card.size.y * 0.058)
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size).x
	draw_string(font, Vector2(card.get_center().x - sw * 0.5, y + card.size.y * 0.29),
			sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, accent)


func _draw_back(card: Rect2, accent: Color, deep: Color, paper: Color) -> void:
	# The bottom strip is the collection row, so the writing area stops above it.
	var strip_h := card.size.y * 0.26
	var inner := card.grow(-card.size.y * 0.08)
	inner.size.y -= strip_h
	var font: Font = Pal.ui_font

	# Stamp, top-right, with a mini landmark inside it.
	var s := card.size.y * 0.26
	var stamp := Rect2(Vector2(inner.position.x + inner.size.x - s, inner.position.y),
			Vector2(s, s * 1.15))
	_rounded(stamp, paper.lerp(accent, 0.18), accent, 3, 2)
	var puzzles: Array = _city.get("puzzles", [])
	if not puzzles.is_empty():
		_draw_art(puzzles[-1]["art"], stamp.grow(-s * 0.16), deep)

	# Postmark: two arcs and the date.
	var pm := stamp.position + Vector2(-s * 0.85, s * 0.50)
	draw_arc(pm, s * 0.42, 0, TAU, 40, accent, maxf(1.0, card.size.y * 0.005), true)
	draw_arc(pm, s * 0.50, 0, TAU, 40, accent, maxf(1.0, card.size.y * 0.004), true)
	var date := SaveGame.stamp_date(city_id)
	if date != "":
		var ds := int(card.size.y * 0.028)
		var dw := font.get_string_size(date, HORIZONTAL_ALIGNMENT_LEFT, -1, ds).x
		draw_string(font, pm + Vector2(-dw * 0.5, ds * 0.35), date,
				HORIZONTAL_ALIGNMENT_LEFT, -1, ds, accent)

	# Vertical divider between the message and the address.
	var mid := inner.position.x + inner.size.x * 0.52
	draw_line(Vector2(mid, inner.position.y + inner.size.y * 0.05),
			Vector2(mid, inner.position.y + inner.size.y * 0.95),
			accent.lerp(paper, 0.5), maxf(1.0, card.size.y * 0.004))

	# What is written on the card: the letter that arrived with it, or — when the
	# player is composing something to send — their own words instead.
	var text := message
	var handwritten := true
	if text.strip_edges() == "":
		text = String(_city.get("letter", {}).get("body", ""))
		handwritten = false

	# The final letter is much longer than the others, so the type shrinks to
	# fit rather than the letter being cut off mid-thought.
	var msg_size := int(card.size.y * 0.062)
	var msg_w := mid - inner.position.x - card.size.x * 0.04
	var room := int(inner.size.y * 0.74 / (msg_size * 1.45))
	var lines := _wrap_paragraphs(font, text, msg_size, msg_w)
	while lines.size() > room and msg_size > int(card.size.y * 0.030):
		msg_size -= 1
		room = int(inner.size.y * 0.74 / (msg_size * 1.45))
		lines = _wrap_paragraphs(font, text, msg_size, msg_w)

	var ly := inner.position.y + inner.size.y * 0.16
	for i in mini(lines.size(), room):
		draw_string(font, Vector2(inner.position.x, ly), lines[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, msg_size,
				deep if handwritten else deep.lerp(accent, 0.25))
		ly += msg_size * 1.45

	if from_name != "":
		draw_string(font, Vector2(inner.position.x, inner.position.y + inner.size.y * 0.93),
				"— " + from_name, HORIZONTAL_ALIGNMENT_LEFT, -1, msg_size, accent)

	# Address side: ruled lines plus who it is for.
	var ax := mid + card.size.x * 0.04
	var aw := inner.position.x + inner.size.x - ax
	var ay := inner.position.y + inner.size.y * 0.55
	if to_name != "":
		draw_string(font, Vector2(ax, ay - msg_size * 0.6), to_name,
				HORIZONTAL_ALIGNMENT_LEFT, -1, msg_size, deep)
	for i in 3:
		draw_line(Vector2(ax, ay + i * msg_size * 1.5),
				Vector2(ax + aw, ay + i * msg_size * 1.5),
				accent.lerp(paper, 0.55), maxf(1.0, card.size.y * 0.004))

	_draw_collection(card, strip_h, accent, deep, paper)


## Every discovery in the city as a small stamp along the foot of the card.
##
## A postcard picture is a view, not an inventory: only three or four things fit
## into a landscape, and food and souvenirs never belong in one. This row is
## where the rest of a destination gets its due, and it still works at twenty
## puzzles a city where cramming them into the painting would not.
func _draw_collection(card: Rect2, strip_h: float, accent: Color, deep: Color,
		paper: Color) -> void:
	var puzzles: Array = _city.get("puzzles", [])
	if puzzles.is_empty():
		return
	var font: Font = Pal.ui_font

	var top := card.position.y + card.size.y - strip_h
	var pad := card.size.y * 0.06
	draw_line(Vector2(card.position.x + pad, top),
			Vector2(card.position.x + card.size.x - pad, top),
			accent.lerp(paper, 0.55), maxf(1.0, card.size.y * 0.004))

	var label_size := int(card.size.y * 0.032)
	var done := 0
	for p in puzzles:
		if SaveGame.is_solved(p["id"]):
			done += 1
	draw_string(font, Vector2(card.position.x + pad, top + label_size * 1.5),
			"COLLECTED  %d / %d" % [done, puzzles.size()],
			HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, accent)

	# Slots sized to fit however many the city has, so twenty still lays out.
	var count := puzzles.size()
	var usable := card.size.x - pad * 2.0
	var slot := usable / float(count)
	var box := minf(slot * 0.82, strip_h * 0.46)
	var y := top + strip_h * 0.44

	for i in count:
		var p: Dictionary = puzzles[i]
		var centre_x := card.position.x + pad + slot * (float(i) + 0.5)
		var frame := Rect2(Vector2(centre_x - box * 0.5, y), Vector2(box, box))
		var solved := SaveGame.is_solved(p["id"])
		if solved:
			_rounded(frame, paper.lerp(accent, 0.14), accent.lerp(paper, 0.35), 2, 1)
			_draw_art(p["art"], frame.grow(-box * 0.16), deep)
		else:
			# Empty slot: a dotted outline, nothing inside.
			_dotted_rect(frame, accent.lerp(paper, 0.6), maxf(1.0, card.size.y * 0.004))


func _dotted_rect(rect: Rect2, col: Color, width: float) -> void:
	var step := maxf(3.0, rect.size.x * 0.16)
	var x := rect.position.x
	while x < rect.position.x + rect.size.x:
		var seg := minf(step * 0.55, rect.position.x + rect.size.x - x)
		draw_line(Vector2(x, rect.position.y), Vector2(x + seg, rect.position.y), col, width)
		draw_line(Vector2(x, rect.position.y + rect.size.y),
				Vector2(x + seg, rect.position.y + rect.size.y), col, width)
		x += step
	var yy := rect.position.y
	while yy < rect.position.y + rect.size.y:
		var seg2 := minf(step * 0.55, rect.position.y + rect.size.y - yy)
		draw_line(Vector2(rect.position.x, yy), Vector2(rect.position.x, yy + seg2), col, width)
		draw_line(Vector2(rect.position.x + rect.size.x, yy),
				Vector2(rect.position.x + rect.size.x, yy + seg2), col, width)
		yy += step


# -- helpers ---------------------------------------------------------------

func _rounded(rect: Rect2, fill: Color, border: Color, radius: int,
		border_width: int = 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 8
	draw_style_box(sb, rect)


func _draw_art(art: Array, rect: Rect2, col: Color) -> void:
	if art.is_empty():
		return
	var h := art.size()
	var w := String(art[0]).length()
	var cell := floorf(minf(rect.size.x / w, rect.size.y / h))
	if cell < 1.0:
		return
	var origin := rect.position + ((rect.size - Vector2(w, h) * cell) * 0.5).floor()
	for r in h:
		var row: String = art[r]
		for c in w:
			if row[c] == "#":
				draw_rect(Rect2(origin + Vector2(c, r) * cell, Vector2(cell, cell)), col)


## Letter-spaced, centred title text — the postcard look.
func _draw_tracked(font: Font, text: String, centre: Vector2, fsize: int,
		col: Color, tracking: float, outline := Color(0, 0, 0, 0)) -> void:
	var total := 0.0
	var widths: Array = []
	for i in text.length():
		var ch := text[i]
		var w: float = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		widths.append(w)
		total += w + tracking
	total -= tracking
	var x := centre.x - total * 0.5
	for i in text.length():
		if outline.a > 0.0:
			draw_string_outline(font, Vector2(x, centre.y), text[i],
					HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 5, outline)
		draw_string(font, Vector2(x, centre.y), text[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
		x += widths[i] + tracking


## Wrap a multi-paragraph letter, keeping its blank lines.
func _wrap_paragraphs(font: Font, text: String, fsize: int, max_width: float) -> Array:
	var out: Array = []
	for para in text.split("\n"):
		if String(para).strip_edges() == "":
			out.append("")
			continue
		out.append_array(_wrap(font, para, fsize, max_width))
	return out


func _wrap(font: Font, text: String, fsize: int, max_width: float) -> Array:
	var out: Array = []
	if text.strip_edges() == "":
		return out
	var line := ""
	for word in text.split(" ", false):
		var trial := word if line == "" else line + " " + word
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > max_width and line != "":
			out.append(line)
			line = word
		else:
			line = trial
	if line != "":
		out.append(line)
	return out
