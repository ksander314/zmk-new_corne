#!/bin/bash
# Install the Russian-on-DVP-positions layout for GNOME.
#
# The stock `ru` layout is drawn for QWERTY positions, so using it means the
# firmware has to move the alphabet to match, and a keyboard that loses track of
# the host then types nonsense. This installs `ru` permuted onto the DVP
# positions instead: the firmware types the same letters in both modes and only
# a handful of punctuation combos care which language is on.
#
# Nothing here touches the firmware. See the bottom of this script for how to
# roll back.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
SRC="$REPO/layouts/rudvp"
DEST_DIR="$HOME/.config/xkb/symbols"

[ -f "$SRC" ] || {
    echo "$SRC is missing -- run: python3 scripts/gen-layouts.py" >&2
    exit 1
}

mkdir -p "$DEST_DIR"
cp "$SRC" "$DEST_DIR/rudvp"
echo "installed $DEST_DIR/rudvp"

# Swap the stock 'ru' source for 'rudvp', keeping position and any other
# sources the user has configured. Done in python because the value is a list
# of GVariant tuples and editing it textually is how the last script broke.
OLD=$(gsettings get org.gnome.desktop.input-sources sources)
NEW=$(python3 -c '
import ast, sys
sources = ast.literal_eval(sys.stdin.read().strip())
print(repr([("xkb", "rudvp") if s == ("xkb", "ru") else s for s in sources]))
' <<< "$OLD")

if [ "$NEW" = "$OLD" ]; then
    echo "input sources already: $OLD"
else
    gsettings set org.gnome.desktop.input-sources sources "$NEW"
    echo "input sources: $OLD"
    echo "            -> $NEW"
fi

cat <<'EOF'

Log out and back in -- mutter builds its keymap once per session, and GNOME has
never seen this layout before.

Then check, with the keyboard on its DVP layer:

  gsettings get org.gnome.desktop.input-sources sources   # should list rudvp
  Super+Space, then type the keys that give  й ц у к е    # top row, left half

The panel indicator may show a placeholder name instead of "Russian (Dvorak
Programmer)": gnome-control-center reads layout names from the system
/usr/share/X11/xkb/rules/evdev.xml, which knows nothing about a user layout.
That is cosmetic -- the keymap itself comes from ~/.config/xkb.

To roll back:

  gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'ru')]"
  rm ~/.config/xkb/symbols/rudvp

EOF
