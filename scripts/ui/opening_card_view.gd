class_name OpeningCardView
extends Control
## The card that arrives before the game does.
##
## Front: a dot for every destination in the game, placed on a world map, and nothing
## else — no coastlines, no names. It should read as coordinates rather than as
## a map, because at this point the player has no reason to recognise any of
## them. Back: the note that explains why five went out.
##
## Same paper and same proportion as every other postcard in the game — it has
## to belong in the pile. What marks it out is that it is empty: no painting on
## the front, no city on the back. The first card is the one nobody had a
## picture for yet.

const RATIO := 1.5

var face := "front":
	set(value):
		face = value
		queue_redraw()

## 0 -> 1 reveals the dots one at a time.
var dots := 0.0:
	set(value):
		dots = value
		queue_redraw()

## 0 -> 1 fades the note in.
var note := 0.0:
	set(value):
		note = value
		queue_redraw()

## Declared above `season_id`, whose setter fills it: a member initialiser
## further down the file would blank it again.
var _body := ""

## Which season's opening card this is. Empty means the current one.
##
## The note used to be read once, in `_ready()`, from `current_season()` — and
## the pile sets this afterwards. So the moment the player moved past Season One
## the current season was one with no opening card, and Season One's card came
## up blank: dots on the front and nothing on the back.
var season_id := "":
	set(value):
		season_id = value
		_read_note()

var _points: Array = []          ## Vector2 in card-space fractions


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	# Nobody said which season, so it is the one being played — the prologue,
	# which shows the card before there is a pile to put it in.
	if season_id == "":
		season_id = str(GameData.current_season().get("id", ""))
	# A dot per destination, where it sits on a world map, squeezed into the
	# card's middle band so it stays a card. Every destination in the game, not just this season's. The card is M
	# saying "I sent one to every place I thought you might be" — the dots are
	# the whole itinerary, and a player who comes back to it after a season or
	# two should find that more of them now have names.
	for city in GameData.cities:
		var m: Array = city.get("map", [0.5, 0.5])
		_points.append(Vector2(
			0.12 + float(m[0]) * 0.76,
			0.30 + float(m[1]) * 0.90))


func _read_note() -> void:
	_body = GameData.text(GameData.opening_of(season_id).get("body", ""))
	queue_redraw()


func _card_rect() -> Rect2:
	var w := size.x
	var h := w / RATIO
	if h > size.y:
		h = size.y
		w = h * RATIO
	return Rect2(((size - Vector2(w, h)) * 0.5).floor(), Vector2(w, h).floor())


func _draw() -> void:
	var card := _card_rect()
	var ground := Pal.c("panel")
	var line := Pal.c("line")
	var mark := Pal.c("ink")

	# The faintest lift off the page, the way a card sitting on a desk has an
	# edge without having a frame.
	var shadow := Pal.c("shadow")
	draw_rect(Rect2(card.position + Vector2(0, 2), card.size), shadow)

	var sb := StyleBoxFlat.new()
	sb.bg_color = ground
	sb.border_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(0)
	sb.set_corner_radius_all(3)
	sb.corner_detail = 4
	draw_style_box(sb, card)

	if face == "front":
		_draw_front(card, line, mark)
	else:
		_draw_note(card, mark, line)


func _draw_front(card: Rect2, line: Color, mark: Color) -> void:
	# Corner ticks instead of a frame: registration marks, not decoration.
	var t := card.size.y * 0.05
	var edge := line
	var corners: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0),
			Vector2(0, 1), Vector2(1, 1)]
	for corner in corners:
		var p := card.position + card.size * corner
		var sx := 1.0 if corner.x == 0.0 else -1.0
		var sy := 1.0 if corner.y == 0.0 else -1.0
		var inset := Vector2(card.size.y * 0.06 * sx, card.size.y * 0.06 * sy)
		draw_line(p + inset, p + inset + Vector2(t * sx, 0), edge, 1.0)
		draw_line(p + inset, p + inset + Vector2(0, t * sy), edge, 1.0)

	var total := float(_points.size())
	for i in _points.size():
		# One at a time, in the order the journey will take them.
		var t_i := float(i) / total
		if dots < t_i:
			continue
		var a := clampf((dots - t_i) * total * 1.4, 0.0, 1.0)
		var pt: Vector2 = _points[i]
		var p := card.position + Vector2(pt.x * card.size.x, pt.y * card.size.y)
		var r := card.size.y * 0.011

		# A ring settling onto a point: the mark a pin leaves, not a bullet.
		var ring := Pal.c("accent")
		ring.a = 0.35 * a * (1.0 - clampf((dots - t_i) * 2.2, 0.0, 1.0))
		draw_arc(p, r * (1.0 + 5.0 * (1.0 - a)), 0, TAU, 24, ring, 1.0, true)
		var dot := mark
		dot.a = a
		draw_circle(p, r, dot)


func _draw_note(card: Rect2, ink: Color, line: Color) -> void:
	if note <= 0.0:
		return
	# The note is written, not printed — the same hand as the letters.
	var font: Font = Pal.letter_font
	var inner := card.grow(-card.size.y * 0.12)
	var fsize := int(card.size.y * 0.068)

	var fade := line
	fade.a = clampf(note * 2.0, 0.0, 1.0)

	# The furniture of a postcard back: a divider, and an empty stamp box where
	# a stamp would go if anyone had known where to send this.
	var mid := inner.position.x + inner.size.x * 0.58
	draw_line(Vector2(mid, inner.position.y + inner.size.y * 0.06),
			Vector2(mid, inner.position.y + inner.size.y * 0.94), fade, 1.0)

	var s := card.size.y * 0.22
	var box := Rect2(Vector2(inner.position.x + inner.size.x - s * 0.86,
			inner.position.y), Vector2(s * 0.86, s))
	_dashed_rect(box, fade)

	for i in 3:
		var y_line := inner.position.y + inner.size.y * (0.62 + i * 0.12)
		draw_line(Vector2(mid + card.size.x * 0.05, y_line),
				Vector2(inner.position.x + inner.size.x, y_line), fade, 1.0)

	# Shrink until the note fits the card rather than running off its edge: the
	# card is sized to the screen, and a phone gives it far less room.
	var text_w := inner.size.x * 0.52
	var room := inner.size.y * 0.92
	# In twos: every size tried is a whole glyph atlas rasterised and kept.
	var lines := _lay_out(font, fsize, text_w)
	while (lines.size() * fsize * 1.5) > room and fsize > 7:
		fsize -= 2
		lines = _lay_out(font, fsize, text_w)

	var y := inner.position.y + fsize * 1.4
	for i in lines.size():
		var text: String = lines[i]
		if text == "":
			y += fsize * 0.75
			continue
		# Each line arrives just after the one above it.
		var t_i := float(i) / maxf(1.0, float(lines.size()))
		var a := clampf((note - t_i * 0.55) * 3.0, 0.0, 1.0)
		var col := ink
		col.a = a
		# The signature sits apart and dimmer, the way a hand tails off.
		if text.begins_with("—"):
			col = line.lerp(ink, 0.7)
			col.a = a
		draw_string(font, Vector2(inner.position.x, y), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
		y += fsize * 1.5


func _wrap(font: Font, text: String, fsize: int, max_width: float) -> Array:
	var out: Array = []
	var current := ""
	for word in text.split(" ", false):
		var trial: String = str(word) if current == "" else current + " " + str(word)
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > max_width \
				and current != "":
			out.append(current)
			current = str(word)
		else:
			current = trial
	if current != "":
		out.append(current)
	return out


## Wrap the note at a given size, keeping its blank lines.
func _lay_out(font: Font, fsize: int, width: float) -> Array:
	var out: Array = []
	for para in _body.split("\n"):
		if String(para).strip_edges() == "":
			out.append("")
			continue
		out.append_array(_wrap(font, para, fsize, width))
	return out


## An empty stamp box, drawn the way a perforated edge looks.
func _dashed_rect(rect: Rect2, col: Color) -> void:
	var step := maxf(3.0, rect.size.x * 0.11)
	var x := rect.position.x
	while x < rect.position.x + rect.size.x:
		var seg := minf(step * 0.5, rect.position.x + rect.size.x - x)
		draw_line(Vector2(x, rect.position.y), Vector2(x + seg, rect.position.y), col, 1.0)
		draw_line(Vector2(x, rect.position.y + rect.size.y),
				Vector2(x + seg, rect.position.y + rect.size.y), col, 1.0)
		x += step
	var y := rect.position.y
	while y < rect.position.y + rect.size.y:
		var seg2 := minf(step * 0.5, rect.position.y + rect.size.y - y)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x, y + seg2), col, 1.0)
		draw_line(Vector2(rect.position.x + rect.size.x, y),
				Vector2(rect.position.x + rect.size.x, y + seg2), col, 1.0)
		y += step
