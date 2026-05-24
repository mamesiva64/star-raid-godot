# Star Raid

A small Godot 4.6 browser game inspired by classic fixed-screen alien shooters.

## Controls

- Move: arrow keys, A/D, or relative touch drag
- Fire: automatic
- Restart: Space, Enter, or tap after game over

## Powerups

Carrier enemies are marked with a ring. Destroy them to drop timed items:

- `3WAY`: three-shot spread
- `LASER`: forward beam
- `RAPID`: faster auto-fire
- `GUARD`: temporary shield
- `WIDE`: five-shot spread

## Local Run

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

## Web Export

```bash
mkdir -p docs
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release Web docs/index.html
```

The `docs/` directory is intended for GitHub Pages.
