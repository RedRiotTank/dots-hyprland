import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    property real padding: 4

    property string trackTitle: ""
    property string trackArtist: ""
    property string trackAlbum: ""
    property string status: "idle" // idle, loading, synced, plain, none, error
    property string errorText: ""
    property var lines: []
    property bool usingSynced: false
    property int activeLine: -1
    property real currentPosition: 0

    readonly property string helperPath: `${FileUtils.trimFileProtocol(Directories.scriptPath)}/lyrics/lrclib.py`

    function parseLrc(lrc) {
        const result = [];
        const timeRegex = /\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]/g;
        for (const rawLine of lrc.split(/\r?\n/)) {
            const text = rawLine.replace(/\[[^\]]*\]/g, "").trim();
            if (text.length === 0) continue;

            let match;
            timeRegex.lastIndex = 0;
            while ((match = timeRegex.exec(rawLine)) !== null) {
                const minutes = parseInt(match[1], 10);
                const seconds = parseInt(match[2], 10);
                const fractionText = (match[3] ?? "0").padEnd(3, "0").slice(0, 3);
                const fraction = parseInt(fractionText, 10) / 1000;
                result.push({
                    time: minutes * 60 + seconds + fraction,
                    text: text,
                });
            }
        }
        result.sort((a, b) => a.time - b.time);
        return result;
    }

    function updateActiveLine() {
        if (!root.usingSynced || root.lines.length === 0) return;
        let index = -1;
        for (let i = 0; i < root.lines.length; ++i) {
            if (root.lines[i].time <= root.currentPosition) index = i;
            else break;
        }
        if (index !== root.activeLine) {
            root.activeLine = index;
        }
    }

    function reload() {
        const track = MprisController.activeTrack;
        if (!track || !track.title || track.title === Translation.tr("Unknown Title")
            || track.artist === Translation.tr("Unknown Artist")) {
            root.trackTitle = "";
            root.trackArtist = "";
            root.trackAlbum = "";
            root.status = "idle";
            root.lines = [];
            return;
        }

        root.trackTitle = track.title;
        root.trackArtist = track.artist;
        root.trackAlbum = track.album;
        root.status = "loading";
        root.errorText = "";
        root.lines = [];
        root.activeLine = -1;

        const player = MprisController.activePlayer;
        const duration = String(player?.length ?? 0);

        lyricsProcess.running = false;
        lyricsProcess.command = [
            "python3", root.helperPath,
            track.artist ?? "",
            track.title ?? "",
            track.album ?? "",
            duration,
        ];
        lyricsProcess.running = true;
    }

    function applyLyrics(data) {
        if (data?.syncedLyrics) {
            root.lines = root.parseLrc(data.syncedLyrics);
            root.usingSynced = true;
            root.status = "synced";
            root.updateActiveLine();
        } else if (data?.plainLyrics) {
            root.lines = data.plainLyrics.split(/\r?\n/).map(line => ({ time: -1, text: line }));
            root.usingSynced = false;
            root.status = "plain";
            root.activeLine = -1;
        } else {
            root.lines = [];
            root.usingSynced = false;
            root.status = data?.error ? "error" : "none";
            root.errorText = data?.error ?? "";
        }
    }

    Component.onCompleted: reload()

    Connections {
        target: MprisController
        function onTrackChanged() {
            root.reload();
        }
        function onActivePlayerChanged() {
            root.reload();
        }
    }

    Process {
        id: lyricsProcess
        running: false
        command: ["python3", root.helperPath, "", "", "", "0"]
        stdout: StdioCollector {
            onStreamFinished: {
                let data = null;
                try {
                    data = JSON.parse(text);
                } catch (error) {
                    data = { error: Translation.tr("Could not parse the lyrics response") };
                }
                root.applyLyrics(data);
            }
        }
    }

    Timer {
        id: positionTimer
        interval: 500
        repeat: true
        running: root.usingSynced && root.status === "synced" && MprisController.isPlaying
        onTriggered: {
            const player = MprisController.activePlayer;
            if (!player) return;
            player.positionChanged();
            root.currentPosition = player.position ?? 0;
            root.updateActiveLine();
        }
    }

    onActiveLineChanged: {
        if (root.usingSynced && root.activeLine >= 0 && typeof lyricList !== "undefined") {
            lyricList.positionViewAtIndex(root.activeLine, ListView.Center);
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: root.padding

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: headerLayout.implicitHeight + 16
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1

            RowLayout {
                id: headerLayout
                anchors {
                    fill: parent
                    margins: 8
                }
                spacing: 8

                MaterialSymbol {
                    text: "lyrics"
                    iconSize: Appearance.font.pixelSize.large
                    color: root.status === "synced" ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: root.trackTitle.length > 0 ? root.trackTitle : Translation.tr("No music playing")
                        color: Appearance.colors.colOnSurface
                        font {
                            weight: Font.Medium
                            pixelSize: Appearance.font.pixelSize.normal
                        }
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.trackArtist.length > 0
                        text: root.trackArtist
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        elide: Text.ElideRight
                    }
                }

                IconToolbarButton {
                    implicitHeight: 36
                    text: "refresh"
                    onClicked: root.reload()
                    StyledToolTip {
                        text: Translation.tr("Reload lyrics")
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StyledListView {
                id: lyricList
                anchors.fill: parent
                visible: root.status === "synced" || root.status === "plain"
                spacing: 4
                model: root.lines
                delegate: Item {
                    id: lyricLine
                    required property var modelData
                    required property int index

                    width: lyricList.width
                    implicitHeight: lyricText.implicitHeight + 8

                    StyledText {
                        id: lyricText
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 20
                        text: modelData.text
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        color: root.usingSynced && index === root.activeLine
                            ? Appearance.colors.colPrimary
                            : Appearance.colors.colOnLayer1
                        font {
                            pixelSize: root.usingSynced && index === root.activeLine
                                ? Appearance.font.pixelSize.larger
                                : Appearance.font.pixelSize.normal
                            weight: root.usingSynced && index === root.activeLine
                                ? Font.DemiBold
                                : Font.Normal
                        }

                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }
                    }
                }
            }

            PagePlaceholder {
                shown: root.status === "idle"
                icon: "lyrics"
                title: Translation.tr("No music playing")
                description: Translation.tr("Play something to see its lyrics")
                shape: MaterialShape.Shape.Cookie4Sided
            }

            PagePlaceholder {
                shown: root.status === "none" || root.status === "error"
                icon: "lyrics"
                title: Translation.tr("No lyrics found")
                description: root.errorText.length > 0
                    ? root.errorText
                    : Translation.tr("No lyrics were found for this track")
                shape: MaterialShape.Shape.Cookie4Sided
            }

            MaterialLoadingIndicator {
                anchors.centerIn: parent
                loading: root.status === "loading"
                visible: root.status === "loading"
            }
        }
    }
}
