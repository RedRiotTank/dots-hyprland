import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root
    required property var post

    width: ListView.view ? ListView.view.width : implicitWidth
    implicitHeight: contentLayout.implicitHeight + 16
    radius: Appearance.rounding.normal
    color: hoverHandler.hovered ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1

    function timeAgo(utc) {
        if (!utc || utc <= 0) return "";
        const seconds = Math.max(0, Math.floor(Date.now() / 1000 - utc));
        if (seconds < 60) return `${seconds}s`;
        const minutes = Math.floor(seconds / 60);
        if (minutes < 60) return `${minutes}m`;
        const hours = Math.floor(minutes / 60);
        if (hours < 24) return `${hours}h`;
        const days = Math.floor(hours / 24);
        if (days < 30) return `${days}d`;
        return `${Math.floor(days / 30)}mo`;
    }

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: {
            if (root.post?.url) Qt.openUrlExternally(root.post.url);
        }
    }

    RowLayout {
        id: contentLayout
        anchors {
            fill: parent
            margins: 8
        }
        spacing: 10

        Item {
            visible: (root.post?.thumbnail ?? "").length > 0
            implicitWidth: 76
            implicitHeight: 56

            Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2
            }

            StyledImage {
                id: thumbnail
                anchors.fill: parent
                source: root.post?.thumbnail ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: thumbnail.width
                        height: thumbnail.height
                        radius: Appearance.rounding.small
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 3

            StyledText {
                Layout.fillWidth: true
                text: root.post?.title ?? ""
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: Appearance.colors.colOnSurface
                font {
                    weight: Font.Medium
                    pixelSize: Appearance.font.pixelSize.normal
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                StyledText {
                    text: root.post?.subreddit ?? ""
                    color: Appearance.colors.colPrimary
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }

                StyledText {
                    text: `u/${root.post?.author ?? ""}`
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideRight
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: root.timeAgo(root.post?.createdUtc ?? 0)
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }
        }
    }
}
