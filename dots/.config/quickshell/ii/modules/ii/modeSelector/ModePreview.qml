import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
    id: root
    property var profile: null
    property bool compact: false
    property real radius: Appearance.rounding.normal

    implicitHeight: root.compact ? 76 : 240

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Appearance.colors.colLayer1
    }

    StyledImage {
        id: wallpaperPreview
        anchors.fill: parent
        source: root.profile?.wallpaper ?? ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: wallpaperPreview.width
                height: wallpaperPreview.height
                radius: root.radius
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "#00000022"
    }

    // Mock top bar
    Rectangle {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: root.compact ? 18 : 30
        color: "#00000066"
        radius: root.radius

        RowLayout {
            anchors {
                fill: parent
                leftMargin: root.compact ? 5 : 10
                rightMargin: root.compact ? 5 : 10
            }
            spacing: root.compact ? 3 : 6

            StyledText {
                Layout.fillWidth: true
                text: root.profile?.name ?? "Mode"
                color: "white"
                font {
                    pixelSize: root.compact ? Appearance.font.pixelSize.smaller : Appearance.font.pixelSize.small
                    weight: Font.Medium
                }
                elide: Text.ElideRight
            }

            MaterialSymbol {
                visible: root.profile?.tabs?.ai !== false
                text: "neurology"
                iconSize: root.compact ? 11 : 16
                color: "white"
            }
            MaterialSymbol {
                visible: root.profile?.tabs?.translator !== false
                text: "translate"
                iconSize: root.compact ? 11 : 16
                color: "white"
            }
            MaterialSymbol {
                visible: root.profile?.tabs?.anime !== false
                text: "bookmark_heart"
                iconSize: root.compact ? 11 : 16
                color: "white"
            }
            CustomIcon {
                visible: root.profile?.tabs?.social !== false
                source: "reddit.svg"
                width: root.compact ? 11 : 16
                height: root.compact ? 11 : 16
            }
            MaterialSymbol {
                visible: root.profile?.tabs?.lyrics !== false
                text: "lyrics"
                iconSize: root.compact ? 11 : 16
                color: "white"
            }
        }
    }

    // Mock terminal
    Rectangle {
        visible: !root.compact
        anchors {
            left: parent.left
            bottom: parent.bottom
            margins: 12
        }
        width: 140
        height: 64
        radius: Appearance.rounding.small
        color: "#00000099"
        border.width: 1
        border.color: "#ffffff33"

        ColumnLayout {
            anchors {
                fill: parent
                margins: 8
            }
            spacing: 2

            RowLayout {
                MaterialSymbol {
                    text: "terminal"
                    iconSize: 12
                    color: "white"
                }
                StyledText {
                    text: "Terminal"
                    color: "white"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }
            StyledText {
                text: root.profile?.terminal === "pokemon" ? "pokemon-colorscripts" : "fastfetch CachyOS"
                color: "#dddddd"
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }
    }

    // Mock floating image indicator
    Rectangle {
        visible: root.profile?.floatingImages === true
        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: root.compact ? 5 : 12
        }
        width: root.compact ? 48 : 90
        height: root.compact ? 18 : 26
        radius: Appearance.rounding.full
        color: "#00000099"

        RowLayout {
            anchors.centerIn: parent
            spacing: 4

            MaterialSymbol {
                text: "imagesmode"
                iconSize: root.compact ? 11 : 14
                color: "white"
            }
            StyledText {
                visible: !root.compact
                text: "Floating"
                color: "white"
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }
    }

    // Mock desktop window
    Rectangle {
        visible: !root.compact
        anchors.centerIn: parent
        width: parent.width * 0.48
        height: parent.height * 0.32
        radius: Appearance.rounding.small
        color: "#00000055"
        border.width: 1
        border.color: "#ffffff22"

        StyledText {
            anchors.centerIn: parent
            text: "Desktop preview"
            color: "#ffffffcc"
            font.pixelSize: Appearance.font.pixelSize.small
        }
    }
}
