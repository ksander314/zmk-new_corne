# kbdtr

Tooling for my eyelash_corne ZMK config in `~/src/zmk-new_corne`.

```
./kb find '&'          how to type a character, for ABC and Russian – PC
./kb heatmap --open    keystroke heatmap from ~/.emacs.d/keystroke-log.csv → out/heatmap.svg
./kb draw --open       draw the current keymap → out/keymap.svg
./kb fetch             wait for the CI build of HEAD, download firmware → firmware/<sha>/
./kb flash left|right  copy that firmware to a half in bootloader mode
```

Needs `uv` (runs the script and keymap-drawer) and `gh`. Paths can be overridden with
`KB_REPO` and `KB_KLOG`.
