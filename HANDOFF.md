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
  the artwork, so a card is the same shape everywhere it appears. Nothing crops
  to fit, which means a badly proportioned file is a badly proportioned card.
  The brief is 3:2 — 1800 × 1200, or 1200 × 1800 upright — and it is written
  down in `README.md`. `tokyo.jpg` and `paris.jpg` are 853 × 1844, a 1:2.16
  sliver, and want redrawing.
* **Puzzle counts vary by city.** S1 is 3·3·2·2·2, S2 is 2·2·2·2·1. Nothing in
  the code assumes a number; it is the length of a list.
* **Cognition drives the curve, not size.** Each grid introduces one new kind
  of reasoning. See the table in the season design below.
* **One answer only.** The build refuses ambiguous grids outright. Up to four
  cells may be left to trial and error (`GUESS_LIMIT`), and even then every
  completion is enumerated and exactly one must fit. Nothing ships that has two
  valid pictures.
* **White is not one of the colours. White is the grid.** An ink as light as an
  empty cell draws holes in the picture rather than shapes. `check_palette` in
  `tools/build_content.py` refuses one, the same way the builder refuses an
  ambiguous grid — Bermuda's cloud and sky were both over the line.
* **A palette has to be a ladder in lightness, not only a spread of hues.**
  Reykjavík's navy and its near-black were the same cell at grid size.
* **A clue number is not the ink.** The ink is chosen to look right filling a
  cell; the same colour printed thin on the open page is a different problem,
  and the pale end of a palette vanished there. `Pal.legible()` walks the
  lightness away from the page until the number reads — darkening on paper,
  lightening in the evening. Only the numbers are corrected: the fill is the
  picture, so the fill stays the colour it is meant to be.
* **The postcards are a pile, not a menu.** No destination buttons, no season
  switcher. One card fills the screen; a timeline underneath is ordered by
  postmark, shows only earned cards, and keeps the face you were reading as you
  move along it.
* **The card you are reading is the one in the middle of the line.** The
  timeline is pulled, not aimed at: it slides under a fixed mark, ticks as it
  crosses each card, and settles on whichever it came to rest nearest. Tapping
  a dot still glides it to the middle, but nothing requires hitting one.
* **Three sections, not four.** Map and Journal were one screen's worth of
  facts split over two pages. The map is pinned to the top of the Journal,
  lighting the destination you are travelling to; the list under it is the
  destinations, one line each.
* **The card has one face and does not turn.** A blank card, a point of light,
  and a picture that develops as the grids are solved. It used to arrive
  letter-side up, which put the whole letter on screen before a single grid had
  been solved — and the rule everywhere else is that a letter stays sealed
  until its city is finished. It arrives on the finishing screen and on the back
  of the card in Postcards, both of which are earned.
* **The card is the only way into a destination.** A row goes straight to it —
  the light, and the picture filling in. The rows briefly expanded into a
  The rows briefly expanded into a strip of grid thumbnails first; that put a
  picture of the puzzle one tap from the card that already has one, and made the
  list something to operate rather than something to read.
* **Every screen that fills itself has a way back out of it.** The card had
  none: turning it over and opening a grid were the only things on it that
  answered a tap, both of them further in. `PARENT` in `main.gd` is the
  hierarchy — puzzle up to card, card up to journal — and a visible link goes
  through `back()` so it cannot drift away from what the escape key does.
* **A setting is a name and a state.** No explanatory paragraph under it, and
  nothing on the page that is not a setting. The crosshair is not a preference;
  the row and column under the cursor are how a clue is read against a cell.
* **Both faces of a card are rounded.** The front used to draw its picture as a
  square, which put corners back on the paper underneath it.
* **The back is set in one size.** The postmark used to be stacked at twice the
  size of the stamp beside it, which made the cancellation the loudest thing on
  a card whose point is the letter.
* **The Chinese is 霞鹜文楷 (LXGW WenKai), a 楷体.** The game is a stack of things
  someone wrote by hand; the face should not be the one part of it that reads
  as an interface. Latin stays IBM Plex — the CJK face hangs off it as a
  fallback, so a mixed line sets in one pass.
* **Sending a card to a friend has no button anywhere.** The screen, the share
  code and the web page all still work and are still tested by the tour; only
  the ways in are pulled, until there is somewhere that earns one.
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

1. **No artwork for any Season Two city.** They fall back to tinted paper,
   which reads as "not developed yet" rather than as broken.
2. **London's second grid is not inverted yet.** The structure is in place and
   marked with a TODO in `tools/build_content.py`; the drawing has to be made.
3. **`COMPOSITION` positions for Rome, New York and London** were measured
   against the colour paintings they no longer use.
4. **Tokyo and Paris are drawn at 853 × 1844**, so their cards are a 1:2.16
   sliver on every screen. The brief is 3:2; these two predate it.
5. **Without artwork, a card is not the same shape on every screen.** `CardBack`
   falls back to 2:3 and the finishing screen to 3:2, so an undrawn Season Two
   city turns from upright to landscape on the way between them. Drawing the
   artwork settles it, since both then measure the same file.
6. **"Send to a friend" needs a home.** Nothing reaches `share` but the tour.
7. **The pinned map is height-limited, so a desktop panel is mostly empty.**
   `_map_area()` fits a 48x24 box inside the panel and centres it; at 250pt
   tall on a 1064pt-wide column that leaves a lot of paper either side. It
   reads fine, but the panel could be capped to the map's own width.
8. **Names still crowd in Europe on the map.** `_draw_labels` places the lit
   destination first and dims the rest, which is enough to read the one that
   matters — but half a dozen names still overprint each other behind it.

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
* **A nav bar is not a back button.** It says where you are. A screen whose
  every control leads further in needs its own way out, and "the section is
  still highlighted up there" is not one — you cannot tell a page you are on
  from a page you can go to.
* **A gesture cannot survive `replace()`.** The timeline could not be dragged
  because moving one card swapped the screen for a fresh one, destroying the
  control mid-drag. Anything that changes while a finger is down has to change
  in place, and write where it got to into `args` so a rebuild under the player
  still lands in the right spot.
* **A container is never narrower than its contents.** A "Send to a friend"
  button added to the expanded destination was 125pt of a 350pt line, and the
  overflow does not clip — it pushes the whole page off the right of a phone,
  map and headings included. Budget the row before adding to it.
* **The scroll bar floats over the column, it does not reserve space.** Rows
  inset their right edge by 14pt for it; anything else on that edge has to as
  well, or its text is printed underneath the bar.
* **New user-facing strings need a row in `data/translations.csv`,** then
  `tools/subset_font.py`, then `godot --headless --editor --quit`. The English
  passes through untranslated, so nothing errors — it just shows up in the
  middle of a Chinese page.
* **Four inks is only four inks if you can count them,** and a palette that
  looks right as filled cells can still be unreadable as clue numbers. Both bugs
  shipped and neither shows up as an error. The tour has `colour_puzzle_four`,
  `colour_puzzle_five` and `colour_puzzle_five_evening` now — a new palette gets
  looked at in both moods, or it is not checked at all.
* **`clip_contents` clips to the rect, not to the style box's corners,** and
  `clip_children` does not exist on gl_compatibility, which is what this project
  renders with. `CornerMask` paints the corners out in the colour of the page
  instead; it only works where that page is flat. For a texture, fill a rounded
  polygon and carry the crop in the uvs — which are normalised in Godot 4, not
  pixels, whatever Godot 3 did.
