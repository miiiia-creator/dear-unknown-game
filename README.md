# Dear, Unknown

**Season One: The Last Ones**

**Chinese title: 致陌生人**

A cozy nonogram travel game. Solve a puzzle, reveal a piece of a city, fill a
passport, and mail a postcard to a friend that they have to solve open.

- **Engine:** Godot 4.4+ (built on 4.3, verified on 4.7.1; GDScript, `gl_compatibility`)
- **Targets:** Steam (Windows / macOS / Linux) and iOS from the same project
- **Sharing:** one static HTML file, no server, no accounts

The name is the salutation on a postcard to someone you have not met. It works
both ways round: the player mails one to a friend, and the game mails one to the
player. Nothing in the title says "puzzle", so the genre words have to live in
the store description and tags — see Shipping.

Not wired up yet: the game has no localisation system, so the Chinese title is
recorded here rather than in the UI. Adding it means a Godot translation CSV and
`tr()` around the handful of user-facing strings.

---

## Running it

Install Godot 4.3 or newer, then:

```bash
godot --path . 
```

Or open `project.godot` in the Godot editor and press Play.

### Tests

```bash
godot --headless --path . --script tests/run_tests.gd
```

Covers clue generation, undo/reset/hint, completion rules, and share-code
encoding. Exits non-zero on failure, so it drops straight into CI.

### Screenshot tour

```bash
godot --path . -- --tour
```

Walks every screen and writes PNGs to `user://shots/`
(`~/Library/Application Support/Godot/app_userdata/Dear, Unknown/shots` on
macOS). It walks the desktop layout, then resizes to 430x932 and re-shoots the
key screens as `phone_*.png`. **It wipes the save file first.**

---

## Content pipeline

Eight puzzles per city, forty in all. Pixel art lives in
`tools/build_content.py`:

```python
P("tokyo_torii", "Torii Gate", "⛩", "Architecture", """
##########
##########
..#....#..
...
""")
```

Discoveries carry no prose. The writing is five letters, one per city,
unlocked with that city's postcard — forty one-liners were forty unconnected
jokes, five letters can be one arc. They live in `LETTERS` alongside each
city's theme and its postcard couplet.

Run the builder to validate and publish:

```bash
python3 tools/build_content.py
```

It does three things:

1. **Validates** every grid with a line-logic solver. A puzzle is only accepted
   if it has exactly one solution *and* that solution is reachable without
   guessing. This is the property that makes a nonogram feel fair, and it is
   easy to break by accident — sparse or symmetric art usually fails.
2. Writes `data/cities.json`, which the game loads at runtime.
3. Inlines the same data into `web/postcard.html` from
   `web/postcard.template.html`, so the share page stays a single self-contained
   file.

If a puzzle fails, nothing is written and the failure is printed:

```
FAIL tokyo/tokyo_sushi   NOT line-solvable: 92 cells need guessing
```

`tools/try_art.py` is a scratchpad for testing candidate art quickly without
touching the real content.

### Adding a destination

1. Add a `P(...)` list and a city entry in `tools/build_content.py`
   (`lonlat(lon, lat)` places the map pin).
2. Run the builder until every puzzle passes.
3. Nothing else — city unlock order, the map, the journal, the passport and the
   postcard all read from the data.

---

## The postcard share

Complete a destination → **Send to a friend** → write a note, pick which puzzle
locks it, copy the link.

The link looks like:

```
https://your-host/postcard.html#eyJjIjoibG9uZG9uIiwiZiI6Ik1pYSIs...
```

Everything — city, puzzle, message, both names — is base64url JSON in the URL
**fragment**. Fragments are never sent to the server in an HTTP request, so the
message stays between the two people who have the link, and hosting costs
nothing.

To turn it on:

1. Put `web/postcard.html` on any static host (GitHub Pages, itch.io, Netlify
   drop, an S3 bucket).
2. Set `BASE_URL` in [`scripts/core/share_code.gd`](scripts/core/share_code.gd)
   to that address.

The page is self-contained: it carries the art for every puzzle, plays the
nonogram with mouse or touch, and flips the postcard open on solve. It works in
dark mode and on a phone.

---

## Layout

```
project.godot            autoloads, window, input map
data/cities.json         generated — do not hand-edit
scripts/
  autoload/
    palette.gd           Pal — colours (paper / evening moods) and fonts
    game_data.gd         GameData — content lookups and unlock rules
    save_game.gd         SaveGame — user:// JSON save, achievements
  core/
    nonogram.gd          pure puzzle logic: clues, undo, hints, completion
    share_code.gd        postcard link encode / decode
  ui/
    board_view.gd        the grid — one custom-drawn Control
    pixel_art_view.gd    a discovery, with the reveal wipe
    postcard_view.gd     procedural postcard, front and back
    stamp_view.gd        procedural passport stamp
    world_map_view.gd    dot-grid world map with pins
    ui.gd               styled control factory
  screens/               one file per screen, built in code
  main.gd                router, toasts, theme changes
  tools/screen_tour.gd   dev screenshot walk
tests/run_tests.gd       headless unit tests
tools/build_content.py   content authoring + validation + web build
web/                     the shareable postcard page
```

Navigation is a fixed top bar plus a declared hierarchy (`PARENT` in
`main.gd`), not a visit history. A history stack looked right at first and was
wrong: drilling city -> puzzle -> back to city left the solved puzzle on the
stack, so Back bounced between the two and never reached the map.

Screens are built in GDScript rather than `.tscn` files. For a UI this small it
keeps every screen readable in one file and makes the palette swap trivial —
changing mood just rebuilds the current screen.

---

## Shipping

### Steam

1. Export a desktop build from Godot as usual.
2. Add [GodotSteam](https://godotsteam.com) for achievements. The
   achievement ids in `SaveGame.ACHIEVEMENTS` already match what you would
   register in the Steamworks partner site; `SaveGame.unlock()` is the single
   place to add the `Steam.setAchievement()` call.
3. Steam Cloud can sync `user://around_the_world.save` without format changes.

### iOS / portrait

The UI reflows rather than scaling. `window/stretch/mode` is **disabled** so the
viewport reports real available space, and every screen picks its layout from
`column_width()` — nav bar collapses to icons, grids drop columns, the share
form stacks, and the puzzle toolbar splits into two thumb-sized rows. Legibility
on dense screens comes from `content_scale_factor`, set in `main.gd`.

Preview portrait on the desktop with the tour: it resizes to 430x932 partway
through and shoots `phone_*.png`.

Untested on real hardware: the mobile branch of `_apply_content_scale()` uses
`DisplayServer.screen_get_scale()`, which needs a device to confirm. Also verify
that the **Fill / Mark** buttons read clearly to a first-time player, since
touch has no right-click.

---

## Postcard motion

Each city's postcard is a painted still that the reveal resolves into, and then
keeps moving. Two ways, chosen automatically:

- **Desktop** plays `assets/postcards/<city>.ogv` if it exists — a looping film
  of the same painting. Godot only decodes Ogg Theora, so source video has to be
  transcoded, and it must actually loop: generated "looping" clips usually drift
  from start to end, and the fix is a ping-pong (forward then reversed), which
  is seamless by construction.
- **Web** skips video entirely — the export filter drops `*.ogv`, because Theora
  files dwarf the stills and the browser build already ships a 38 MB engine.
  Instead a shader breathes the still in and out, and per-city particles drift
  across it: petals in Tokyo, drizzle in London, dust in a light shaft in Rome,
  nothing at all in New York, where the stillness is the point.

The caption colour is measured, not configured: the game samples the lower band
of the artwork and switches to light lettering over a dark painting. Rome is a
Caravaggio and Hopper's New York is not, and nobody should have to remember
which.

---

## Not built yet

Deliberately out of scope for the prototype, in rough priority order:

- **Sound and music.** The single biggest gap for a cozy game.
- **Four postcards still to paint.** Tokyo has art; Paris, Rome, New York and
  London fall back to a procedural sky that only really suits a dusk scene.
  `tools/export_refs.py` renders the composition sheets to paint against.
- **Difficulty is assigned by grid size alone**, and playtest times say that is
  wrong — some 10x10s take longer than the 15x15. The validator already runs a
  line solver, so it could score real difficulty from solving depth instead.
- On-device iOS testing.
- Daily puzzle, photo album, travel companion.
- Real Steam integration.
