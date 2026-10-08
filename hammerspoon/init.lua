-- Idempotent input source switching for ZMK split keyboard
-- Hyper+1 → ABC (used with DVP layer)
-- Hyper+2 → Russian (used with QWERTY layer)

require("hs.ipc")

local log = io.open("/tmp/hammerspoon.log", "a")
local function logMsg(msg)
    log:write(os.date("%H:%M:%S") .. " " .. msg .. "\n")
    log:flush()
end

logMsg("=== Hammerspoon config loaded ===")

local hyper = {"cmd", "alt", "ctrl", "shift"}

hs.hotkey.bind(hyper, "1", function()
    logMsg("Hyper+1 triggered → switching to ABC")
    hs.keycodes.setLayout("ABC")
end)

hs.hotkey.bind(hyper, "2", function()
    logMsg("Hyper+2 triggered → switching to Russian – PC")
    hs.keycodes.setLayout("Russian – PC")
end)

-- Push every input source switch to the Emacs keystroke log
-- (~/.emacs.d/lisp/init-keystroke-log.el, my/klog-set-layout).
-- Value matches what the log used before: "ABC", "RussianWin".
local function pushLayoutToEmacs()
    local id = hs.keycodes.currentSourceID():gsub("^com%.apple%.keylayout%.", "")
    hs.task.new("/opt/homebrew/bin/emacsclient", nil,
        {"-e", string.format('(when (fboundp \'my/klog-set-layout) (my/klog-set-layout "%s"))', id)}):start()
end
hs.keycodes.inputSourceChanged(pushLayoutToEmacs)
pushLayoutToEmacs()
