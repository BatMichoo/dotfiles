registerShortcut("Toggle Maximize or Tile Top", "Toggle Maximize or Tile Top", "Meta+Up", function() {
    let window = workspace.activeWindow;
    if (window) {
        // In KWin 6, maximizeMode value 3 represents full maximization (MaximizeFull).
        if (window.maximizeMode === 3 || (typeof KWin !== 'undefined' && window.maximizeMode === KWin.MaximizeFull)) {
            // Unmaximize first, then quick tile to the top half
            window.setMaximize(false, false);
            workspace.slotWindowQuickTileTop();
        } else {
            // Maximize fully
            window.setMaximize(true, true);
        }
    }
});


