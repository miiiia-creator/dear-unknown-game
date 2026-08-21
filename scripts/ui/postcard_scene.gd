class_name PostcardScene
extends Control
## The city-completion payoff: the puzzle's pixel art standing as a crisp
## silhouette against a procedurally generated dusk sky.
##
## The art direction is deliberate. Trying to render pixel art *as* painted
## illustration lands in the uncanny middle; keeping the subject hard-edged
## against a soft, bloomed sky is a coherent look, and it costs nothing per
## destination because the sky is generated from the city palette.
##
## Layering note: a CanvasItem draws itself first and its children on top, so
## the sky and the subject are two sibling child layers in the right order
## rather than "_draw() plus a background node".

const SKY := preload("res://shaders/sky.gdshader")
const RESOLVE := preload("res://shaders/postcard_resolve.gdshader")

## Painted art, one PNG per city id. A destination with a file here resolves
## into it; one without falls back to the procedural sky, so the two can coexist
## while the set is being filled in.
const ART_DIR := "res://assets/postcards/"

## Sun position in UV space. Shared by the sky and the subject's rim light so
## the two agree about where the light is coming from.
const SUN := Vector2(0.67, 0.38)

var bloom := 0.0:
	set(value):
		bloom = value
		if _sky_mat:
			_sky_mat.set_shader_parameter("bloom", value)
		if _subject:
			_subject.bloom = value

var appear := 0.0:
	set(value):
		appear = value
		if _subject:
			_subject.appear = value

var rim := 0.0:
	set(value):
		rim = value
		if _subject:
			_subject.rim = value

## 0 -> 1 drives the mosaic refinement when the city has painted art.
var resolve := 0.0:
	set(value):
		resolve = value
		_update_resolve()

var city_id := ""
var has_art := false
## Mean luminance of the band the caption sits over, 0..1. Measured from the
## artwork rather than configured per city, because a Caravaggio and a Hopper
## need opposite type colours and nobody should have to remember which.
var caption_luma := 1.0
var _sky: ColorRect
var _sky_mat: ShaderMaterial
var _subject: SubjectLayer
var _painted: ColorRect
var _painted_mat: ShaderMaterial
var _drift: DriftLayer
var _video: VideoStreamPlayer
var _grid_blocks := 15.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func setup(id: String) -> void:
	city_id = id
	var city := GameData.city(id)
	if city.is_empty():
		return
	var palette := GameData.city_palette(id)
	var puzzles: Array = city.get("puzzles", [])

	if _sky == null:
		_sky = ColorRect.new()
		_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
		_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sky_mat = ShaderMaterial.new()
		_sky_mat.shader = SKY
		_sky.material = _sky_mat
		add_child(_sky)

		_subject = SubjectLayer.new()
		_subject.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_subject)          # after the sky, so it draws in front

		_drift = DriftLayer.new()
		_drift.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_drift)

	var accent: Color = palette[1]

	# Fixed cool-to-warm structure; the city only tints the warm half. Deriving
	# every band from one palette is what made the first pass monochrome.
	var warm := accent.lerp(Color(1.0, 0.76, 0.44), 0.55)
	warm.s = clampf(warm.s * 1.15, 0.0, 1.0)
	var cool := Color(0.07, 0.10, 0.26).lerp(accent.darkened(0.7), 0.35)
	var mid := cool.lerp(warm, 0.5)
	mid.s = clampf(mid.s * 1.2, 0.0, 1.0)

	_sky_mat.set_shader_parameter("warm", warm)
	_sky_mat.set_shader_parameter("mid", mid)
	_sky_mat.set_shader_parameter("cool", cool)
	_sky_mat.set_shader_parameter("sun", SUN)
	_sky_mat.set_shader_parameter("drift", float(city.get("order", 0)) * 7.3)
	_sky_mat.set_shader_parameter("bloom", bloom)

	_subject.art = puzzles[-1]["art"] if not puzzles.is_empty() else []
	# Near-black silhouette: the subject is backlit, so it should not carry the
	# city colour — the sky does that job.
	_subject.ink = cool.darkened(0.55)
	_subject.glow = warm.lightened(0.30)
	_subject.sun_uv = SUN
	_subject.seed_motes(int(abs(hash(id))) % 100000)
	_drift.kind = str(city.get("drift", "mote"))
	_drift.tint = palette[0].lightened(0.35)
	_drift.reseed(int(abs(hash(id + "drift"))) % 100000)

	_load_painted(id, puzzles)
	# After the artwork is known, not before: the sky is only a stand-in for a
	# city that has no painting, and left underneath one its sun shafts came
	# straight through and bleached the drawing white.
	_sky.visible = not has_art


## Look for painted art for this city and, if it exists, put the mosaic layer in
## front of the procedural sky.
func _load_painted(id: String, puzzles: Array) -> void:
	var tex: Texture2D = null
	for ext in [".png", ".jpg", ".jpeg", ".webp"]:
		var path: String = ART_DIR + id + str(ext)
		if ResourceLoader.exists(path):
			tex = load(path)
			if tex != null:
				break
	has_art = tex != null
	# The generated sky is what a city without a painting falls back to. With
	# one, it was still being drawn underneath — and its sun shafts came
	# straight through a soft ink drawing and bleached it white.
	if not has_art:
		if _painted:
			_painted.visible = false
		return

	if _painted == null:
		_painted = ColorRect.new()
		_painted.set_anchors_preset(Control.PRESET_FULL_RECT)
		_painted.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_painted_mat = ShaderMaterial.new()
		_painted_mat.shader = RESOLVE
		_painted.material = _painted_mat
		add_child(_painted)
	_painted.visible = true
	move_child(_painted, get_child_count() - 1)   # in front of sky and subject

	# Layer order with painted art: the coarse mosaic sits behind as the colour
	# field, the pixel pieces stand crisply on top of it. Starting from the
	# painting's own blurred colours means the dissolve never jumps hue.
	_sky.visible = false
	move_child(_painted, 0)
	move_child(_subject, get_child_count() - 1)
	move_child(_drift, get_child_count() - 1)   # petals in front of everything

	# Stand the pixel pieces where the painting puts the same subjects. The slots
	# are measured off each painting and live in the content data, because they
	# describe the artwork rather than the code.
	var by_id: Dictionary = {}
	for p in puzzles:
		by_id[p["id"]] = p
	_subject.visible = true
	_subject.pieces = []
	for slot in GameData.city(id).get("composition", []):
		var piece: Dictionary = by_id.get(slot["id"], {})
		if piece.is_empty():
			continue
		_subject.pieces.append({
			"art": piece["art"], "x": float(slot["x"]),
			"base": float(slot["base"]), "w": float(slot["w"]),
		})

	_painted_mat.set_shader_parameter("art", tex)
	caption_luma = _measure_caption_band(tex)
	_load_video(id)

	# Start the mosaic at the puzzle's own grid size, so the first colour frame
	# lands at exactly the resolution the player was just looking at.
	_grid_blocks = float(String(puzzles[-1]["art"][0]).length()) if not puzzles.is_empty() else 15.0
	_update_resolve()


## An optional looping film of the same painting, played once the still has
## resolved. Desktop only: Godot decodes Theora on the CPU, the files are an
## order of magnitude larger than the stills, and the web build is already
## heavy — so the browser keeps the procedural motion instead.
func _load_video(id: String) -> void:
	if _video:
		_video.stop()
		_video.stream = null
		_video.queue_free()
		_video = null
	if OS.has_feature("web"):
		return
	var path := ART_DIR + id + ".ogv"
	if not ResourceLoader.exists(path):
		return
	var stream: VideoStream = load(path)
	if stream == null:
		return
	_video = VideoStreamPlayer.new()
	_video.stream = stream
	_video.loop = true
	_video.expand = true
	_video.audio_track = -1
	_video.volume_db = -80.0
	_video.set_anchors_preset(Control.PRESET_FULL_RECT)
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video.modulate.a = 0.0
	add_child(_video)
	move_child(_video, 1)          # above the still, below the pixel pieces
	if is_inside_tree():
		_video.play()
	else:
		# Callers that build the scene before parenting it still get playback.
		_video.ready.connect(_video.play, CONNECT_ONE_SHOT)


## True when this city has film to play, so callers know which motion to use.
func has_video() -> bool:
	return _video != null


## Average brightness across the lower band of the artwork, where the title goes.
func _measure_caption_band(tex: Texture2D) -> float:
	var img := tex.get_image()
	if img == null:
		return 1.0
	var w := img.get_width()
	var h := img.get_height()
	if w == 0 or h == 0:
		return 1.0
	var total := 0.0
	var count := 0
	# A coarse sample is plenty; this decides one boolean.
	var step := maxi(1, w / 48)
	for y in range(int(h * 0.70), h, maxi(1, h / 24)):
		for x in range(0, w, step):
			total += img.get_pixel(x, y).get_luminance()
			count += 1
	return total / maxf(1.0, float(count))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_resolve()


func _update_resolve() -> void:
	if _painted_mat == null or not has_art:
		return
	# Exponential ramp: the early, chunky frames are the interesting ones, so
	# give them time and let the fine detail snap in at the end.
	_painted_mat.set_shader_parameter("grid", _grid_blocks)
	_painted_mat.set_shader_parameter("progress", clampf(resolve, 0.0, 1.0))
	_painted_mat.set_shader_parameter("warmth", 1.0 - clampf(resolve * 1.6, 0.0, 1.0))
	_painted_mat.set_shader_parameter("cover", _cover_scale())
	_painted_mat.set_shader_parameter("max_blocks", maxf(size.x, 64.0))
	# The wash arrives with the caption, not before it.
	_painted_mat.set_shader_parameter("caption_scrim",
			clampf((resolve - 0.55) / 0.35, 0.0, 1.0))
	_painted_mat.set_shader_parameter("scrim_dir", -1.0 if caption_luma < 0.45 else 1.0)
	# The camera move only starts once the picture has resolved — and only when
	# there is no film doing it for real.
	var settled := clampf((resolve - 0.80) / 0.20, 0.0, 1.0)
	_painted_mat.set_shader_parameter("breathe", 0.0 if _video else settled)
	if _video:
		# Cross from the resolved still into the film so the swap is invisible.
		_video.modulate.a = settled
	# The living light only starts once the picture has actually arrived.
	_painted_mat.set_shader_parameter("shimmer", clampf((resolve - 0.85) / 0.15, 0.0, 1.0))
	if _drift:
		_drift.alpha = clampf((resolve - 0.75) / 0.25, 0.0, 1.0)


## Width / height of the painted art, so the card can be shaped to match it.
## Painted postcards carry their own printed border, and cropping that off to
## force a 3:2 card looks like a mistake — better to shape the card to the art.
func art_aspect() -> float:
	if not has_art or _painted_mat == null:
		return 1.5
	var tex: Texture2D = _painted_mat.get_shader_parameter("art")
	if tex == null or tex.get_height() == 0:
		return 1.5
	return float(tex.get_width()) / float(tex.get_height())


## With the card shaped to the art this is 1:1; it stays as a guard for the
## moments before layout has settled.
func _cover_scale() -> Vector2:
	var tex: Texture2D = _painted_mat.get_shader_parameter("art")
	if tex == null or size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ONE
	var img_aspect := float(tex.get_width()) / float(tex.get_height())
	var box_aspect := size.x / size.y
	if absf(box_aspect - img_aspect) < 0.01:
		return Vector2.ONE
	if box_aspect > img_aspect:
		return Vector2(1.0, box_aspect / img_aspect)
	return Vector2(img_aspect / box_aspect, 1.0)


func play(host: Node) -> Tween:
	bloom = 0.0
	appear = 0.0
	rim = 0.0
	resolve = 0.0

	if not has_art:
		var tw := host.create_tween()
		tw.tween_property(self, "bloom", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(self, "appear", 1.0, 1.3) \
				.set_delay(0.35).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(self, "rim", 1.0, 0.9) \
				.set_delay(0.95).set_trans(Tween.TRANS_SINE)
		return tw

	# The pieces you solved stand on the painting's own blurred colours, hold
	# long enough to be recognised, then dissolve as the picture sharpens into
	# the same arrangement underneath them.
	_subject.modulate.a = 1.0
	var tw2 := host.create_tween()
	tw2.tween_property(self, "appear", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	tw2.parallel().tween_property(self, "rim", 1.0, 0.7).set_delay(0.35)
	tw2.parallel().tween_property(self, "resolve", 0.10, 0.8)
	tw2.tween_interval(0.4)
	tw2.tween_property(_subject, "modulate:a", 0.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw2.parallel().tween_property(self, "resolve", 0.34, 0.7)
	tw2.tween_property(self, "resolve", 1.0, 1.4) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return tw2


# --------------------------------------------------------------------------

## The silhouette and the drifting motes, drawn in front of the sky.
class SubjectLayer:
	extends Control

	var art: Array = []
	## Composition slots: {art, x, base, w} in fractions of the frame. Empty
	## falls back to the single centred `art` above.
	var pieces: Array = []
	var ink := Color.BLACK
	var glow := Color.WHITE
	var sun_uv := Vector2(0.7, 0.58)
	var bloom := 0.0:
		set(value):
			bloom = value
			queue_redraw()
	var appear := 0.0:
		set(value):
			appear = value
			queue_redraw()
	var rim := 0.0:
		set(value):
			rim = value
			queue_redraw()

	var _motes: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
		set_process(true)

	func seed_motes(seed_value: int) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		_motes.clear()
		for i in 26:
			_motes.append([
				Vector2(rng.randf(), rng.randf()),
				rng.randf_range(0.010, 0.035),
				rng.randf_range(1.0, 2.6),
			])

	func _process(_delta: float) -> void:
		if bloom > 0.0:
			queue_redraw()      # the sky and motes are both time-driven

	func _draw() -> void:
		_draw_motes()
		if not pieces.is_empty():
			for piece in pieces:
				_draw_piece(piece)
			return
		if art.is_empty():
			return
		var h := art.size()
		var w := String(art[0]).length()
		var cell := floorf(minf(size.x * 0.32 / w, size.y * 0.46 / h))
		if cell < 1.0:
			return
		var art_size := Vector2(w, h) * cell
		var origin := (Vector2(size.x * 0.40, size.y * 0.62)
				- Vector2(art_size.x * 0.5, art_size.y)).floor()
		_rim_and_body(origin, cell, art_size, art)

	## One slot of the composition, sized and seated on its own baseline.
	func _draw_piece(piece: Dictionary) -> void:
		var piece_art: Array = piece["art"]
		if piece_art.is_empty():
			return
		var h := piece_art.size()
		var w := String(piece_art[0]).length()
		var cell := floorf(size.x * float(piece["w"]) / float(w))
		if cell < 1.0:
			return
		var art_size := Vector2(w, h) * cell
		var origin := (Vector2(size.x * float(piece["x"]), size.y * float(piece["base"]))
				- Vector2(art_size.x * 0.5, art_size.y)).floor()
		_rim_and_body(origin, cell, art_size, piece_art)

	func _rim_and_body(origin: Vector2, cell: float, art_size: Vector2, which: Array) -> void:
		if rim > 0.0:
			var centre := origin + art_size * 0.5
			var towards := (sun_uv * size - centre).normalized()
			var spread := maxf(1.0, cell * 0.6)
			for i in 5:
				var spin := (float(i) - 2.0) * 0.42
				var halo := glow
				halo.a = 0.5 * rim * (1.0 - absf(spin) * 0.7)
				_stamp_art(which, origin + towards.rotated(spin) * spread, cell, halo)
		_stamp_art(which, origin, cell, ink)

	func _stamp_art(which: Array, origin: Vector2, cell: float, col: Color) -> void:
		var h := which.size()
		var w := String(which[0]).length()
		var total := float(w + h)
		for r in h:
			var row: String = which[r]
			for c in w:
				if row[c] != "#":
					continue
				var t := float(r + c) / total
				if t > appear:
					continue
				var cc := col
				cc.a *= clampf((appear - t) * 6.0, 0.0, 1.0)
				draw_rect(Rect2(origin + Vector2(c, r) * cell, Vector2(cell, cell)), cc)

	func _draw_motes() -> void:
		if bloom <= 0.0:
			return
		var t := float(Time.get_ticks_msec()) / 1000.0
		for m in _motes:
			var seed_pos: Vector2 = m[0]
			var speed: float = m[1]
			var radius: float = m[2]
			var y := fposmod(seed_pos.y - t * speed, 1.0)
			var x := fposmod(seed_pos.x + sin(t * 0.35 + seed_pos.y * 9.0) * 0.012, 1.0)
			var c := glow
			c.a = 0.5 * sin(PI * y) * bloom
			draw_circle(Vector2(x * size.x, y * size.y), radius, c)


## Petals drifting across a resolved postcard. A souvenir that keeps moving
## reads as a place you are still standing in; a frozen one reads as a
## screenshot of somewhere you already left.
class DriftLayer:
	extends Control

	var tint := Color.WHITE
	## petal | mote | dust | rain | none — what moves in this city's air.
	var kind := "mote"
	var alpha := 0.0:
		set(value):
			alpha = value
			visible = value > 0.001

	var _bits: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
		set_process(true)

	func reseed(seed_value: int) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		_bits.clear()
		if kind == "none":
			return
		# Each kind has its own weather: petals tumble, motes hang, dust barely
		# moves in a shaft of light, rain falls straight and fast.
		var counts := {"petal": 22, "mote": 26, "dust": 16, "rain": 46}
		var count: int = counts.get(kind, 22)
		for i in count:
			var fall := 0.030
			var sway := 1.0
			var size := 3.0
			match kind:
				"petal":
					fall = rng.randf_range(0.020, 0.055)
					sway = rng.randf_range(0.5, 1.6)
					size = rng.randf_range(2.2, 4.6)
				"mote":
					fall = rng.randf_range(-0.012, 0.012)
					sway = rng.randf_range(0.2, 0.7)
					size = rng.randf_range(1.4, 3.0)
				"dust":
					fall = rng.randf_range(-0.006, 0.008)
					sway = rng.randf_range(0.1, 0.4)
					size = rng.randf_range(1.0, 2.2)
				"rain":
					fall = rng.randf_range(0.55, 0.95)
					sway = rng.randf_range(0.0, 0.15)
					size = rng.randf_range(4.0, 9.0)
			_bits.append({
				"x": rng.randf(), "y": rng.randf(), "fall": fall, "sway": sway,
				"phase": rng.randf() * TAU, "size": size,
				"spin": rng.randf_range(-1.4, 1.4),
			})

	func _process(_delta: float) -> void:
		if alpha > 0.0:
			queue_redraw()

	func _draw() -> void:
		if alpha <= 0.0 or _bits.is_empty():
			return
		var t := float(Time.get_ticks_msec()) / 1000.0
		for b in _bits:
			var y: float = fposmod(float(b["y"]) + t * float(b["fall"]), 1.15) - 0.075
			var sway: float = sin(t * float(b["sway"]) + float(b["phase"])) * 0.035
			var pos := Vector2((float(b["x"]) + sway) * size.x, y * size.y)
			var fade: float = clampf(sin(PI * clampf(y, 0.0, 1.0)) * 1.6, 0.0, 1.0)
			var col := tint
			col.a = 0.75 * fade * alpha
			var r: float = float(b["size"])

			if kind == "rain":
				# A streak, not a speck, and dimmer — drizzle, not a downpour.
				col.a *= 0.5
				draw_line(pos, pos + Vector2(size.x * 0.004, r), col, 1.0, true)
			elif kind == "petal":
				var spin: float = t * float(b["spin"]) + float(b["phase"])
				draw_colored_polygon(PackedVector2Array([
					pos + Vector2(0, -r).rotated(spin),
					pos + Vector2(r * 0.75, 0).rotated(spin),
					pos + Vector2(0, r).rotated(spin),
					pos + Vector2(-r * 0.55, 0).rotated(spin),
				]), col)
			else:
				col.a *= 0.7 if kind == "dust" else 1.0
				draw_circle(pos, r, col)
