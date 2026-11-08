import qs.services
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland

Scope {
    id: root
    property bool open: false

    PanelWindow {
        id: panelWindow
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:modeSelector"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        onVisibleChanged: {
            if (visible) {
                GlobalFocusGrab.addDismissable(panelWindow);
                Qt.callLater(() => content.forceActiveFocus());
            } else {
                GlobalFocusGrab.removeDismissable(panelWindow);
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                if (root.open) root.open = false;
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.open = false;
                event.accepted = true;
            }
        }

        ModeSelectorContent {
            id: content
            anchors.fill: parent
            onCloseRequested: root.open = false
        }
    }

    IpcHandler {
        target: "modeSelector"

        function toggle(): void {
            root.open = !root.open;
        }
        function open(): void {
            root.open = true;
        }
        function close(): void {
            root.open = false;
        }
    }

    GlobalShortcut {
        name: "modeSelectorToggle"
        description: "Toggles the desktop mode selector"

        onPressed: {
            root.open = !root.open;
        }
    }
}
