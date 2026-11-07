import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.ii.sidebarLeft.social
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    property real padding: 4
    property string subreddit: Persistent.states.sidebar.social.subreddit || "unixporn"
    property var posts: []
    property bool loading: false
    property string errorText: ""
    property bool showingCache: false

    readonly property string helperPath: `${FileUtils.trimFileProtocol(Directories.scriptPath)}/social/reddit_rss.py`

    function normalizeSubreddit(value) {
        let result = value.trim();
        result = result.replace(/^r\//i, "");
        result = result.replace(/^\/+|\/+$/g, "");
        return result.replace(/[^A-Za-z0-9_]/g, "");
    }

    function refresh() {
        const normalized = root.normalizeSubreddit(subredditField.text.length > 0 ? subredditField.text : root.subreddit);
        if (normalized.length === 0) return;

        root.subreddit = normalized;
        Persistent.states.sidebar.social.subreddit = normalized;
        root.loading = true;
        root.errorText = "";

        fetchProcess.running = false;
        fetchProcess.command = ["python3", root.helperPath, normalized];
        fetchProcess.running = true;
    }

    Component.onCompleted: refresh()

    Process {
        id: fetchProcess
        running: false
        command: ["python3", root.helperPath, root.subreddit]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    const parsed = JSON.parse(text);
                    root.posts = parsed.posts ?? [];
                    root.errorText = parsed.error ?? "";
                    root.showingCache = parsed.cached ?? false;
                } catch (error) {
                    root.posts = [];
                    root.errorText = Translation.tr("Could not parse the Reddit feed");
                    root.showingCache = false;
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.loading = false;
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: root.padding

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: 40
            Layout.maximumHeight: 40
            spacing: 6

            MaterialSymbol {
                text: "dynamic_feed"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnLayer1
            }

            ToolbarTextField {
                id: subredditField
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                Layout.fillHeight: false
                text: root.subreddit
                placeholderText: Translation.tr("Subreddit")
                onAccepted: root.refresh()
            }

            IconToolbarButton {
                implicitHeight: 36
                text: "refresh"
                onClicked: root.refresh()
                StyledToolTip {
                    text: Translation.tr("Refresh Reddit feed")
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StyledListView {
                id: feedList
                anchors.fill: parent
                visible: root.posts.length > 0
                spacing: 6
                model: root.posts
                delegate: SocialPostItem {
                    required property var modelData
                    post: modelData
                }
            }

            PagePlaceholder {
                shown: root.posts.length === 0 && !root.loading
                icon: "dynamic_feed"
                title: root.errorText.length > 0
                    ? Translation.tr("Could not load the feed")
                    : Translation.tr("Social feed")
                description: root.errorText.length > 0
                    ? root.errorText
                    : Translation.tr("Refresh to load posts from Reddit")
                shape: MaterialShape.Shape.Cookie4Sided
            }

            MaterialLoadingIndicator {
                anchors.centerIn: parent
                loading: root.loading
                visible: root.loading
            }
        }

        StyledText {
            visible: root.showingCache
            Layout.fillWidth: true
            text: Translation.tr("Reddit is rate limiting requests. Showing the last cached feed.")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
            wrapMode: Text.WordWrap
        }
    }
}
