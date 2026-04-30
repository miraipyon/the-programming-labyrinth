# Contributing

Thanks for helping improve The Programming Labyrinth. Keep changes small, testable, and easy to review.

## Development Baseline

- Use Godot `4.6.2 stable`.
- Keep source files UTF-8 with LF line endings.
- Use tabs for Godot script/scene/resource files and spaces for Markdown, JSON, YAML, and Python.

## Before You Push

Run the full local suite:

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

## Asset And Data Policy

- Do not add new visual assets unless they are referenced by scenes/scripts/data or documented as unused source art.
- If you rename an asset, update every `res://` reference and run `scripts/check_resource_refs.py`.
- Gameplay data changes should include or update tests when they affect encounter flow, item behavior, or scene contracts.
