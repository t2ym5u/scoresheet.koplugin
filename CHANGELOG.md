# Changelog

## [1.0.8] - 2026-11-24

### Changed
- Picks up game-common 1.20.0: a deferred action no longer runs once the
  game is closed or a new game has started, and the game is saved a few
  seconds after a move instead of after every one, and at once on close,
  suspend or power-off.

## [1.0.7] - 2026-11-24

### Changed
- Picks up game-common 1.19.0: with the Dashboard installed, the title bar's
  close icon becomes a house that goes back to it.

## [1.0.6] - 2026-11-24

### Changed
- Picks up game-common 1.18.0: a status line cut off with "…" opens in full
  when tapped, so a long hint can be read.

## [1.0.5] - 2026-11-18

### Changed
- Picks up game-common 1.17.0 (a board redraw fix used by chess, binairo and
  tatami; no change in this game).

## [1.0.4] - 2026-11-12

### Changed
- Picks up game-common 1.16.0: games for two readers (new Two readers
  category) and the shared Start / Join dialog.

## [1.0.3] - 2026-11-04

### Fixed
- The tool no longer crashes when an outdated plugin is installed alongside:
  shared modules left behind by an older plugin are replaced by this
  plugin's own copy instead of being used as they are.

## [1.0.2] - 2026-11-04

### Changed
- Uses less memory: the tool loads when you open it, not when KOReader
  starts, so it no longer takes memory or startup time while unused.

## [1.0.1] - 2026-11-03

### Fixed
- Always listed under Tools → Games → Party & quiz, never under "Other",
  whichever game's copy of the shared category table the reader loaded.

## [1.0.0] - 2026-11-03

### Added
- First release: score sheets for games played around a real table — Tarot (FFT rules, 3–5 players, called partner at 5), Belote / Coinche (target score, dedans, litige, capot, coinche/surcoinche), word tile game (+50 bonus, leftover tiles), Rummy (elimination over a limit) and a free sheet for any other game.
- Big on-screen number pad, live preview of each round, undo, tap a round for its details, the leader's total highlighted.
- One game in progress per sheet, kept when the screen is closed; player names remembered, New game keeps them.
- Rules of each sheet in English and French; interface in English, French, Spanish and German.
