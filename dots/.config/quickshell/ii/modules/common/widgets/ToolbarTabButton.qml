import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RippleButton {
    id: root
    required property string materialSymbol
    required property bool current
    property string iconSource: ""
    property bool coloredIcons: true
    horizontalPadding: 10

    implicitHeight: 40
    implicitWidth: implicitContentWidth + horizontalPadding * 2
    buttonRadius: height / 2

    colBackground: ColorUtils.transparentize(Appearance.colors.colSurfaceContainer)
    colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colOnSurface, current ? 1 : 0.95)
    colRipple: ColorUtils.transparentize(Appearance.colors.colOnSurface, 0.95)

    contentItem: Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        CustomIcon {
            id: imageIcon
            visible: root.iconSource.length > 0
            width: visible ? 22 : 0
            height: 22
            source: root.iconSource
            colorize: !root.coloredIcons
            color: Appearance.colors.colOnLayer1
        }
        MaterialSymbol {
            id: icon
            visible: root.iconSource.length === 0
            width: visible ? implicitWidth : 0
            anchors.verticalCenter: parent.verticalCenter
            iconSize: 22
            text: root.materialSymbol
        }
        StyledText {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
        }
    }
}
