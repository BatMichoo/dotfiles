registerShortcut("Toggle Maximize or Tile Top", "Toggle Maximize or Tile Top", "Meta+Up", function() {
    let window = workspace.activeWindow;
    if (window) {
        if (window.maximizeMode === KWin.MaximizeFull || window.maximizeMode === 3) {
            // Unmaximize first, then quick tile to the top half
            window.setMaximize(false, false);
            workspace.slotWindowQuickTileTop();
        } else {
            // Maximize fully
            window.setMaximize(true, true);
        }
    }
});
