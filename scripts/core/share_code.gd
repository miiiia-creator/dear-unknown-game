class_name ShareCode
extends RefCounted
## Encodes a postcard into a link a friend can open in any browser.
##
## The whole postcard lives in the URL fragment: no server, no account, no
## database. web/postcard.html already contains the artwork for every puzzle,
## so the payload only needs ids plus the note.
##
## Fragment payloads are never sent to the host in an HTTP request, so the
## message stays between the two people who have the link.

## Point this at wherever web/postcard.html gets hosted (GitHub Pages, itch.io,
## Netlify — any static host will do).
const BASE_URL := "https://miiiia-creator.github.io/dear-unknown/postcard.html"


static func encode(payload: Dictionary) -> String:
	var json := JSON.stringify(payload)
	var b64 := Marshalls.utf8_to_base64(json)
	# base64url so the code survives being pasted into chat apps and URLs.
	return b64.replace("+", "-").replace("/", "_").replace("=", "")


## Returns {} for anything that is not a postcard. A friend pasting the wrong
## thing is expected, so this stays quiet instead of logging engine errors.
static func decode(code: String) -> Dictionary:
	var trimmed := code.strip_edges()
	# Accept a whole URL as well as a bare code.
	var hash_at := trimmed.rfind("#")
	if hash_at >= 0:
		trimmed = trimmed.substr(hash_at + 1)
	if trimmed.is_empty():
		return {}

	var b64 := trimmed.replace("-", "+").replace("_", "/")
	for i in b64.length():
		var ch := b64[i]
		var ok := (ch >= "A" and ch <= "Z") or (ch >= "a" and ch <= "z") \
				or (ch >= "0" and ch <= "9") or ch == "+" or ch == "/" or ch == "="
		if not ok:
			return {}
	while b64.length() % 4 != 0:
		b64 += "="

	var text := Marshalls.base64_to_utf8(b64)
	if text.is_empty():
		return {}
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed if parsed.has("c") and parsed.has("p") else {}


## v: format, c: city, p: puzzle to unlock it, m: message, f: from, t: to
static func build(city_id: String, puzzle_id: String, message: String,
		from_name: String, to_name: String) -> String:
	return encode({
		"v": 1,
		"c": city_id,
		"p": puzzle_id,
		"m": message.strip_edges(),
		"f": from_name.strip_edges(),
		"t": to_name.strip_edges(),
	})


static func url_for(code: String) -> String:
	return BASE_URL + "#" + code
