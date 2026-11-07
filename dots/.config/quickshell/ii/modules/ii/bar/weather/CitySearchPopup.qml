import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: root
    property Item anchorItem
    property bool open: false
    readonly property int popupWidth: 440
    property list<var> results: []
    property int selectedIndex: 0
    property bool searching: false

    function toggle() {
        root.open = !root.open;
    }

    function close() {
        root.open = false;
    }

    function searchFor(text) {
        const query = text.trim();
        if (query.length < 2) {
            root.results = [];
            root.searching = false;
            return;
        }

        root.searching = true;
        geocodeProc.command = ["bash", "-c",
            `curl -sS --max-time 8 "https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(query)}&count=8&language=es&format=json"`
        ];
        geocodeProc.running = false;
        geocodeProc.running = true;
    }

    function choose(index) {
        if (index < 0 || index >= root.results.length) return;
        const result = root.results[index];
        Config.options.bar.weather.latitude = result.latitude;
        Config.options.bar.weather.longitude = result.longitude;
        Config.options.bar.weather.enableGPS = false;
        Config.options.bar.weather.city = `${result.name}, ${result.country}`;
        Weather.getData();
        root.close();
    }

    onOpenChanged: {
        if (root.open) {
            searchField.text = "";
            root.results = [];
            root.selectedIndex = 0;
            GlobalFocusGrab.addDismissable(popupWindow);
            Qt.callLater(() => searchField.forceActiveFocus());
        } else {
            GlobalFocusGrab.removeDismissable(popupWindow);
        }
    }

    Timer {
        id: debounce
        interval: 280
        repeat: false
        onTriggered: root.searchFor(searchField.text)
    }

    Process {
        id: geocodeProc
        running: false
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                root.searching = false;
                try {
                    const parsed = JSON.parse(text);
                    root.results = parsed.results ?? [];
                } catch (error) {
                    root.results = [];
                }
                root.selectedIndex = 0;
            }
        }
    }

    PanelWindow {
        id: popupWindow
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:weatherCitySearch"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors.left: true
        anchors.top: !Config.options.bar.bottom
        anchors.bottom: Config.options.bar.bottom

        implicitWidth: popupBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
        implicitHeight: popupBackground.implicitHeight + Appearance.sizes.elevationMargin * 2

        margins {
            left: {
                if (!root.open) return 0;
                const barWindow = root.anchorItem?.QsWindow;
                if (!barWindow) return 8;
                const mapped = barWindow.mapFromItem(
                    root.anchorItem,
                    (root.anchorItem.width - popupBackground.implicitWidth) / 2,
                    0
                ).x;
                const screenWidth = barWindow.screen?.width ?? 1920;
                return Math.max(8, Math.min(screenWidth - popupBackground.implicitWidth - 8, mapped));
            }
            top: Config.options.bar.bottom ? 0 : Appearance.sizes.barHeight
            bottom: Config.options.bar.bottom ? Appearance.sizes.barHeight : 0
        }

        mask: Region {
            item: popupBackground
        }

        StyledRectangularShadow {
            target: popupBackground
        }

        Rectangle {
            id: popupBackground
            anchors {
                fill: parent
                margins: Appearance.sizes.elevationMargin
            }
            implicitWidth: root.popupWidth
            implicitHeight: contentColumn.implicitHeight + 24
            color: Appearance.m3colors.m3surfaceContainer
            radius: Appearance.rounding.normal
            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            ColumnLayout {
                id: contentColumn
                anchors {
                    fill: parent
                    margins: 12
                }
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialSymbol {
                        text: "location_on"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnSurfaceVariant
                    }

                    StyledText {
                        text: Translation.tr("Change city")
                        font {
                            weight: Font.Medium
                            pixelSize: Appearance.font.pixelSize.normal
                        }
                        color: Appearance.colors.colOnSurface
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                ToolbarTextField {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    Layout.fillHeight: false
                    placeholderText: Translation.tr("Search city...")

                    onTextChanged: {
                        root.selectedIndex = 0;
                        debounce.restart();
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down) {
                            if (root.results.length > 0)
                                root.selectedIndex = Math.min(root.selectedIndex + 1, root.results.length - 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            root.selectedIndex = Math.max(root.selectedIndex - 1, 0);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.choose(root.selectedIndex);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            root.close();
                            event.accepted = true;
                        }
                    }
                }

                StyledText {
                    visible: root.searching
                    text: Translation.tr("Searching...")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                }

                ListView {
                    id: resultsList
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? Math.min(300, contentHeight) : 0
                    visible: root.results.length > 0
                    clip: true
                    spacing: 2
                    model: root.results

                    delegate: RippleButton {
                        id: resultButton
                        required property var modelData
                        required property int index

                        width: resultsList.width
                        implicitHeight: 52
                        buttonRadius: Appearance.rounding.small
                        colBackground: index === root.selectedIndex
                            ? Appearance.colors.colSecondaryContainer
                            : "transparent"
                        colBackgroundHover: Appearance.colors.colLayer1Hover
                        onClicked: root.choose(index)

                        contentItem: RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            MaterialSymbol {
                                text: "location_on"
                                iconSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnSurfaceVariant
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: resultButton.modelData.name
                                    color: Appearance.colors.colOnSurface
                                    font {
                                        weight: Font.Medium
                                        pixelSize: Appearance.font.pixelSize.normal
                                    }
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: `${resultButton.modelData.admin1 ? resultButton.modelData.admin1 + ", " : ""}${resultButton.modelData.country}`
                                    color: Appearance.colors.colSubtext
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                StyledText {
                    visible: !root.searching && root.results.length === 0
                        && searchField.text.trim().length >= 2
                    text: Translation.tr("No results")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                if (root.open) root.close();
            }
        }
    }
}
