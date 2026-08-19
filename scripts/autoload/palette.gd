extends Node
## Colour + font system. Autoloaded as `Pal`.
##
## Two moods: "paper" (daytime travel journal) and "evening" (lamp-lit).
## Everything in the game asks Pal for colour so a single toggle re-skins the
## whole app.

signal theme_changed

const PAPER := {
	"bg": "#F0E7D8",
	"panel": "#FBF6EC",
	"panel_alt": "#E9DFCC",
	"ink": "#3A3128",
	"ink_soft": "#8B7A63",
	"ink_faint": "#B6A48A",
	"line": "#D9CAB2",
	"line_strong": "#A8957A",
	"accent": "#C25E4B",
	"accent_soft": "#EAC0B4",
	"gold": "#B98C3C",
	"good": "#4A7C6F",
	"cell": "#3A3128",
	"shadow": "#00000014",
}

const EVENING := {
	"bg": "#1C1917",
	"panel": "#272220",
	"panel_alt": "#332C28",
	"ink": "#EFE4D3",
	"ink_soft": "#A6937A",
	"ink_faint": "#6E6052",
	"line": "#3D352F",
	"line_strong": "#6A5C4E",
	"accent": "#E08A6E",
	"accent_soft": "#5C3C31",
	"gold": "#D9AF63",
	"good": "#79B39F",
	"cell": "#EFE4D3",
	"shadow": "#00000040",
}

var mood: String = "paper"

var ui_font: Font
var mono_font: Font


func _ready() -> void:
	_build_fonts()


func _build_fonts() -> void:
	# Bundling a licensed font is a shipping task; for the prototype we lean on
	# system faces and chain a colour-emoji fallback so flags and icons render.
	var emoji := SystemFont.new()
	emoji.font_names = PackedStringArray([
		"Apple Color Emoji", "Segoe UI Emoji", "Noto Color Emoji",
	])
	emoji.allow_system_fallback = true

	var body := SystemFont.new()
	body.font_names = PackedStringArray([
		"Avenir Next", "Optima", "Segoe UI", "Noto Sans", "DejaVu Sans",
	])
	body.allow_system_fallback = true
	body.fallbacks = [emoji]
	ui_font = body

	var mono := SystemFont.new()
	mono.font_names = PackedStringArray([
		"SF Mono", "Menlo", "Consolas", "DejaVu Sans Mono",
	])
	mono.allow_system_fallback = true
	mono.fallbacks = [emoji]
	mono_font = mono


func set_mood(value: String) -> void:
	if value == mood:
		return
	mood = value
	theme_changed.emit()


func toggle_mood() -> void:
	set_mood("evening" if mood == "paper" else "paper")


func c(key: String) -> Color:
	var table: Dictionary = PAPER if mood == "paper" else EVENING
	return Color(table.get(key, "#FF00FF"))


## Blend a colour towards the current background — handy for soft fills.
func fade(key: String, amount: float) -> Color:
	return c(key).lerp(c("bg"), amount)
