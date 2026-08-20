class_name UI
extends RefCounted
## Small factory of consistently-styled controls, so screens stay short and
## every button in the game looks like it came from the same place.

const H1 := 40
const H2 := 26
const H3 := 19
const BODY := 16
const SMALL := 12

## Tracking for the small uppercase labels. At this size the letters need air or
## they read as a smudge rather than a mark.
const LABEL_TRACKING := 1.6


static func _apply_font(node: Control, size: int, color_key: String) -> void:
	node.add_theme_font_override("font", Pal.ui_font)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", Pal.c(color_key))


## Single-line label. Never wraps: inside an HBox an autowrapping label collapses
## to its longest word and shreds the row, so wrapping is opt-in via paragraph().
static func label(text: String, size: int = BODY, color_key: String = "ink",
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	_apply_font(l, size, color_key)
	return l


## A small tracked label — section headers, counts, captions. Uppercase and
## spaced so it reads as a mark beside the content rather than a sentence.
static func label_small(text: String, color_key: String = "ink_faint",
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := label(text.to_upper(), SMALL, color_key, align)
	l.add_theme_constant_override("line_spacing", 2)
	return l


## Wrapping text. Only use inside a container with a definite width.
static func paragraph(text: String, size: int = BODY, color_key: String = "ink",
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := label(text, size, color_key, align)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func title(text: String) -> Label:
	var l := label(text, H1, "ink")
	l.add_theme_constant_override("line_spacing", 2)
	return l


static func spacer(height: float = 12.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


static func grow() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func hrule() -> Control:
	var line := ColorRect.new()
	line.color = Pal.c("line")
	line.custom_minimum_size = Vector2(0, 1)
	return line


static func _flat(bg: Color, border: Color, radius: int = 10,
		border_width: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 11
	sb.content_margin_bottom = 11
	return sb


static func button(text: String, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	# Square corners and a hairline only where a button has to look pressable.
	var bg := Pal.c("accent") if primary else Pal.c("panel")
	var fg := Pal.c("panel") if primary else Pal.c("ink")
	var border := Color(0, 0, 0, 0) if primary else Pal.c("line")

	b.add_theme_stylebox_override("normal", _flat(bg, border, 3))
	b.add_theme_stylebox_override("hover",
			_flat(bg.lerp(Pal.c("accent"), 0.12), Pal.c("accent"), 3))
	b.add_theme_stylebox_override("pressed",
			_flat(bg.lerp(Pal.c("ink"), 0.12), Pal.c("accent"), 3))
	b.add_theme_stylebox_override("disabled",
			_flat(Pal.fade("panel", 0.55), Color(0, 0, 0, 0), 3))
	b.add_theme_font_override("font", Pal.ui_font)
	b.add_theme_font_size_override("font_size", BODY)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", Pal.c("accent") if not primary else fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", Pal.c("ink_faint"))
	return b


## Re-skin an existing button between primary and secondary, for segmented
## controls where the selection moves.
static func restyle_button(b: Button, primary: bool) -> void:
	var bg := Pal.c("accent") if primary else Pal.c("panel")
	var fg := Pal.c("panel") if primary else Pal.c("ink")
	var border := Color(0, 0, 0, 0) if primary else Pal.c("line")
	b.add_theme_stylebox_override("normal", _flat(bg, border, 3))
	b.add_theme_stylebox_override("hover",
			_flat(bg.lerp(Pal.c("accent"), 0.12), Pal.c("accent"), 3))
	b.add_theme_stylebox_override("pressed",
			_flat(bg.lerp(Pal.c("ink"), 0.12), Pal.c("accent"), 3))
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", Pal.c("accent") if not primary else fg)
	b.add_theme_color_override("font_pressed_color", fg)


## Text-only button for menus and back links.
static func quiet_button(text: String, size: int = BODY) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var blank := StyleBoxEmpty.new()
	blank.content_margin_left = 6
	blank.content_margin_right = 6
	blank.content_margin_top = 6
	blank.content_margin_bottom = 6
	for s in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(s, blank)
	b.add_theme_font_override("font", Pal.ui_font)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Pal.c("ink"))
	b.add_theme_color_override("font_hover_color", Pal.c("accent"))
	b.add_theme_color_override("font_pressed_color", Pal.c("accent"))
	b.add_theme_color_override("font_disabled_color", Pal.c("ink_faint"))
	return b


static func dropdown() -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.add_theme_stylebox_override("normal", _flat(Pal.c("bg"), Pal.c("line_strong"), 8))
	o.add_theme_stylebox_override("hover", _flat(Pal.c("bg"), Pal.c("accent"), 8))
	o.add_theme_stylebox_override("pressed", _flat(Pal.c("bg"), Pal.c("accent"), 8))
	o.add_theme_font_override("font", Pal.ui_font)
	o.add_theme_font_size_override("font_size", BODY)
	o.add_theme_color_override("font_color", Pal.c("ink"))
	o.add_theme_color_override("font_hover_color", Pal.c("ink"))
	o.add_theme_color_override("font_pressed_color", Pal.c("ink"))

	# The dropdown list is a PopupMenu with its own theme.
	var popup := o.get_popup()
	popup.add_theme_stylebox_override("panel", _flat(Pal.c("panel"), Pal.c("line_strong"), 8))
	popup.add_theme_font_override("font", Pal.ui_font)
	popup.add_theme_font_size_override("font_size", BODY)
	popup.add_theme_color_override("font_color", Pal.c("ink"))
	popup.add_theme_color_override("font_hover_color", Pal.c("accent"))
	return o


static func panel(radius: int = 6, alt: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _flat(Pal.c("panel_alt") if alt else Pal.c("panel"),
			Color(0, 0, 0, 0), radius, 0)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	p.add_theme_stylebox_override("panel", sb)
	return p


static func vbox(separation: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func hbox(separation: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


static func line_edit(placeholder: String, max_len: int = 0) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	if max_len > 0:
		e.max_length = max_len
	e.add_theme_font_override("font", Pal.ui_font)
	e.add_theme_font_size_override("font_size", BODY)
	e.add_theme_color_override("font_color", Pal.c("ink"))
	e.add_theme_color_override("font_placeholder_color", Pal.c("ink_faint"))
	e.add_theme_color_override("caret_color", Pal.c("accent"))
	var sb := _flat(Pal.c("bg"), Pal.c("line_strong"), 8)
	e.add_theme_stylebox_override("normal", sb)
	e.add_theme_stylebox_override("focus", _flat(Pal.c("bg"), Pal.c("accent"), 8))
	return e


## "3 / 8" style progress bar drawn as two rectangles. Both layers are anchored
## so the fill stays correct when a container stretches the bar.
static func progress_bar(value: float, width: float = 180.0,
		height: float = 6.0) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(width, height)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var track := ColorRect.new()
	track.color = Pal.c("line")
	track.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(track)

	var fill := ColorRect.new()
	fill.color = Pal.c("accent")
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.anchor_right = clampf(value, 0.0, 1.0)
	fill.anchor_bottom = 1.0
	fill.offset_right = 0.0
	fill.offset_bottom = 0.0
	holder.add_child(fill)
	return holder

## Lay buttons out in rows that fit, rather than one row that does not.
##
## A container is never narrower than its contents, so a row of six
## destinations on a phone does not overflow quietly — it stretches everything
## above it past the edge of the screen, and the page looks broken in ways that
## have nothing to do with the row. Three screens had that bug.
static func chip_rows(buttons: Array, per_row: int, gap: int = 6) -> Control:
	var rows := vbox(gap)
	var row: HBoxContainer = null
	for b in buttons:
		if row == null or row.get_child_count() >= per_row:
			row = hbox(gap)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			rows.add_child(row)
		row.add_child(b)
	return rows

