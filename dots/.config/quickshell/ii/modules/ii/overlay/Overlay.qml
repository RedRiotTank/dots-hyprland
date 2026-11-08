import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property Component regionComponent: Component {
        Region {}
    }

    readonly property string focusedScreenName: Hyprland.focusedMonitor?.name
        ?? (Quickshell.screens[0]?.name ?? "")

    // One overlay window per monitor. The interactive overlay opens on the
    // focused monitor, while pinned widgets stay on the monitor where they
    // were placed. This also lets each monitor keep its own widget layout.
    Variants {
        model: Quickshell.screens

        LazyLoader {
            id: scopedOverlay
            required property var modelData

            readonly property bool focused: modelData.name === root.focusedScreenName
            readonly property bool interactive: GlobalStates.overlayOpen && focused
            active: interactive || OverlayContext.hasPinnedWidgetsOnScreen(modelData.name)

            component: PanelWindow {
                id: overlayWindow
                screen: scopedOverlay.modelData
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.namespace: "quickshell:overlay"
                WlrLayershell.layer: WlrLayer.Overlay
                // Use OnDemand for pinned widgets to allow focus switching with mouse clicks
                WlrLayershell.keyboardFocus: scopedOverlay.interactive
                    ? WlrKeyboardFocus.Exclusive
                    : (OverlayContext.clickableWidgets.some(widget =>
                        widget.QsWindow?.window?.screen?.name === scopedOverlay.modelData.name)
                        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)
                visible: true
                color: "transparent"

                mask: Region {
                    item: scopedOverlay.interactive ? overlayContent : null
                    regions: OverlayContext.clickableWidgets
                        .filter(widget => widget.QsWindow?.window?.screen?.name === scopedOverlay.modelData.name)
                        .map(widget => root.regionComponent.createObject(this, {
                            item: widget
                        }))
                }

                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }

                HyprlandFocusGrab {
                    id: grab
                    windows: [overlayWindow]
                    active: false
                    onCleared: () => {
                        // Only dismiss the overlay when the grab was cleared by
                        // clicking outside, not when we intentionally release
                        // it because this monitor is no longer interactive.
                        if (scopedOverlay.interactive && !grab.active)
                            GlobalStates.overlayOpen = false;
                    }
                }

                Connections {
                    target: scopedOverlay
                    function onInteractiveChanged() {
                        if (scopedOverlay.interactive)
                            delayedGrabTimer.restart();
                        else
                            grab.active = false;
                    }
                }

                Timer {
                    id: delayedGrabTimer
                    interval: Appearance.animation.elementMoveFast.duration
                    onTriggered: {
                        grab.active = scopedOverlay.interactive;
                    }
                }

                Component.onCompleted: {
                    if (scopedOverlay.interactive)
                        delayedGrabTimer.restart();
                }

                OverlayContent {
                    id: overlayContent
                    anchors.fill: parent
                    screenName: scopedOverlay.modelData.name
                    interactive: scopedOverlay.interactive
                }
            }
        }
    }

    IpcHandler {
        target: "overlay"

        function toggle(): void {
            GlobalStates.overlayOpen = !GlobalStates.overlayOpen;
        }
        function spawnFloatingImage(): void {
            OverlayContext.spawnFloatingImage("", root.focusedScreenName);
        }
        function closeFloatingImages(): void {
            OverlayContext.closeAllFloatingImages();
        }
    }

    GlobalShortcut {
        name: "overlayToggle"
        description: "Toggles overlay on press"

        onPressed: {
            GlobalStates.overlayOpen = !GlobalStates.overlayOpen;
        }
    }
}
