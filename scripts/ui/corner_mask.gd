class_name CornerMask
extends Control
## Rounds off a rectangular clip.
##
## `clip_contents` clips a control to its rect, not to the corners of the style
## box drawn behind it — so a full-bleed child inside a rounded panel puts the
## square corners straight back on. The postcard on the finishing screen is
## built from shader layers rather than a texture, so there is nothing to draw
## as a rounded polygon either.
##
## `clip_children` would do this properly and is not available: the project
## renders on gl_compatibility, which has no support for it. So the corners are
## painted out in the colour of the page behind them instead. That only works
## where the page behind is flat, which on this screen it is.

var radius := 10.0:
	set(value):
		radius = value
		queue_redraw()

var colour := Color(0, 0, 0, 0):
	set(value):
		colour = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var r := minf(radius, minf(size.x, size.y) * 0.5)
	if r <= 0.0 or colour.a <= 0.0:
		return
	const STEPS := 8
	# Each corner is the sliver between the square angle and the arc: the point
	# itself, then the quarter turn that cuts it off.
	for i in 4:
		var centre := Vector2(r if i == 0 or i == 3 else size.x - r,
				r if i < 2 else size.y - r)
		var point := Vector2(0.0 if i == 0 or i == 3 else size.x,
				0.0 if i < 2 else size.y)
		var from := TAU * 0.5 + TAU * 0.25 * float(i)
		var pts := PackedVector2Array([point])
		for step in STEPS + 1:
			var a: float = from + TAU * 0.25 * float(step) / float(STEPS)
			pts.append(centre + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, colour)
