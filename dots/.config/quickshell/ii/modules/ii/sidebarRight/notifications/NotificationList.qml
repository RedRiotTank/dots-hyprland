import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    readonly property var activeProfile: ProfileManager.activeProfile
    readonly property bool artEnabled: activeProfile?.notificationImageEnabled !== false
    readonly property string artPath: activeProfile?.notificationImage ?? ""
    readonly property real artAvailableHeight: Math.max(0, listview.height - listview.contentHeight)
    readonly property real artMaxWidth: Math.max(0, listview.width - 20)
    readonly property real artMaxHeight: Math.max(0, artAvailableHeight - 10)
    readonly property bool artReady: notificationArt.status === Image.Ready
    readonly property bool showArt: artEnabled
        && artPath.length > 0
        && artMaxWidth > 40
        && artMaxHeight > 80
        && artReady
    readonly property real artScale: {
        if (notificationArt.implicitWidth <= 0 || notificationArt.implicitHeight <= 0) return 0;
        return Math.min(artMaxWidth / notificationArt.implicitWidth,
                        artMaxHeight / notificationArt.implicitHeight);
    }

    Item { // Decorative art in the space the list leaves free.
        id: artContainer
        anchors {
            left: parent.left
            right: parent.right
            bottom: statusRow.top
            bottomMargin: 8
        }
        height: root.artMaxHeight
        visible: root.showArt
        z: 0

        AnimatedImage {
            id: notificationArt
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            source: root.artPath.length > 0 ? Qt.resolvedUrl(root.artPath) : ""
            width: Math.max(1, implicitWidth * root.artScale)
            height: Math.max(1, implicitHeight * root.artScale)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
            playing: visible
            smooth: true
        }
    }

    NotificationListView { // Scrollable window
        z: 1
        id: listview
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: statusRow.top
        anchors.bottomMargin: 5

        clip: true
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: listview.width
                height: listview.height
                radius: Appearance.rounding.normal
            }
        }

        popup: false
    }

    // Placeholder when list is empty
    PagePlaceholder {
        shown: Notifications.list.length === 0 && !root.showArt
        icon: "notifications_active"
        description: Translation.tr("Nothing")
        shape: MaterialShape.Shape.Ghostish
        descriptionHorizontalAlignment: Text.AlignHCenter
    }

    ButtonGroup {
        id: statusRow
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        NotificationStatusButton {
            Layout.fillWidth: false
            buttonIcon: "notifications_paused"
            toggled: Notifications.silent
            onClicked: () => {
                Notifications.silent = !Notifications.silent;
            }
        }
        NotificationStatusButton {
            enabled: false
            Layout.fillWidth: true
            buttonText: Translation.tr("%1 notifications").arg(Notifications.list.length)
        }
        NotificationStatusButton {
            Layout.fillWidth: false
            buttonIcon: "delete_sweep"
            onClicked: () => {
                Notifications.discardAllNotifications()
            }
        }
    }
}