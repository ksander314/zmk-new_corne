# kbdtr

A console for my eyelash_corne keyboard, whose ZMK keymap is this repo.
It does three jobs:

1. **Look up** how to type a char and see the layers: in Emacs (`kbdtr.el`) or with `./kb`.
2. **Measure** typing by the Emacs keystroke log (`~/.emacs.d/keystroke-log.csv`) and check
   whether a keymap change helped.
3. **Ship** firmware: wait for the CI build and flash a half with one command.

Not here: the keymap is edited by hand in `../config/eyelash_corne.keymap`, and CI builds
the firmware and draws `../keymap-drawer/eyelash_corne.svg`.

## Emacs

`~/.emacs.d/init.el` loads `kbdtr.el` from the repo in `my/zmk-repo` (`~/src/zmk-new_corne`,
or `$ZMK_REPO`) and warns when it is not there; it works on macOS and Linux alike.

- `C-c K` (`kbdtr-find`): type a char or its Unicode name (`&`, `brace`, `э`) to see how to
  type it in the current input source; Enter copies it, `C-u` asks about the other source.
- `C-c L` (`kbdtr-layers`): the layers that type in the current input source. There `l`
  switches to the other source, `h` tints keys and combos by how often they are pressed,
  `g` reruns `./kb index` to recount, `f` searches.

The input source comes from the keystroke log's Hammerspoon feed on macOS, else from the
last letter before point.

## kb

```
./kb find '&'          how to type a char, for ABC and Russian – PC
./kb layers            the layers as text, as they type in each input source (--layout ru)
./kb index             out/index.json and out/layers.json for kbdtr.el (flash refreshes them too)
./kb heatmap           the busiest keys and combos by the keystroke log (--days N, --no-chords)
./kb bigrams           slowest pairs of consecutive chars, grouped by finger and hand
./kb fetch             wait for the CI build of HEAD, download it to firmware/<sha>/
./kb flash left|right  fetch, then copy the firmware to a half in bootloader mode
```

Keys are named by what the DVP layer prints on them (`O`, `N`), in either input source.
Needs `python3` and `gh`, nothing else. `KB_REPO` overrides the keymap repo (by default the
one kb lives in) and `KB_KLOG` the keystroke log.
