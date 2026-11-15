import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * Compact now-playing card for the lock screen.
 * Shows the current cover, title, artist and playback controls while media is
 * available. It stays visible when paused so playback can be resumed without
 * leaving the lock screen.
 */
Item {
    id: root

    property var player: MprisController.activePlayer
    property var track: MprisController.activeTrack
    readonly property bool hasMedia: root.player !== null
        && root.player !== undefined
        && (root.track?.title?.length ?? 0) > 0
    readonly property bool playing: root.player?.isPlaying ?? false
    readonly property string title: StringUtils.cleanMusicTitle(root.track?.title ?? "")
        || (root.track?.title ?? "")
    readonly property string artist: root.track?.artist ?? ""
    readonly property string album: root.track?.album ?? ""
    readonly property string artSource: {
        const url = root.track?.artUrl ?? "";
        if (url.length === 0)
            return "";
        if (url.startsWith("file://") || url.startsWith("http://") || url.startsWith("https://"))
            return url;
        if (url.startsWith("/"))
            return Qt.resolvedUrl(url);
        return url;
    }
    readonly property real trackLength: root.player?.length ?? 0
    property real trackPosition: 0
    readonly property real progress: root.trackLength > 0
        ? Math.max(0, Math.min(1, root.trackPosition / root.trackLength))
        : 0

    visible: opacity > 0
    opacity: root.hasMedia ? 1 : 0
    implicitHeight: 88

    Behavior on opacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    function refreshPosition() {
        root.trackPosition = root.player?.position ?? 0;
    }

    onPlayerChanged: refreshPosition()
    Component.onCompleted: refreshPosition()

    Connections {
        target: root.player
        function onPositionChanged() {
            root.refreshPosition();
        }
        function onLengthChanged() {
            root.refreshPosition();
        }
    }

    // MPRIS position does not always notify while playing, so poll it lightly.
    Timer {
        running: root.playing && root.visible
        interval: 1000
        repeat: true
        onTriggered: root.refreshPosition()
    }

    component MediaControlButton: RippleButton {
        id: button
        required property string iconName
        property bool primary: false

        implicitWidth: primary ? 42 : 34
        implicitHeight: primary ? 42 : 34
        buttonRadius: height / 2
        pointingHandCursor: true

        colBackground: primary
            ? Appearance.colors.colPrimary
            : ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
        colBackgroundHover: primary
            ? Appearance.colors.colPrimaryHover
            : Appearance.colors.colLayer2Hover
        colBackgroundToggled: primary
            ? Appearance.colors.colPrimary
            : Appearance.colors.colLayer2
        colRipple: primary
            ? Appearance.colors.colPrimaryActive
            : Appearance.colors.colLayer2Active

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            iconSize: button.primary ? Appearance.font.pixelSize.huge : Appearance.font.pixelSize.larger
            fill: 1
            text: button.iconName
            color: button.primary
                ? Appearance.colors.colOnPrimary
                : Appearance.colors.colOnLayer2
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: Appearance.colors.colSurfaceContainer
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        RowLayout {
            anchors {
                fill: parent
                margins: 10
            }
            spacing: 12

            // Cover art
            Rectangle {
                id: artBackground
                Layout.preferredWidth: 64
                Layout.preferredHeight: 64
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: artBackground.width
                        height: artBackground.height
                        radius: artBackground.radius
                    }
                }

                StyledImage {
                    id: coverArt
                    anchors.fill: parent
                    source: root.artSource
                    fillMode: Image.PreserveAspectCrop
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: coverArt.status !== Image.Ready
                    text: "music_note"
                    iconSize: Appearance.font.pixelSize.hugeass
                    color: Appearance.colors.colOnLayer2
                }
            }

            // Track information
            ColumnLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: 210
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: root.title
                    color: Appearance.colors.colOnSurface
                    font.pixelSize: Appearance.font.pixelSize.small
                    elide: Text.ElideRight
                    animateChange: true
                    animationDistanceY: 4
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.artist || root.album
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideRight
                    animateChange: true
                    animationDistanceY: 4
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 12

                    StyledProgressBar {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        valueBarHeight: 3
                        valueBarWidth: 100
                        value: root.progress
                        wavy: root.playing
                        highlightColor: Appearance.colors.colPrimary
                        trackColor: Appearance.colors.colSecondaryContainer
                    }
                }
            }

            // Playback controls
            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                MediaControlButton {
                    iconName: "skip_previous"
                    enabled: root.player?.canGoPrevious ?? false
                    onClicked: MprisController.previous()
                }

                MediaControlButton {
                    primary: true
                    iconName: root.playing ? "pause" : "play_arrow"
                    enabled: root.player?.canTogglePlaying ?? false
                    onClicked: MprisController.togglePlaying()
                }

                MediaControlButton {
                    iconName: "skip_next"
                    enabled: root.player?.canGoNext ?? false
                    onClicked: MprisController.next()
                }
            }
        }
    }
}
