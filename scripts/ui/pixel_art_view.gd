class_name PixelArtView
extends Control
## Draws a discovery's pixel art at whatever size it is given. Used by the
## reveal moment, the journal grid and the postcards.

var art: Array = []
var ink: Color = Color.BLACK
var locked := false          ## draw as a silhouette of unknown squares
## 0..1 sweep used by the reveal animation; cells appear top-left to bottom-right.
var appear := 1.0:
	set(value):
		appear = value
		queue_redraw()


func setup(art_rows: Array, color: Color, is_locked: bool = false) -> void:
	art = art_rows
	ink = color
	locked = is_locked
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if art.is_empty():
		return
	var h := art.size()
	var w := String(art[0]).length()
	var cell := floorf(minf(size.x / w, size.y / h))
	if cell < 1.0:
		return
	var origin := ((size - Vector2(w, h) * cell) * 0.5).floor()

	if locked:
		var dim := ink
		dim.a = 0.14
		draw_rect(Rect2(origin, Vector2(w, h) * cell), dim)
		return

	var total := float(w + h)
	for r in h:
		var row: String = art[r]
		for c in w:
			if row[c] != "#":
				continue
			# Diagonal wipe: cells nearer the top-left land first.
			var t := float(r + c) / total
			if t > appear:
				continue
			var a := clampf((appear - t) * 8.0, 0.0, 1.0)
			var col := ink
			col.a *= a
			draw_rect(Rect2(origin + Vector2(c, r) * cell, Vector2(cell, cell)), col)
