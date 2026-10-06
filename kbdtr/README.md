# kbdtr

Tooling for my eyelash_corne ZMK config in `~/src/zmk-new_corne`.

```
./kb find '&'          how to type a character, for ABC and Russian – PC
./kb heatmap --open    keystroke heatmap from ~/.emacs.d/keystroke-log.csv → out/heatmap.svg
                       (chords like C-x C-f included; --no-chords for typed chars only)
./kb bigrams           slowest pairs of consecutive chars, grouped by finger/hand
./kb index             out/index.json and out/layers.json for the cheat sheets (also refreshed by flash)
./kb layers            the layers as text, as they type in each input source (--layout ru)
./kb draw --open       draw the current keymap → out/keymap.svg
./kb fetch             wait for the CI build of HEAD, download firmware → firmware/<sha>/
./kb flash left|right  copy that firmware to a half in bootloader mode
```

Needs `uv` (runs the script and keymap-drawer) and `gh`. Paths can be overridden with
`KB_REPO` and `KB_KLOG`.

## Cheat sheet

`hammerspoon.lua` binds Cmd+Alt+A to a search over `out/index.json`: type a character or
its Unicode name (`&`, `brace`, `э`) to see how to type it in the current input source.
Enter copies the character. `~/.hammerspoon/init.lua` loads it with
`dofile(os.getenv("HOME") .. "/src/kbdtr/hammerspoon.lua")`.

`kbdtr.el` does the same in Emacs, on macOS and Linux alike: `C-c K` (`kbdtr-find`) is
the search, `C-c L` (`kbdtr-layers`) shows the layers that type in the current input
source; there `l` switches to the other source, `f` searches, `h` tints the keys and
combos by how often the keystroke log says they are pressed, and `g` reruns `kb index`
to recount. The source comes from
the keystroke log's Hammerspoon feed on macOS, else from the last letter before point.
`~/.emacs.d/init.el` loads it when `~/src/kbdtr/kbdtr.el` exists.
