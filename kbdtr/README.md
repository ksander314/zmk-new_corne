# kbdtr

Tooling for my eyelash_corne ZMK config in `~/src/zmk-new_corne`.

```
./kb find '&'          how to type a character, for ABC and Russian – PC
./kb heatmap --open    keystroke heatmap from ~/.emacs.d/keystroke-log.csv → out/heatmap.svg
                       (chords like C-x C-f included; --no-chords for typed chars only)
./kb bigrams           slowest pairs of consecutive chars, grouped by finger/hand
./kb index             out/index.json for the Cmd+Alt+A cheat sheet (also refreshed by flash)
./kb draw --open       draw the current keymap → out/keymap.svg
./kb fetch             wait for the CI build of HEAD, download firmware → firmware/<sha>/
./kb flash left|right  copy that firmware to a half in bootloader mode
```

Needs `uv` (runs the script and keymap-drawer) and `gh`. Paths can be overridden with
`KB_REPO` and `KB_KLOG`.

## Cheat sheet

`~/.hammerspoon/init.lua` binds Cmd+Alt+A to a search over `out/index.json`: type a
character or its Unicode name (`&`, `brace`, `э`) to see how to type it in the current
input source. Enter copies the character.
