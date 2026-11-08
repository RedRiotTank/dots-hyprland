import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Qt.labs.synchronizer
import Quickshell

Item {
    id: root
    required property var scopeRoot
    property int sidebarPadding: 10
    anchors.fill: parent
    property string selectedTabKey: ""

    property var tabDefinitions: [
        {
            key: "ai",
            icon: "neurology",
            iconSource: "ai-gemini-color.svg",
            name: Translation.tr("AI Chat"),
            component: aiChat,
            available: Config.options.policies.ai !== 0,
        },
        {
            key: "translator",
            icon: "translate",
            iconSource: "translator-color.svg",
            name: Translation.tr("Translator"),
            component: translator,
            available: Config.options.sidebar.translator.enable,
        },
        {
            key: "anime",
            icon: "bookmark_heart",
            iconSource: "anime-color.svg",
            name: Translation.tr("Anime"),
            component: anime,
            available: true,
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
            icon: "music_note",
            iconSource: "music-color.svg",
            name: Translation.tr("Music"),
            component: music,
            available: true,
        }
    ]

    readonly property bool coloredTabIcons: ProfileManager.activeProfile?.coloredIcons ?? true

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
        music.createObject(),
    ]

    function tabVisible(key) {
        return ProfileManager.tabVisible(key);
    }

    function setTabVisible(key, value) {
        ProfileManager.setTabVisible(key, value);
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
                    coloredIcons: root.coloredTabIcons
                    horizontalPadding: 10
                    onClicked: tabBar.setCurrentIndex(index)

                    StyledToolTip {
                        text: modelData.name
                    }
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
                visible: root.visibleTabs.length > 0
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
                shown: root.visibleTabs.length === 0
                icon: "tab"
                title: Translation.tr("No tabs are visible")
                description: Translation.tr("Enable some tabs from Desktop modes")
                shape: MaterialShape.Shape.Cookie4Sided
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
        id: music
        Music {}
    }
}
