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
		var was := face
		face = value
		# The motion belongs to the picture. A card that is showing its back —
		# the completion screen builds one purely for the letter — has no use
		# for a second decode of the same film.
		if value != was:
			if value == "front":
				_load_motion(city_id)
			else:
				_stop_motion()
		queue_redraw()

## The city's painting, if it has one. A postcard front should be a picture;
## three pixel icons in a row were a stand-in for not having one.
const ART_DIR := "res://assets/postcards/"

## The same painting, moving. The still is frame zero of this video, so a card
## looks identical before the motion arrives — it just starts breathing once it
## has. Only the finishing-a-city screen used to animate; a postcard you go back
## to look at was a photograph of the thing you were given.
const MOTION_CACHE := "user://motion/"

var _city: Dictionary = {}
var _palette: Array = []
var _art: Texture2D
var _art_luma := 1.0
var _motion: VideoStreamPlayer
var _fetch: HTTPRequest


func setup(id: String, msg: String = "", sender: String = "", recipient: String = "") -> void:
	city_id = id
	message = msg
	from_name = sender
	to_name = recipient
	_city = GameData.city(id)
	_palette = GameData.city_palette(id)
	_load_art(id)
	if face == "front":
		_load_motion(id)
	else:
		_stop_motion()
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
	set_process(false)


## A video texture only changes between frames, so the card has to ask to be
## redrawn; nothing else on this Control does.
func _process(_delta: float) -> void:
	if _motion != null and _motion.is_playing():
		queue_redraw()


func _exit_tree() -> void:
	_stop_motion()


func _load_motion(id: String) -> void:
	_stop_motion()
	if id == "":
		return
	var packed := ART_DIR + id + ".ogv"
	if ResourceLoader.exists(packed):
		_start(load(packed))
		return
	# The web build leaves the videos out of the download — ten megabytes on top
	# of a load that already takes half a minute on a slow line. Fetch the one
	# the player actually opened, once, and keep it for next time.
	if OS.has_feature("web"):
		_fetch_motion(id)


func _start(stream: VideoStream) -> void:
	if stream == null:
		return
	_motion = VideoStreamPlayer.new()
	_motion.stream = stream
	_motion.loop = true
	_motion.audio_track = -1
	_motion.volume_db = -80.0
	# Never shown as a node: the card draws the frames itself, so the cover crop
	# and the lettering over it stay exactly as they are for the still.
	_motion.visible = false
	_motion.custom_minimum_size = Vector2.ONE
	add_child(_motion)
	# setup() is usually called while the card is still being assembled, before
	# it is in the tree — and a VideoStreamPlayer outside the tree refuses to
	# play. Wait for the frame it arrives, if it has not already.
	if _motion.is_inside_tree():
		_motion.play()
	else:
		_motion.tree_entered.connect(_motion.play, CONNECT_ONE_SHOT)
	set_process(true)


func _stop_motion() -> void:
	set_process(false)
	if _motion != null:
		# Drop the stream before the node: queue_free lands next frame, and at
		# shutdown there is no next frame, so the video would still be held when
		# the engine clears its resource cache.
		_motion.stop()
		_motion.stream = null
		_motion.queue_free()
		_motion = null
	if _fetch != null:
		_fetch.queue_free()
		_fetch = null


func _fetch_motion(id: String) -> void:
	var cached := MOTION_CACHE + id + ".ogv"
	if FileAccess.file_exists(cached):
		_start(_stream_at(cached))
		return
	var url := _motion_url(id)
	if url == "":
		return
	DirAccess.make_dir_recursive_absolute(MOTION_CACHE)
	_fetch = HTTPRequest.new()
	_fetch.download_file = cached
	add_child(_fetch)
	_fetch.request_completed.connect(_motion_arrived.bind(cached))
	if _fetch.request(url) != OK:
		_stop_motion()


func _motion_arrived(result: int, code: int, _headers: PackedStringArray,
		_body: PackedByteArray, cached: String) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 \
			and FileAccess.file_exists(cached):
		_start(_stream_at(cached))
		return
	# A failed request still writes whatever came back. An error page saved as
	# a video would be treated as a cache hit forever.
	if FileAccess.file_exists(cached):
		DirAccess.remove_absolute(cached)


func _stream_at(path: String) -> VideoStream:
	var stream := VideoStreamTheora.new()
	stream.file = path
	return stream


## Sibling of the page the game was served from, so it follows the build
## wherever it is hosted.
func _motion_url(id: String) -> String:
	var base: Variant = JavaScriptBridge.eval("location.href.split('#')[0].split('?')[0].replace(/[^/]*$/, '')", true)
	if typeof(base) != TYPE_STRING or String(base) == "":
		return ""
	return String(base) + "motion/" + id + ".ogv"


func flip() -> void:
	face = "back" if face == "front" else "front"


## Largest 3:2 rectangle that fits, centred.
## The card turns with the screen. A landscape card on a phone held upright
## fills a third of it, which is no way to show the thing the whole game is
## for; a portrait card on a monitor is the same mistake the other way round.
func portrait() -> bool:
	return size.y > size.x


func _card_rect() -> Rect2:
	# A card is whatever shape its picture is. Postcards are not all one size,
	# and forcing a tall ink drawing into a 3:2 frame crops away the sky, which
	# on that drawing is most of what there is to look at.
	var ratio := RATIO if not portrait() else 1.0 / RATIO
	if _art != null and _art.get_height() > 0:
		ratio = float(_art.get_width()) / float(_art.get_height())
	var w := size.x
	var h := w / ratio
	if h > size.y:
		h = size.y
		w = h * ratio
	return Rect2(((size - Vector2(w, h)) * 0.5).floor(), Vector2(w, h).floor())


func _draw() -> void:
	if _city.is_empty():
		return
	var card := _card_rect()

	# A sheet of paper, not a swatch of the city's colour. The back sits beside
	# a grey ink drawing; a pink card behind it read as a different object.
	var paper: Color = _palette[0].lerp(Color(0.96, 0.95, 0.93), 0.72)
	var accent: Color = _palette[1]
	var deep: Color = _palette[2]

	# Soft drop shadow, then the card.
	var shadow := Color(0, 0, 0, 0.12)
	_rounded(card.grow(0.0).abs(), shadow, Color(0, 0, 0, 0), 14)
	_rounded(card.grow(-2.0), paper, deep.lerp(paper, 0.6), 12, 2)

	if face == "front":
		_draw_front(card, accent, deep)
		# The picture is drawn right out to the paper's edge, so the card's own
		# rule goes back on top of it. A style box edge is antialiased where a
		# polygon's is not, and it is what keeps the two faces the same object.
		_rounded(card.grow(-2.0), Color(0, 0, 0, 0), deep.lerp(paper, 0.6), 12, 2)
	else:
		_draw_back(card, accent, deep, paper)


func _draw_front(card: Rect2, accent: Color, deep: Color) -> void:
	if _art != null:
		_draw_painted_front(card)
		return
	# A city whose painting is not drawn yet gets a sheet of its own colour
	# rather than a white rectangle. White reads as broken; tinted paper reads
	# as a card that has not been developed.
	_rounded(card.grow(-2.0), _palette[0], Color(0, 0, 0, 0), 12)
	_draw_placeholder_front(card, accent, deep)


## The painting, cropped to the card and captioned.
func _draw_painted_front(card: Rect2) -> void:
	# Upright, the painting is shown whole as a band across the top rather than
	# cropped to a tall box. These are wide views — a gate on the left, a city
	# on the right — and a portrait crop throws away the half that makes them
	# worth looking at. Under the band is paper, which is where the name goes,
	# and that is what a printed postcard looks like anyway.
	var inner := card.grow(-2.0)
	var tex: Texture2D = _art
	if _motion != null and _motion.is_playing():
		var frame := _motion.get_video_texture()
		if frame != null:
			tex = frame
	var tex_size := Vector2(tex.get_width(), tex.get_height())
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
	_rounded_texture(inner, 12.0, tex, src)

	var font: Font = Pal.ui_font
	# Plain black or plain white, whichever the picture underneath calls for.
	# Tinting the lettering with the city's colour put a warm rose over a grey
	# ink drawing, and the only thing on the card that was not part of the
	# drawing was the one thing shouting.
	var dark := _art_luma < 0.45
	var type_col := Color(0.97, 0.97, 0.96) if dark else Color(0.10, 0.10, 0.10)
	var halo := Color(0, 0, 0, 0.45) if dark else Color(1, 1, 1, 0.45)

	# The name sits over the picture, near its foot. Sized from the card's short
	# side rather than its height: a card is whatever shape its picture is now,
	# and a tall one was getting type as large as the drawing.
	var upright := false
	var short := minf(card.size.x, card.size.y)
	var name_size := int(short * 0.135)
	var sub_size := int(short * 0.052)
	var name_y := card.position.y + card.size.y - short * 0.30
	var sub_y := card.position.y + card.size.y - short * 0.16
	if upright:
		type_col = _palette[2]
		halo = Color(0, 0, 0, 0)
		name_size = int(card.size.x * 0.105)
		sub_size = int(card.size.x * 0.040)
		var band_bottom := inner.position.y + inner.size.y
		var rest := card.position.y + card.size.y - band_bottom
		name_y = band_bottom + rest * 0.46
		sub_y = band_bottom + rest * 0.72

	var city_name: String = String(GameData.text(_city["name"])).to_upper()
	_draw_tracked(font, city_name, Vector2(card.get_center().x, name_y),
			name_size, type_col, name_size * 0.22, halo)

	var sub := String(GameData.text(_city["country"])).to_upper()
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size).x
	if not upright:
		draw_string_outline(font, Vector2(card.get_center().x - sw * 0.5, sub_y), sub,
				HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, 4, halo)
	draw_string(font, Vector2(card.get_center().x - sw * 0.5, sub_y), sub,
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
	_draw_tracked(font, String(GameData.text(_city["name"])).to_upper(),
			Vector2(card.get_center().x, y + card.size.y * 0.20),
			int(card.size.y * 0.155), deep, card.size.y * 0.035)

	var sub := String(GameData.text(_city["country"])).to_upper()
	var sub_size := int(card.size.y * 0.058)
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size).x
	draw_string(font, Vector2(card.get_center().x - sw * 0.5, y + card.size.y * 0.29),
			sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, accent)


func _draw_back(card: Rect2, accent: Color, deep: Color, paper: Color) -> void:
	# The back is the letter, the postmark and the stamp, and nothing else. It
	# used to carry a row of the city's discoveries along the bottom, which took
	# a quarter of the card to repeat something the journal page already shows
	# and left the writing squeezed into what was left.
	# Inset by the short side. Taken from the height, a tall card lost a third
	# of its width to margins — which is what pushed the stamp into the middle
	# and cut the ends off every line of the letter.
	var short_side := minf(card.size.x, card.size.y)
	var inner := card.grow(-short_side * 0.09)
	var font: Font = Pal.ui_font

	# A stamp, top-right. It used to hold a shrunken copy of the landmark, which
	# repeated the picture on the front and read as a sticker; a plain perforated
	# rectangle with the country on it is what a stamp actually looks like.
	var s := short_side * 0.26
	var stamp := Rect2(Vector2(inner.position.x + inner.size.x - s * 0.88,
			inner.position.y), Vector2(s * 0.88, s))
	_draw_stamp(stamp, accent, deep, paper)

	# Postmark: two arcs and the day M posted it — not the day the player earned
	# it. That is what a cancellation mark actually records, and the dates are
	# not in the order the cards arrive. Kept faint on purpose: it should read
	# as ink on the paper, and only mean something to someone who goes back and
	# compares them.
	var pm := stamp.position + Vector2(-s * 0.80, s * 0.50)
	var mark := accent.lerp(paper, 0.42)
	draw_arc(pm, s * 0.42, 0, TAU, 40, mark, maxf(1.0, card.size.y * 0.005), true)
	draw_arc(pm, s * 0.50, 0, TAU, 40, mark, maxf(1.0, card.size.y * 0.004), true)
	var date := String(_city.get("sent", ""))
	if date != "":
		# One line, at the size the stamp sets its country in. It used to be
		# stacked — day and month over the year — at twice that size, which made
		# the postmark the loudest thing on a card whose point is the letter,
		# and put two type sizes on a face that only needs one.
		var ds := _stamp_type_size(stamp)
		var room := s * 0.72
		var tw := font.get_string_size(date, HORIZONTAL_ALIGNMENT_LEFT, -1, ds).x
		if tw > room:
			ds = maxi(6, int(float(ds) * room / tw))
			tw = font.get_string_size(date, HORIZONTAL_ALIGNMENT_LEFT, -1, ds).x
		draw_string(font, pm + Vector2(-tw * 0.5, float(ds) * 0.36), date,
				HORIZONTAL_ALIGNMENT_LEFT, -1, ds, mark)

	# Vertical divider between the message and the address — only when there is
	# an address side to divide off. M's letters are not addressed to anybody,
	# which is the premise of the game, and they run long enough to cross the
	# middle of the card; a rule down the centre just gets written over.
	var mid := inner.position.x + inner.size.x * 0.52
	var addressed := message.strip_edges() != ""
	if addressed:
		draw_line(Vector2(mid, inner.position.y + inner.size.y * 0.05),
				Vector2(mid, inner.position.y + inner.size.y * 0.95),
				accent.lerp(paper, 0.5), maxf(1.0, card.size.y * 0.004))

	# What is written on the card: the letter that arrived with it, or — when the
	# player is composing something to send — their own words instead.
	var text := message
	var handwritten := true
	if text.strip_edges() == "":
		text = GameData.text(_city.get("letter", {}).get("body", ""))
		handwritten = false

	# M's letters are written in lines, not paragraphs — each break is the
	# author's. Wrapping them to a column destroyed that: a sentence meant to
	# land on its own turned into two ragged lines, and with the measure
	# changing halfway down the card the right edge jumped about.
	#
	# So they are not wrapped at all. The type is sized to the two things that
	# actually constrain it — the number of lines and the longest line — and the
	# block is centred in what the stamp leaves. A message the player is writing
	# still wraps, because that one is prose and is short.
	var narrow_w := mid - inner.position.x - card.size.x * 0.04
	var lines: Array = []
	var msg_size := 0
	var top := 0.0

	if handwritten:
		msg_size = int(card.size.y * 0.062)
		var room := int(inner.size.y * 0.74 / (msg_size * 1.45))
		lines = _wrap_paragraphs(font, text, msg_size, narrow_w)
		while lines.size() > room and msg_size > int(card.size.y * 0.030):
			msg_size -= 1
			room = int(inner.size.y * 0.74 / (msg_size * 1.45))
			lines = _wrap_paragraphs(font, text, msg_size, narrow_w)
		top = inner.position.y + inner.size.y * 0.16
	else:
		for para in text.split("\n"):
			lines.append(String(para).strip_edges())
		var wide_w := inner.size.x - card.size.x * 0.02
		# Room to the left of the stamp. M writes short lines, so the block
		# usually clears it and can start at the top of the card. Only a letter
		# with a long line has to begin underneath.
		# Measured to the postmark, not the stamp: the cancellation circle sits
		# further left than the stamp does, and a line that cleared the stamp
		# was still running straight through it.
		# Room to the left of the postmark. On a tall card there is none worth
		# having, so the letter simply starts underneath.
		var beside_w := stamp.position.x - s * 1.30 - inner.position.x \
				- card.size.x * 0.02
		if card.size.y > card.size.x:
			beside_w = 0.0
		var high_top := inner.position.y + short_side * 0.03
		var low_top := stamp.position.y + stamp.size.y + short_side * 0.06
		var bottom := inner.position.y + inner.size.y
		var block_top := high_top
		msg_size = int(short_side * 0.075)
		while msg_size > int(short_side * 0.030):
			var widest := 0.0
			for line in lines:
				widest = maxf(widest, font.get_string_size(
						line, HORIZONTAL_ALIGNMENT_LEFT, -1, msg_size).x)
			block_top = high_top if widest <= beside_w else low_top
			var tall := lines.size() * msg_size * 1.45
			if widest <= wide_w and block_top + tall <= bottom:
				break
			msg_size -= 1
		var tall_final := lines.size() * msg_size * 1.45
		top = block_top + maxf(0.0, (bottom - block_top - tall_final) * 0.5)

	var ly := top
	for i in lines.size():
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
	for i in (3 if addressed else 0):
		draw_line(Vector2(ax, ay + i * msg_size * 1.5),
				Vector2(ax + aw, ay + i * msg_size * 1.5),
				accent.lerp(paper, 0.55), maxf(1.0, card.size.y * 0.004))



## Every discovery in the city as a small stamp along the foot of the card.
##
## A postcard picture is a view, not an inventory: only three or four things fit
## into a landscape, and food and souvenirs never belong in one. This row is
## where the rest of a destination gets its due, and it still works at twenty
## puzzles a city where cramming them into the painting would not.
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


## Perforated edge, an inner rule, and the country in very small caps.
func _draw_stamp(rect: Rect2, accent: Color, deep: Color, paper: Color) -> void:
	draw_rect(rect, paper.lerp(accent, 0.10))

	var teeth := accent.lerp(paper, 0.35)
	var step := rect.size.x / 7.0
	var r := step * 0.30
	var x := rect.position.x + step * 0.5
	while x < rect.position.x + rect.size.x:
		draw_circle(Vector2(x, rect.position.y), r, paper)
		draw_circle(Vector2(x, rect.position.y + rect.size.y), r, paper)
		x += step
	var y := rect.position.y + step * 0.5
	while y < rect.position.y + rect.size.y:
		draw_circle(Vector2(rect.position.x, y), r, paper)
		draw_circle(Vector2(rect.position.x + rect.size.x, y), r, paper)
		y += step

	var inset := rect.grow(-rect.size.x * 0.14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = teeth
	sb.set_border_width_all(1)
	draw_style_box(sb, inset)

	var font: Font = Pal.ui_font
	var fsize := _stamp_type_size(rect)
	var country: String = String(GameData.text(_city.get("country", ""))).to_upper()
	var w := font.get_string_size(country, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	draw_string(font, Vector2(rect.get_center().x - w * 0.5,
			rect.get_center().y + fsize * 0.4), country,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, deep.lerp(paper, 0.15))


# -- helpers ---------------------------------------------------------------

## The one small size the back is set in: the stamp's country, and the postmark
## that sits beside it.
func _stamp_type_size(rect: Rect2) -> int:
	return int(maxf(6.0, rect.size.x * 0.15))


## The painting has to stop where the paper does. `draw_texture_rect_region`
## draws a square, so on a rounded card the picture put its own corners back and
## the front read as a photograph laid over a postcard rather than as the
## postcard. A rounded polygon carrying the crop in its uvs is the same picture
## in the paper's own shape. (Polygon uvs are normalised in Godot 4, not pixels.)
func _rounded_texture(rect: Rect2, radius: float, tex: Texture2D, src: Rect2) -> void:
	var pts := _round_rect(rect, radius)
	var sheet := Vector2(maxf(1.0, float(tex.get_width())),
			maxf(1.0, float(tex.get_height())))
	var uvs := PackedVector2Array()
	for p in pts:
		var t := (p - rect.position) / rect.size
		uvs.append((src.position + src.size * t) / sheet)
	draw_colored_polygon(pts, Color.WHITE, uvs, tex)


## A rounded rectangle as a clockwise ring of points.
func _round_rect(rect: Rect2, radius: float) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var far := rect.position + rect.size
	var corners := [
		[Vector2(far.x - r, rect.position.y + r), -TAU * 0.25],
		[Vector2(far.x - r, far.y - r), 0.0],
		[Vector2(rect.position.x + r, far.y - r), TAU * 0.25],
		[Vector2(rect.position.x + r, rect.position.y + r), TAU * 0.5],
	]
	var pts := PackedVector2Array()
	const STEPS := 8
	for corner in corners:
		var centre: Vector2 = corner[0]
		var from: float = corner[1]
		for i in STEPS + 1:
			var a: float = from + TAU * 0.25 * float(i) / float(STEPS)
			pts.append(centre + Vector2(cos(a), sin(a)) * r)
	return pts


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
## Wrap `text` where the usable width changes partway down: narrow while the
## line is still beside the stamp, wide once it has cleared it.
func _flow(font: Font, text: String, fsize: int, top: float, stamp_bottom: float,
		narrow_w: float, wide_w: float) -> Array:
	var out: Array = []
	var line_h := fsize * 1.45
	for para in text.split("\n"):
		var body: String = String(para).strip_edges()
		if body == "":
			out.append("")
			continue
		var words := body.split(" ")
		var current := ""
		for word in words:
			var trial: String = word if current == "" else current + " " + word
			var width: float = narrow_w if (top + out.size() * line_h) < stamp_bottom else wide_w
			if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x <= width \
					or current == "":
				current = trial
			else:
				out.append(current)
				current = word
		if current != "":
			out.append(current)
	return out


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
