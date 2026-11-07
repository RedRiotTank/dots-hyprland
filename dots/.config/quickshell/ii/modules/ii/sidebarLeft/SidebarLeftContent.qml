import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Qt.labs.synchronizer

Item {
    id: root
    required property var scopeRoot
    property int sidebarPadding: 10
    anchors.fill: parent
    property bool editMode: false
    property string selectedTabKey: ""

    property var tabDefinitions: [
        {
            key: "ai",
            icon: "neurology",
            name: Translation.tr("AI Chat"),
            component: aiChat,
            available: Config.options.policies.ai !== 0,
        },
        {
            key: "translator",
            icon: "translate",
            name: Translation.tr("Translator"),
            component: translator,
            available: Config.options.sidebar.translator.enable,
        },
        {
            key: "anime",
            icon: "bookmark_heart",
            name: Translation.tr("Anime"),
            component: anime,
            available: Config.options.policies.weeb !== 0 && Config.options.policies.weeb !== 2,
        },
        {
            key: "social",
            icon: "dynamic_feed",
            iconSource: "reddit.svg",
            name: Translation.tr("Reddit"),
            component: socialFeed,
            available: true,
        },
        {
            key: "lyrics",
            icon: "lyrics",
            name: Translation.tr("Lyrics"),
            component: lyrics,
            available: true,
        }
    ]

    readonly property var visibleTabs: root.tabDefinitions.filter(tab => tab.available && root.tabVisible(tab.key))
    property var tabButtonList: root.visibleTabs.map(tab => ({
        icon: tab.icon,
        iconSource: tab.iconSource ?? "",
        name: tab.name,
        pageIndex: root.tabDefinitions.indexOf(tab),
    }))
    property int tabCount: root.visibleTabs.length

    // The pages are created once and kept alive. The visible tab bar maps its
    // own compact index to the page index in this fixed list.
    property var pageItems: [
        aiChat.createObject(),
        translator.createObject(),
        anime.createObject(),
        socialFeed.createObject(),
        lyrics.createObject(),
    ]

    function tabVisible(key) {
        const state = Persistent.states.sidebar.leftPanel;
        if (!state) return true;
        return state[key] !== false;
    }

    function setTabVisible(key, value) {
        const state = Persistent.states.sidebar.leftPanel;
        if (state) state[key] = value;
    }

    function focusActiveItem() {
        if (swipeView.currentItem) swipeView.currentItem.forceActiveFocus();
    }

    function ensureSelectedTabIsValid() {
        if (root.visibleTabs.length === 0) {
            root.selectedTabKey = "";
            return;
        }

        Qt.callLater(() => {
            let index = root.visibleTabs.findIndex(tab => tab.key === root.selectedTabKey);
            if (index < 0) index = Math.min(tabBar.currentIndex, root.visibleTabs.length - 1);
            if (index < 0) index = 0;
            tabBar.currentIndex = index;
            root.selectedTabKey = root.visibleTabs[index].key;
        });
    }

    onVisibleTabsChanged: ensureSelectedTabIsValid()

    Connections {
        target: tabBar
        function onCurrentIndexChanged() {
            const tab = root.visibleTabs[tabBar.currentIndex];
            if (!tab) return;
            root.selectedTabKey = tab.key;
            const pageIndex = root.tabDefinitions.indexOf(tab);
            if (pageIndex >= 0) swipeView.currentIndex = pageIndex;
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape && root.editMode) {
            root.editMode = false;
            event.accepted = true;
            return;
        }
        if (event.modifiers === Qt.ControlModifier) {
            if (event.key === Qt.Key_PageDown) {
                swipeView.incrementCurrentIndex()
                event.accepted = true;
            }
            else if (event.key === Qt.Key_PageUp) {
                swipeView.decrementCurrentIndex()
                event.accepted = true;
            }
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: sidebarPadding
        }
        spacing: sidebarPadding

        Toolbar {
            Layout.alignment: Qt.AlignHCenter
            enableShadow: false

            ToolbarTabBar {
                id: tabBar
                visible: !root.editMode
                Layout.alignment: Qt.AlignHCenter
                tabButtonList: root.tabButtonList
                currentIndex: 0

                delegate: ToolbarTabButton {
                    required property int index
                    required property var modelData

                    current: index == tabBar.currentIndex
                    text: current ? modelData.name : ""
                    materialSymbol: modelData.icon
                    iconSource: modelData.iconSource ?? ""
                    horizontalPadding: 10
                    onClicked: tabBar.setCurrentIndex(index)

                    StyledToolTip {
                        text: modelData.name
                    }
                }
            }

            IconToolbarButton {
                id: editButton
                implicitHeight: 40
                text: root.editMode ? "close" : "edit"
                toggled: root.editMode
                onClicked: root.editMode = !root.editMode

                StyledToolTip {
                    text: root.editMode
                        ? Translation.tr("Close tab settings")
                        : Translation.tr("Customize sidebar tabs")
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitWidth: swipeView.implicitWidth
            implicitHeight: swipeView.implicitHeight
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1
            clip: true

            SwipeView { // Content pages
                id: swipeView
                anchors.fill: parent
                spacing: 10
                visible: !root.editMode && root.visibleTabs.length > 0
                interactive: false

                clip: true
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: swipeView.width
                        height: swipeView.height
                        radius: Appearance.rounding.small
                    }
                }

                contentChildren: root.pageItems
            }

            PagePlaceholder {
                shown: root.visibleTabs.length === 0 && !root.editMode
                icon: "tab"
                title: Translation.tr("No tabs are visible")
                description: Translation.tr("Use the pencil button to enable some tabs")
                shape: MaterialShape.Shape.Cookie4Sided
            }

            Item { // Tab visibility settings
                id: editPanel
                anchors.fill: parent
                visible: root.editMode

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 14
                    }
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        MaterialSymbol {
                            text: "edit"
                            iconSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colOnSurface
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Customize sidebar")
                            color: Appearance.colors.colOnSurface
                            font {
                                weight: Font.Medium
                                pixelSize: Appearance.font.pixelSize.larger
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Choose which tabs are visible. Your choices are saved automatically.")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                        wrapMode: Text.WordWrap
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: root.tabDefinitions

                            delegate: RippleButton {
                                id: tabSettingRow
                                required property var modelData

                                Layout.fillWidth: true
                                implicitHeight: tabSettingLayout.implicitHeight + 16
                                buttonRadius: Appearance.rounding.small
                                colBackground: Appearance.colors.colLayer2
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                enabled: tabSettingRow.modelData.available

                                onClicked: {
                                    root.setTabVisible(
                                        tabSettingRow.modelData.key,
                                        !root.tabVisible(tabSettingRow.modelData.key)
                                    );
                                }

                                contentItem: RowLayout {
                                    id: tabSettingLayout
                                    anchors {
                                        fill: parent
                                        margins: 8
                                    }
                                    spacing: 10

                                    CustomIcon {
                                        visible: (tabSettingRow.modelData.iconSource ?? "").length > 0
                                        source: tabSettingRow.modelData.iconSource ?? ""
                                        width: 24
                                        height: 24
                                    }

                                    MaterialSymbol {
                                        visible: (tabSettingRow.modelData.iconSource ?? "").length === 0
                                        text: tabSettingRow.modelData.icon
                                        iconSize: Appearance.font.pixelSize.large
                                        color: tabSettingRow.modelData.available
                                            ? Appearance.colors.colOnSurface
                                            : Appearance.colors.colSubtext
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: tabSettingRow.modelData.name
                                            color: Appearance.colors.colOnSurface
                                            font {
                                                weight: Font.Medium
                                                pixelSize: Appearance.font.pixelSize.normal
                                            }
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: tabSettingRow.modelData.available
                                                ? Translation.tr("Show this tab")
                                                : Translation.tr("Unavailable until enabled in settings")
                                            color: Appearance.colors.colSubtext
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            wrapMode: Text.WordWrap
                                        }
                                    }

                                    StyledSwitch {
                                        checked: root.tabVisible(tabSettingRow.modelData.key)
                                        enabled: false
                                        opacity: 1
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Tip: you can also use the pencil button to close this panel.")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    Component {
        id: aiChat
        AiChat {}
    }
    Component {
        id: translator
        Translator {}
    }
    Component {
        id: anime
        Anime {}
    }
    Component {
        id: socialFeed
        SocialFeed {}
    }
    Component {
        id: lyrics
        Lyrics {}
    }
}
