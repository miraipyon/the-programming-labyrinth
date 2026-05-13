# The Programming Labyrinth

A Godot 4 educational maze-crawler where combat is solved by debugging code.

Players clear maze stages, fight bug-themed enemies through programming puzzles, manage temporary/permanent loot, and progress chapter-by-chapter.

## Highlights

- 20 handcrafted stages (`4 chapters x 5 stages`).
- Strict progression lock:
  - Start with only `Chapter 1 / Stage 1` unlocked.
  - Clear stage to unlock next stage.
  - Clear chapter to unlock next chapter.
- Per stage spawn contract:
  - `4 enemies`
  - `3 chests` (`1 rare + 2 normal`)
- Puzzle combat modes:
  - Multi-bug Python code fix (chapter 1-3)
  - Block assembly algorithm (chapter 4)
- Frame-by-frame character animation via `SpriteAnimator`:
  - Directional player idle/walk on the maze map.
  - Animated player/enemy portraits in combat UI.
- Inventory system with consumables and artifacts.
- Failure rules:
  - Lose when `HP = 0` or `timer = 0`.
  - Temporary loot is discarded on failure/retry.
- Star rating per stage (saved persistently):
  - `3 stars`: elapsed `< 1/3` total stage time
  - `2 stars`: elapsed `< 2/3` total stage time
  - `1 star`: cleared before timeout
  - `0 star`: failed
- **Background music**: random shuffle from `music/background_music/` via `BackgroundMusicManager` autoload.
- **SFX**: contextual sound effects from `music/audio/` via `SoundManager` autoload (UI clicks, combat events, chest open, portal, stage clear, etc.).

## Tech Stack

- Engine: **Godot 4.6.x stable** (tested locally with `4.6.2`)
- Language: **GDScript**
- Data: JSON-driven content (`data/*.json`)
- Validation helper: Python 3 script (`scripts/check_resource_refs.py`)

## Project Structure

- `autoload/`: global managers (state, hp/time, inventory, data, telemetry, BGM, SFX, animation metadata)
- `scenes/`: menus, maze, combat, entities, UI
- `scripts/`: reusable gameplay systems
- `data/`: enemies, stages, bugs, rules, loot tables
- `tests/`: headless tests and embedded suites
- `assets/`, `assets_2/`: game art assets, including `assets/MC/Animation/` and enemy `Animation/` frame sequences
- `music/background_music/`: background music tracks (MP3)
- `music/audio/`: sound effect library (OGG)
- `docs/`: GDD and project documentation

## Requirements

- Godot `4.6.2` (desktop/editor + headless for CI tests)
- Python `3.x`

## Run

Open in Godot and run:

- Main scene: `res://scenes/menus/MainMenu.tscn`

Quick CLI smoke run:

```bash
godot --headless --path . --quit-after 3
```

## Controls

- Move: `WASD` or arrow keys
- Interact: `E` / `Enter`
- Pause: `Esc`
- Combat: select/fix, then `SUBMIT`
- Home screen: **Quit** button is at the **bottom-left corner**

## Test

Main full suite:

```bash
godot --headless --path . --script tests/test_all.gd
```

Additional suites:

```bash
godot --headless --path . --script tests/test_menu_scripts.gd
godot --headless --path . --script tests/test_autoload_flow.gd
godot --headless --path . tests/test_runner.tscn
godot --headless --path . tests/test_runner_combat.tscn
godot --headless --path . tests/test_runner_maze.tscn
godot --headless --path . tests/test_runner_inventory_artifacts.tscn
godot --headless --path . tests/test_runner_combat_items.tscn
python3 scripts/check_resource_refs.py
```

## CI / Quality Notes

- Repository health tests verify scene contracts and data constraints.
- Stage generation tests verify unique route and required enemy/chest distribution.
- Menu/game-flow tests verify unlock logic, victory/game-over flow, star persistence, and UI hooks.
- Audio tests verify all BGM tracks and SFX files exist and are reachable.
- Animation health checks verify every declared player/enemy frame sequence exists and loads.
- `scripts/check_resource_refs.py` understands `SpriteAnimator` frame-sequence prefixes like `idle1.png`, `idle2.png`, ...

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
