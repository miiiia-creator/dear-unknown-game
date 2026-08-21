# Where this is

A working note for whoever picks this up next. `README.md` describes the
project; this describes its state, the decisions that are settled, and what is
still open.

## Running it

```bash
godot --path /Users/miazhou/Downloads/around-the-world
```

The window opens at 430×932 — phone-shaped, because the game is played upright
and every layout bug this project has had was a portrait bug. Drag it wider to
see what a monitor does with it.

```bash
python3 tools/build_content.py          # data/cities.json + web/postcard.html
python3 tools/subset_font.py            # after ANY Chinese copy change
godot --headless --editor --quit        # after subsetting, or fonts render tofu
godot --headless --path . --script tests/run_tests.gd
godot --path . --position 0,0 -- --tour # screenshots, must print 0 errors
tools/deploy_web.sh "what changed"      # export, package, push, Pages rebuilds
```

Live: <https://miiiia-creator.github.io/dear-unknown/> — password `thelastones`
(client-side gate in `web/shell.html`; a doormat, not a lock).
Source: <https://github.com/miiiia-creator/dear-unknown-game>

Delete the save to replay the opening:

```bash
rm -f "$HOME/Library/Application Support/Godot/app_userdata/Dear, Unknown/around_the_world.save"
```

## Settled decisions — do not re-litigate these

* **Portrait only.** Landscape is not being maintained.
* **Season One is grey.** Ink drawings, grey palettes. Season Two is where
  colour returns, one ink at a time: Kyoto 1, San Francisco 2, Istanbul 3,
  Reykjavík 4, Bermuda 5. The count is the season's argument.
* **A card is whatever shape its picture is.** Both faces read the aspect from
  the artwork, so turning a card never changes its size.
* **Puzzle counts vary by city.** S1 is 3·3·2·2·2, S2 is 2·2·2·2·1. Nothing in
  the code assumes a number; it is the length of a list.
* **Cognition drives the curve, not size.** Each grid introduces one new kind
  of reasoning. See the table in the season design below.
* **One answer only.** The build refuses ambiguous grids outright. Up to four
  cells may be left to trial and error (`GUESS_LIMIT`), and even then every
  completion is enumerated and exactly one must fit. Nothing ships that has two
  valid pictures.
* **The postcards are a pile, not a menu.** No destination buttons, no season
  switcher. One card fills the screen; a timeline underneath is ordered by
  postmark, shows only earned cards, and keeps the face you were reading as you
  move along it.
* **Postmarks are not the play order.** Season Two was posted in the middle of
  Season One. A card earned late lands between two the player has had for
  hours, and that discovery is the point — which is why blank slots are never
  drawn on the timeline.

## Season design

Season One — *The Last Ones*, twelve grids:

| City | Grids | What arrives |
|---|---|---|
| Tokyo | pond 5×5, blossom 5×5, torii 10×10 | what a number means; two numbers in a line; scale — all square, on purpose |
| Paris | croissant 10×5, café 10×9, tower 10×15 | first non-square; asymmetry; tall |
| Rome | coin 10×10, fountain 12×11 | overlap reasoning — a run of 8 in a line of 10 fixes 6 cells |
| New York | someone 8×15, cab 15×10 | the sparsest grid; cannot finish without marking blanks |
| London | Big Ben 15×20, postcard 15×20 | same size twice — the second inverts, and what fills is the ground |

Season Two — *The Color Doesn't Exist*, nine grids: Kyoto (blossom, Hello
Kitty), San Francisco (croissant, sourdough), Istanbul (coin, phone), Reykjavík
(woman, sea), Bermuda (ship and plane). All ten letters written, English and
Chinese.

## Open

1. **Journal merge — the next task.** Fold Map into Journal, one screen called
   Journal. World map pinned at the top, reacting to the list below it
   (expanded city lights up, others dim). Under it, a vertical list where each
   city is an expandable card; expanded shows its grids in a single row (never
   more than three). Tapping the city opens its postcard — the ritual — and
   tapping a grid chip jumps straight to that puzzle. Delete `journal_screen`
   and `world_map` as separate destinations; nav goes from four to three.
2. **Map opens a blank card for undrawn cities.** `is_city_written()` exists
   and the map's routing does not use it.
3. **No artwork for any Season Two city.** They fall back to tinted paper,
   which reads as "not developed yet" rather than as broken.
4. **London's second grid is not inverted yet.** The structure is in place and
   marked with a TODO in `tools/build_content.py`; the drawing has to be made.
5. **`COMPOSITION` positions for Rome, New York and London** were measured
   against the colour paintings they no longer use.

## Things that bit, so they do not bite again

* **Read the whole file before rewriting it.** Rewriting `nonogram.gd` from a
  partial read silently deleted four functions. The test count dropping from 75
  to 73 was the only signal.
* **Check slice boundaries.** A replacement whose `end` came before its `start`
  deleted 400 lines of `build_content.py`, including hand-measured coordinates.
* **A clean tour is not proof the thing looks right.** The postcard's sun
  shafts were reported fixed twice while still on screen, because `0 errors`
  was checked instead of the screenshot. Open the image.
* **The tour references puzzle ids by name.** Cutting a puzzle breaks it; the
  failure is `Nonexistent function 'total_filled' in base 'Nil'`.
* **New `class_name` scripts need `godot --headless --editor --quit`** before
  anything can use them.
* **Use a heredoc for commit messages.** Quotes and parentheses in `-m` break
  the shell.
