import Gio from 'gi://Gio';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import {getInputSourceManager} from 'resource:///org/gnome/shell/ui/status/keyboard.js';

const OBJECT_PATH = '/org/gnome/Shell/Extensions/ZmkInputSource';

const IFACE = `
<node>
  <interface name="org.gnome.Shell.Extensions.ZmkInputSource">
    <method name="Activate">
      <arg type="s" direction="in" name="xkbId"/>
      <arg type="b" direction="out" name="activated"/>
    </method>
    <method name="List">
      <arg type="as" direction="out" name="xkbIds"/>
    </method>
    <method name="Current">
      <arg type="s" direction="out" name="xkbId"/>
    </method>
  </interface>
</node>`;

export default class ZmkInputSourceExtension extends Extension {
    enable() {
        this._dbus = Gio.DBusExportedObject.wrapJSObject(IFACE, this);
        this._dbus.export(Gio.DBus.session, OBJECT_PATH);
    }

    disable() {
        this._dbus?.unexport();
        this._dbus = null;
    }

    /**
     * Select the input source with the given xkb id ('us', 'ru', 'us+dvp', ...).
     *
     * Going through InputSource.activate() means GNOME Shell performs the
     * switch itself, so the panel indicator, the IBus engine and the mutter
     * keymap all end up agreeing. Idempotent: activating the source that is
     * already current is a no-op as far as the user can tell.
     *
     * @param {string} xkbId - xkb id of the source to activate
     * @returns {boolean} true if a matching source was found
     */
    Activate(xkbId) {
        const source = this._find(xkbId);
        if (!source)
            return false;

        source.activate(true);
        return true;
    }

    /**
     * @returns {string[]} xkb ids of every configured input source
     */
    List() {
        return this._sources().map(source => source.xkbId);
    }

    /**
     * @returns {string} xkb id of the active input source, '' if there is none
     */
    Current() {
        return getInputSourceManager().currentSource?.xkbId ?? '';
    }

    _sources() {
        // inputSources is an object keyed by source index, not an array.
        return Object.values(getInputSourceManager().inputSources);
    }

    _find(xkbId) {
        return this._sources().find(
            source => source.xkbId === xkbId || source.id === xkbId);
    }
}
