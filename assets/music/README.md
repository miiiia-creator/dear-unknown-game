# Music

Drop the source file here — `.mp3`, `.wav`, `.m4a`, `.ogg`, whatever you were
given. `tools/build_music.sh` converts it to the looping Ogg Vorbis the game
actually loads, and reports what it costs to download.

Sound effects are generated, not sourced; they live in `assets/sfx/` and come
from `tools/make_sfx.py`.

Two things worth knowing before picking a track:

* **Size is the whole question.** The web build is already about sixteen
  megabytes and takes half a minute on a slow line. Three minutes of stereo
  Vorbis at a sane bitrate is another three to four megabytes on top of that.
  If the track is long, the game fetches it in the background after the first
  screen is up rather than bundling it, the same way the postcard films are
  fetched — nobody waits on the music.
* **It has to loop.** A track that fades out and restarts is worse than no
  music at all in a game people leave running. If the file does not loop
  cleanly the build reports it, and the fix is usually to trim to a bar line
  rather than to cross-fade.
