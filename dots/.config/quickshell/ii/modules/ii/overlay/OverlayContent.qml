import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas

Item {
    id: root
    focus: true
    property string screenName: ""
    // True only on the focused monitor while the overlay is open. Pinned-only
    // overlay windows on other monitors render just their pinned widgets.
    property bool interactive: false
    readonly property bool usePasswordChars: !PolkitService.flow?.responseVisible ?? true

    Keys.onPressed: (event) => { // Esc to close
        if (event.key === Qt.Key_Escape && root.interactive) {
            GlobalStates.overlayOpen = false;
        }
    }

    property real initScale: Config.options.overlay.openingZoomAnimation ? 1.08 : 1.000001
    scale: root.interactive ? root.initScale : 1
    Component.onCompleted: {
        scale = 1
    }
    Behavior on scale {
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        color: Appearance.colors.colScrim
        visible: root.interactive && Config.options.overlay.darkenScreen && opacity > 0
        opacity: (root.interactive && root.scale !== root.initScale) ? 1 : 0
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    WidgetCanvas {
        anchors.fill: parent
        onClicked: {
            if (root.interactive)
                GlobalStates.overlayOpen = false;
        }

        OverlayTaskbar {
            visible: root.interactive
            screenName: root.screenName
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
                topMargin: 50
            }
        }

        Repeater {
            model: ScriptModel {
                values: Persistent.states.overlay.open
                    .filter(identifier => {
                        const state = Persistent.states.overlay[identifier];
                        if (!state) return false;
                        if (!root.interactive && state.pinned !== true) return false;
                        return OverlayContext.widgetScreenName(identifier) === root.screenName;
                    })
                    .map(identifier => OverlayContext.definitionFor(identifier))
                    .filter(entry => entry !== null)
                objectProp: "identifier"
            }
            delegate: OverlayWidgetDelegateChooser {
                
            }
        }
    }
}
