local scheme = require("scheme.current")

return {
    ------------------
    ---- HYPRLAND ----
    ------------------

    -- Apps
    terminal                        = "kitty",
    browser                         = "brave",
    editor                          = "code",
    fileExplorer                    = "dolphin",
    audioSettings                   = "pavucontrol",
    gitEditor                       = "gitkraken",

    -- Touchpad
    touchpadDisableTyping           = true,
    touchpadScrollFactor            = 0.5,
    gestureFingers                  = 3,
    workspaceSwipeFingers           = 4,
    gestureFingersMore              = 4,

    -- Blur
    blurEnabled                     = true,
    blurSpecialWs                   = false,
    blurPopups                      = true,
    blurInputMethods                = true,
    blurSize                        = 8,
    blurPasses                      = 2,
    blurXray                        = false,

    -- Shadow
    shadowEnabled                   = true,
    shadowRange                     = 15,
    shadowRenderPower               = 4,
    shadowColour                    = "rgba(" .. scheme.inversePrimary .. "10)",

    -- Gaps
    workspaceGaps                   = 0,
    windowGapsIn                    = 2,
    windowGapsOut                   = 0,
    singleWindowGapsOut             = 0,

    -- Window styling
    windowOpacity                   = 0.90,
    windowRounding                  = 10,
    windowBorderSize                = 2,
    activeWindowBorderColour        = "rgba(82b176ff)",
    groupedWindowBorderColour       = "rgba(ffcc99ee)",
    groupedLockedWindowBorderColour = "rgba(e77778ff)",
    inactiveWindowBorderColour      = "rgba(" .. scheme.onSurfaceVariant .. "11)",

    -- Misc
    volumeStep                      = 10,
    volumeMax                       = 100,
    cursorTheme                     = "sweet-cursors",
    cursorSize                      = 24,
    sleepGestureCmd                 = "systemctl suspend-then-hibernate",

    ------------------
    ---- KEYBINDS ----
    ------------------

    -- Workspaces
    kbMoveWinToWs                   = "SUPER + ALT",
    kbMoveWinToWsGroup              = "CTRL + SUPER + ALT",
    kbGoToWs                        = "SUPER",
    kbGoToWsGroup                   = "CTRL + SUPER",
    kbNextWs                        = "CTRL + SUPER + Right",
    kbPrevWs                        = "CTRL + SUPER + Left",

    -- Window Group
    kbWindowGroupCycleNext          = "ALT + TAB",
    kbWindowGroupCyclePrev          = "SHIFT + ALT + TAB",
    kbUngroup                       = "SUPER + U",
    kbToggleGroup                   = "SUPER + Comma",

    -- Window Action
    kbMoveWindow                    = "SUPER + Z",
    kbResizeWindow                  = "SUPER + X",
    kbWindowPip                     = "SUPER + ALT + backslash",
    kbPinWindow                     = "SUPER + P",
    kbReorderWindow                 = "SUPER + R",
    kbWindowFullscreen              = "SUPER + F",
    kbWindowBorderedFullscreen      = "SUPER + ALT + F",
    kbToggleWindowFloating          = "SUPER + SHIFT + F",
    kbCloseWindow                   = "SUPER + Q",

    -- Special workspaces toggles
    kbSpecialWs                     = "SUPER + S",
    kbSystemMonitorWs               = "CTRL + SHIFT + Escape",
    kbMusicWs                       = "SUPER + M",
    kbCommunicationWs               = "SUPER + W",

    -- Apps
    kbTerminal                      = "SUPER + T",
    kbBrowser                       = "SUPER + B",
    kbEditor                        = "SUPER + C",
    kbFileExplorer                  = "SUPER + E",
    kbGitEditor                     = "SUPER + G",

    -- Misc
    kbSession                       = "CTRL + ALT + Delete",
    kbShowSidebar                   = "SUPER + N",
    kbClearNotifs                   = "CTRL + ALT + C",
    kbShowPanels                    = "SUPER + I",
    kbLock                          = "SUPER + O",
    kbRestoreLock                   = "SUPER + ALT + O",
}
