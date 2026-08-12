#!/bin/bash
# Install the Russian-on-DVP-positions layout for GNOME.
#
# This is the alternative to scripts/linux-setup.sh. Instead of having the
# keyboard tell the host to change layout -- which needs host-side code on both
# platforms, because nothing outside GNOME Shell can select an input source --
# it moves the arrangement into the layout itself. The firmware then stays on
# its DVP layer permanently and holds no language state, so switching language
# is just GNOME's own Super+Space.
#
# Nothing here touches the firmware: layer 0 (QWERTY) and the Hyper macros stay
# where they are, so a machine without this layout installed still works the old
# way. See the bottom of this script for how to roll back.
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
