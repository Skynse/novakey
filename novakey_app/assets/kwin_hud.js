// Only manages this process's HUD. No global window rules are modified.
var hudTitle = 'NovaKey Bindings HUD @PID@';
var lastApplication = workspace.activeWindow;
function isHud(w) { return w && String(w.caption) === hudTitle; }
function configure(w) {
    if (!isHud(w)) return;
    w.keepAbove = true;
    w.skipTaskbar = true;
    w.skipPager = true;
    w.skipSwitcher = true;
    var output = lastApplication ? lastApplication.output : w.output;
    if (output) {
        var area = output.geometry;
        var frame = w.frameGeometry;
        w.frameGeometry = {
            x: area.x + Math.max(0, (area.width - frame.width) / 2),
            y: area.y + Math.max(0, (area.height - frame.height) / 2),
            width: frame.width,
            height: frame.height
        };
    }
}
workspace.windowAdded.connect(configure);
workspace.windowActivated.connect(function(w) {
    if (isHud(w)) {
        if (lastApplication) workspace.activeWindow = lastApplication;
    } else if (w) {
        lastApplication = w;
    }
});
workspace.windowRemoved.connect(function(w) {
    if (w === lastApplication) lastApplication = null;
});
workspace.windowList().forEach(configure);
