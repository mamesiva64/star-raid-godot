# Star Raid

A small Godot 4.6 browser game inspired by classic fixed-screen alien shooters.

## Controls

- Move: arrow keys or A/D
- Fire: Space or Enter
- Touch: drag to move, tap to fire
- Restart: Space, Enter, or tap after game over

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

