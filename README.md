# The Programming Labyrinth

The Programming Labyrinth is a Godot 4 educational dungeon-crawler MVP where combat is driven by programming puzzles. Players explore maze stages, fight bugs by fixing code or reordering logic blocks, collect temporary loot, and confirm rewards only after clearing a stage.

## Current MVP Scope

- Four playable chapters wired through the main menu and stage flow.
- **All four chapters are always selectable** from the main menu in this MVP/dev build (no unlock gate). Progression still advances stage-by-stage after each victory.
- Twenty playable maze stages (5 per chapter) with chapter-appropriate enemy and chest spawns.
- Maze gameplay with player, enemies, chests, portal, HUD, pause, victory, and game-over overlays.
- Chapter 1-3 combat using multi-bug code-fix encounters.
- Chapter 4 combat using block assembly with up/down reorder controls.
- Consumables: `green_tea`, `focus_pill`, `hint_chip`, `block_snap_chip`.
- Artifacts: `github_cape`, `ide_armor`, `runtime_patch`.
- Existing placeholder art is reused where final art is still missing.
- Entity sprites are scaled to sane world-space sizes (player ~48 px, normal enemy ~52 px, strong ~64 px, boss ~84 px, chest ~44 px, portal ~64 px) regardless of source texture resolution.
- Gameplay camera is zoomed out to 0.75× and bounded to stage extents so the maze fits the viewport.

## Requirements

- Godot `4.6.2 stable` standard build.
- Python 3 for repository resource checks.

## Run The Game

1. Open the repository root in Godot.
2. Run the main scene: `res://scenes/menus/MainMenu.tscn`.
3. Select a chapter and start a new game.

Command-line smoke run:

```bash
godot --headless --path . --quit-after 3
```

## Controls

- Move: `WASD` or arrow keys.
- Interact: `E` or `Enter`.
- Pause: `Esc`.
- Combat: choose bug lines/fixes or reorder blocks, then press `Submit`.

## Test Commands

Run the same suite used by CI:

```bash
godot --headless --path . --quit-after 3
godot --headless --path . --script tests/test_all.gd
godot --headless --path . tests/test_runner.tscn
godot --headless --path . tests/test_runner_combat.tscn
godot --headless --path . tests/test_runner_maze.tscn
godot --headless --path . tests/test_runner_inventory_artifacts.tscn
godot --headless --path . tests/test_runner_combat_items.tscn
godot --headless --path . --script tests/test_autoload_flow.gd
godot --headless --path . --script tests/test_menu_scripts.gd
python3 scripts/check_resource_refs.py
```

## Project Structure

- `autoload/`: global game, HP/time, inventory, data, and telemetry managers.
- `data/`: JSON gameplay data for stages, enemies, bugs, rules, and loot.
- `docs/`: design and implementation notes.
- `scenes/`: Godot scenes and scripts for menus, maze, combat, entities, and UI.
- `scripts/`: gameplay systems shared by scenes.
- `tests/`: headless smoke and gameplay coverage.
- `assets/`: sprite assets used by the playable MVP.

## Repository Health

Before opening a pull request or pushing a release branch, run the full test suite above and confirm `python3 scripts/check_resource_refs.py` reports `MISSING 0`.
