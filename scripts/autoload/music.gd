extends Node
## The one piece of music, looping under everything. Autoloaded as `Music`.
##
## It is not part of the download. A megabyte and a half on top of a load that
## already takes half a minute on a slow line buys nothing in the first ten
## seconds of play, so the track is fetched once the game is on screen and
## fades in whenever it arrives — the same arrangement the postcard films use.
##
## The file it plays is built by tools/build_music.py, which folds the end of
## the source recording back over its beginning. A track that fades out and
## restarts is worse than silence in a game people leave open.

const PACKED := "res://assets/music/theme.ogg"
const CACHE := "user://theme.ogg"
const FADE := 4.0            ## seconds to come up from nothing
const LEVEL_DB := -13.0      ## under everything, never in front of it

var _player: AudioStreamPlayer
var _fetch: HTTPRequest
## Browsers keep audio silent until the page has been touched, and starting a
## stream into that silence just loses the opening. Wait for the first input.
##
## Waiting for *one* input is not enough, which is what left a phone with sound
## effects and no music. A browser resumes its audio clock as a result of the
## gesture, not during it, so the first touch is the one moment a stream is most
## likely to be started into a context that is still asleep — and the old code
## stopped listening right there and never tried again. Effects survived it
## because they are played on later taps, by which time the clock is running.
## So: keep asking until the player says it is actually playing.
var _touched := false
var _since := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.volume_db = -60.0
	add_child(_player)
	_obtain.call_deferred()


## An autoload is torn down after the engine has begun clearing its resource
## cache, so a stream the player still holds at that point is reported as
## leaked — a decoded Ogg is a chain of four objects, and all four survive.
## Let go of it at the last moment anybody can still ask us to.
func release() -> void:
	if _player != null:
		_player.stop()
		_player.stream = null


func _exit_tree() -> void:
	release()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		release()


func enabled() -> bool:
	return bool(SaveGame.setting("music", true))


func set_enabled(on: bool) -> void:
	SaveGame.set_setting("music", on)
	if on:
		_start()
	else:
		_player.stop()


func _input(_event: InputEvent) -> void:
	_touched = true
	_start()


## Nothing to do until there is a stream and somebody has touched the page; from
## then on, one attempt a second until it takes.
func _process(delta: float) -> void:
	if not _touched or _player.stream == null or _player.playing or not enabled():
		return
	_since += delta
	if _since < 1.0:
		return
	_since = 0.0
	_start()


func _obtain() -> void:
	if ResourceLoader.exists(PACKED):
		_player.stream = load(PACKED)
		_ready_to_play()
		return
	if not OS.has_feature("web"):
		return
	if FileAccess.file_exists(CACHE):
		_adopt(CACHE)
		return
	var url := _url()
	if url == "":
		return
	_fetch = HTTPRequest.new()
	add_child(_fetch)
	_fetch.request_completed.connect(_arrived)
	if _fetch.request(url) != OK:
		_fetch.queue_free()
		_fetch = null


func _arrived(result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	_adopt_bytes(body)
	# Keep it for next time, but only once it has been proved playable: an error
	# page saved under this name would be treated as the track forever.
	if _player.stream != null:
		var f := FileAccess.open(CACHE, FileAccess.WRITE)
		if f != null:
			f.store_buffer(body)
			f.close()


## From the bytes that just arrived rather than from the file they were written
## to. The web build keeps `user://` in a browser database, which is one more
## thing between the track and the speaker for no gain — the response is already
## in memory. The file is still written, so the next visit skips the download.
func _adopt_bytes(body: PackedByteArray) -> void:
	if body.is_empty():
		return
	var stream := AudioStreamOggVorbis.load_from_buffer(body)
	if stream == null:
		return
	stream.loop = true
	_player.stream = stream
	_ready_to_play()


func _adopt(path: String) -> void:
	var stream := AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		return
	stream.loop = true
	_player.stream = stream
	_ready_to_play()


func _ready_to_play() -> void:
	if _player.stream is AudioStreamOggVorbis:
		(_player.stream as AudioStreamOggVorbis).loop = true
	if _touched:
		_start()


func _start() -> void:
	if _player.stream == null or not enabled() or not _touched:
		return
	if not _player.playing:
		_player.volume_db = -60.0
		_player.play()
	var tw := create_tween()
	tw.tween_property(_player, "volume_db", LEVEL_DB, FADE)


## Sibling of the page the game was served from, so it follows the build.
func _url() -> String:
	var base: Variant = JavaScriptBridge.eval(
			"location.href.split('#')[0].split('?')[0].replace(/[^/]*$/, '')", true)
	if typeof(base) != TYPE_STRING or String(base) == "":
		return ""
	return String(base) + "audio/theme.ogg"
