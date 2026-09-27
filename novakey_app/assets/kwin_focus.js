// Plasma 6 focus events, delivered to the current NovaKey Studio session.
// No titles, keystrokes, or window content are collected.
function publish(window) {
    if (!window || window.specialWindow) return;
    callDBus('org.novakey.Studio.Focus', '/org/novakey/Studio/Focus',
        'org.novakey.Studio.Focus', 'ActiveApplication',
        String(window.desktopFileName || ''),
        String(window.resourceClass || ''),
        String(window.resourceName || ''));
}
workspace.windowActivated.connect(publish);
workspace.windowAdded.connect(function(window) {
    window.desktopFileNameChanged.connect(function() {
        if (workspace.activeWindow === window) publish(window);
    });
    window.windowClassChanged.connect(function() {
        if (workspace.activeWindow === window) publish(window);
    });
});
publish(workspace.activeWindow);
