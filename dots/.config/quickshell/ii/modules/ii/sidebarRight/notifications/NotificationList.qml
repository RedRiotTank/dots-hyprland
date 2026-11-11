import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Qt5Compat.GraphicalEffects
import QtMultimedia
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    readonly property var activeProfile: ProfileManager.activeProfile
    readonly property bool artEnabled: activeProfile?.notificationImageEnabled !== false
    readonly property string artPath: activeProfile?.notificationImage ?? ""
    readonly property bool artIsVideo: /\.(mp4|webm|mov|mkv|m4v)$/i.test(artPath)
    readonly property bool artVisible: showArt && GlobalStates.sidebarRightOpen
    readonly property real artAvailableHeight: Math.max(0, listview.height - listview.contentHeight)
    readonly property real artMaxWidth: Math.max(0, listview.width - 20)
    readonly property real artMaxHeight: Math.max(0, artAvailableHeight - 10)
    readonly property bool artReady: artIsVideo
        ? (videoPlayer.hasVideo
            && videoPlayer.mediaStatus !== MediaPlayer.LoadingMedia
            && videoPlayer.mediaStatus !== MediaPlayer.NoMedia
            && videoPlayer.mediaStatus !== MediaPlayer.InvalidMedia)
        : notificationArt.status === Image.Ready
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
            visible: !root.artIsVideo
            source: !root.artIsVideo && root.artPath.length > 0 ? Qt.resolvedUrl(root.artPath) : ""
            width: Math.max(1, implicitWidth * root.artScale)
            height: Math.max(1, implicitHeight * root.artScale)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
            playing: root.artVisible && visible
            smooth: true
        }

        Item { // Green-screen video, with optional chroma key.
            id: videoArt
            anchors.fill: parent
            visible: root.artIsVideo

            VideoOutput {
                id: videoOutput
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectCrop
                // Kept out of the scene: ShaderEffectSource takes its frames.
                visible: false
            }

            ShaderEffectSource {
                id: videoSource
                anchors.fill: parent
                sourceItem: videoOutput
                live: true
                hideSource: true
                recursive: false
            }

            ShaderEffect {
                anchors.fill: parent
                property variant source: videoSource
                property real chroma: root.activeProfile?.notificationChromaKey === false ? 0.0 : 1.0
                property real panelR: Appearance.colors.colLayer1.r
                property real panelG: Appearance.colors.colLayer1.g
                property real panelB: Appearance.colors.colLayer1.b
                fragmentShader: Qt.resolvedUrl("chroma-key.frag.qsb")
            }
        }
    }

    MediaPlayer {
        id: videoPlayer
        source: root.artIsVideo ? Qt.resolvedUrl(root.artPath) : ""
        loops: MediaPlayer.Infinite
        videoOutput: videoOutput
        audioOutput: AudioOutput {
            muted: true
            volume: 0
        }
        onHasVideoChanged: if (root.artVisible && hasVideo) play()
    }

    Connections {
        target: root
        function onArtVisibleChanged() {
            if (root.artVisible && videoPlayer.hasVideo) videoPlayer.play();
            else videoPlayer.pause();
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