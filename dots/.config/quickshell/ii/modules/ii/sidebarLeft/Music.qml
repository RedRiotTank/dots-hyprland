import qs
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
    readonly property string recommendationLauncherPath: `${FileUtils.trimFileProtocol(Directories.scriptPath)}/media/recommendation_launcher.py`
    readonly property var activePlayer: MprisController.activePlayer
    readonly property string artUrl: root.activePlayer?.trackArtUrl ?? ""
    readonly property string artKey: Qt.md5(root.artUrl)
    property string artFilePath: `${Directories.coverArt}/${root.artKey}`
    property string downloadedArtKey: ""
    property string pendingArtUrl: ""
    property string pendingArtKey: ""
    property list<real> visualizerPoints: []
    property var recommendations: []
    property bool recommendationsLoading: false
    property string recommendationsError: ""
    readonly property real trackLength: root.activePlayer?.length ?? 0
    readonly property string elapsedText: StringUtils.friendlyTimeForSeconds(root.currentPosition)
    readonly property string remainingText: "-" + StringUtils.friendlyTimeForSeconds(Math.max(0, root.trackLength - root.currentPosition))
    readonly property string playbackPlatform: {
        const player = root.activePlayer;
        const identity = String(player?.identity ?? "").toLowerCase();
        const desktopEntry = String(player?.desktopEntry ?? "").toLowerCase();
        const dbusName = String(player?.dbusName ?? "").toLowerCase();
        const metadataUrl = String((player?.metadata ?? {})["xesam:url"] ?? "").toLowerCase();
        const description = `${identity} ${desktopEntry} ${dbusName} ${metadataUrl}`;
        if (description.includes("spotify")) return "spotify";
        if (description.includes("music.youtube") || description.includes("youtube music")) return "youtube-music";
        return "youtube";
    }

    readonly property string displayedArt: {
        if (root.artUrl.length === 0) return "";
        if (root.artUrl.startsWith("file://")) return root.artUrl;
        if (root.artUrl.startsWith("/")) return Qt.resolvedUrl(root.artUrl);
        return root.downloadedArtKey === root.artKey ? Qt.resolvedUrl(root.artFilePath) : "";
    }
    readonly property bool hasLyrics: root.lines.length > 0
    readonly property int displayLine: root.activeLine >= 0 ? root.activeLine : 0
    readonly property string previousLyric: root.lines[root.displayLine - 1]?.text ?? ""
    readonly property string currentLyric: root.lines[root.displayLine]?.text ?? ""
    readonly property string nextLyric: root.lines[root.displayLine + 1]?.text ?? ""

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
        if (index !== root.activeLine)
            root.activeLine = index;
    }

    function startArtDownload(url, key) {
        const path = StringUtils.shellSingleQuoteEscape(`${Directories.coverArt}/${key}`);
        const folder = StringUtils.shellSingleQuoteEscape(Directories.coverArt);
        const escapedUrl = StringUtils.shellSingleQuoteEscape(url);

        coverArtDownloader.targetFile = url;
        coverArtDownloader.artFilePath = `${Directories.coverArt}/${key}`;
        coverArtDownloader.artKey = key;
        coverArtDownloader.command = [
            "bash", "-c",
            `mkdir -p '${folder}' && ` +
            `if [ -s '${path}' ] && { [ "$(tail -c 2 '${path}' | od -An -tx1 | tr -d ' \\n')" = "ffd9" ] || [ "$(tail -c 8 '${path}' | od -An -tx1 | tr -d ' \\n')" = "49454e44ae426082" ]; }; then exit 0; fi; ` +
            `tmp='${path}.part.$$'; rm -f "$tmp"; ` +
            `if curl -4 -fsSL '${escapedUrl}' -o "$tmp" && [ -s "$tmp" ]; then mv "$tmp" '${path}'; else rm -f "$tmp"; exit 1; fi`
        ];
        coverArtDownloader.running = true;
    }

    function updateArt() {
        if (root.artUrl.length === 0) {
            root.downloadedArtKey = "";
            root.pendingArtUrl = "";
            root.pendingArtKey = "";
            return;
        }
        if (root.artUrl.startsWith("file://") || root.artUrl.startsWith("/")) {
            root.downloadedArtKey = root.artKey;
            return;
        }
        if (root.downloadedArtKey === root.artKey) return;
        if (coverArtDownloader.running) {
            // Keep only the newest request; starting a Process while it is
            // already running would keep downloading the previous artwork.
            root.pendingArtUrl = root.artUrl;
            root.pendingArtKey = root.artKey;
            return;
        }
        root.startArtDownload(root.artUrl, root.artKey);
    }

    // Some players change trackArtUrl without notifying every binding. A small
    // watchdog makes sure the cover follows the current track reliably.
    function ensureArtCurrent() {
        if (root.artUrl.length === 0 || root.artUrl.startsWith("file://") || root.artUrl.startsWith("/"))
            return;
        if (root.downloadedArtKey === root.artKey)
            return;
        if (coverArtDownloader.running) {
            if (coverArtDownloader.artKey !== root.artKey) {
                root.pendingArtUrl = root.artUrl;
                root.pendingArtKey = root.artKey;
            }
            return;
        }
        root.startArtDownload(root.artUrl, root.artKey);
    }

    function syncPosition() {
        const player = MprisController.activePlayer;
        root.currentPosition = player?.position ?? 0;
        root.updateActiveLine();
    }

    function loadRecommendations() {
        root.recommendationsError = "";
        const artist = root.trackArtist.trim();
        if (artist.length === 0 || artist === Translation.tr("Unknown Artist")) {
            root.recommendations = [];
            root.recommendationsLoading = false;
            return;
        }

        root.recommendationsLoading = true;
        const query = encodeURIComponent(artist);
        recsProcess.running = false;
        recsProcess.command = [
            "curl", "-sS", "--max-time", "12",
            `https://api.deezer.com/search?q=${query}&limit=12`
        ];
        recsProcess.running = true;
    }

    function openRecommendation(track) {
        if (!track) return;
        const title = String(track.title ?? "");
        const artist = String(track.artist?.name ?? "");
        recommendationLauncher.command = [
            "python3", root.recommendationLauncherPath,
            root.playbackPlatform, title, artist
        ];
        recommendationLauncher.running = false;
        recommendationLauncher.running = true;
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
            root.activeLine = -1;
            root.recommendations = [];
            root.recommendationsLoading = false;
            return;
        }

        root.trackTitle = track.title;
        root.trackArtist = track.artist;
        root.trackAlbum = track.album;
        root.status = "loading";
        root.errorText = "";
        root.lines = [];
        root.activeLine = -1;
        root.syncPosition();
        root.loadRecommendations();

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

    onArtUrlChanged: updateArt()

    Component.onCompleted: {
        reload();
        updateArt();
    }

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

    Process {
        id: coverArtDownloader
        property string targetFile: ""
        property string artFilePath: ""
        property string artKey: ""
        running: false
        command: ["bash", "-c", ""]
        onExited: (exitCode, exitStatus) => {
            const finishedKey = coverArtDownloader.artKey;
            if (exitCode === 0 && finishedKey === root.artKey)
                root.downloadedArtKey = finishedKey;

            if (root.pendingArtKey.length > 0) {
                const nextUrl = root.pendingArtUrl;
                const nextKey = root.pendingArtKey;
                root.pendingArtUrl = "";
                root.pendingArtKey = "";
                if (nextKey !== finishedKey)
                    root.startArtDownload(nextUrl, nextKey);
                else if (nextKey === root.artKey && exitCode === 0)
                    root.downloadedArtKey = nextKey;
            }
        }
    }

    Process {
        id: recsProcess
        running: false
        command: ["curl", "-sS", "--max-time", "12", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                root.recommendationsLoading = false;
                try {
                    const parsed = JSON.parse(text);
                    const currentTitle = root.trackTitle.toLowerCase();
                    root.recommendations = (parsed.data ?? [])
                        .filter(track => track?.title?.toLowerCase() !== currentTitle)
                        .slice(0, 8);
                } catch (error) {
                    root.recommendations = [];
                    root.recommendationsError = Translation.tr("Could not load recommendations");
                }
            }
        }
    }

    Process {
        id: recommendationLauncher
        running: false
        command: ["python3", root.recommendationLauncherPath, "", "", ""]
    }

    Timer {
        id: positionTimer
        interval: 500
        repeat: true
        running: MprisController.isPlaying && root.activePlayer !== null
        onTriggered: {
            const player = MprisController.activePlayer;
            if (!player) return;
            player.positionChanged();
            root.currentPosition = player.position ?? 0;
            if (root.usingSynced)
                root.updateActiveLine();
        }
    }

    Timer {
        interval: 1200
        repeat: true
        running: true
        onTriggered: root.ensureArtCurrent()
    }

    // cava visualizer
    Process {
        id: cavaProc
        running: MprisController.isPlaying && GlobalStates.sidebarLeftOpen
        onRunningChanged: {
            if (!cavaProc.running)
                root.visualizerPoints = [];
        }
        command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/raw_output_config.txt`]
        stdout: SplitParser {
            onRead: data => {
                root.visualizerPoints = data.split(";")
                    .map(point => parseFloat(point.trim()))
                    .filter(point => !isNaN(point));
            }
        }
    }

    component ControlButton: RippleButton {
        id: controlButton
        required property string iconName
        property bool primary: false

        implicitWidth: primary ? 52 : 42
        implicitHeight: primary ? 52 : 42
        buttonRadius: height / 2
        colBackground: primary
            ? Appearance.colors.colPrimaryContainer
            : ColorUtils.transparentize(Appearance.colors.colLayer1, 1)
        colBackgroundHover: primary
            ? Appearance.colors.colPrimaryContainerHover
            : Appearance.colors.colLayer1Hover
        colRipple: primary
            ? Appearance.colors.colPrimaryContainerActive
            : Appearance.colors.colLayer1Active

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: controlButton.iconName
            fill: 1
            iconSize: controlButton.primary ? 28 : 24
            color: controlButton.primary
                ? Appearance.colors.colOnPrimaryContainer
                : Appearance.colors.colOnLayer1
        }
    }

    ColumnLayout {
        id: mainContent
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: cavaArea.visible ? cavaArea.top : parent.bottom
            margins: root.padding
            bottomMargin: 0
        }
        spacing: 10

        // Album art
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(260, root.width - root.padding * 2)
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1
            clip: true

            StyledImage {
                anchors.fill: parent
                source: root.displayedArt
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                visible: root.displayedArt.length > 0
            }

            Rectangle {
                anchors.fill: parent
                visible: root.displayedArt.length === 0
                color: Appearance.colors.colLayer1

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "music_note"
                    iconSize: 56
                    color: Appearance.colors.colSubtext
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: titleColumn.implicitHeight + 20
                color: "#99000000"

                ColumnLayout {
                    id: titleColumn
                    anchors {
                        fill: parent
                        leftMargin: 14
                        rightMargin: 14
                    }
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: root.trackTitle.length > 0 ? root.trackTitle : Translation.tr("No music playing")
                        color: "white"
                        font {
                            weight: Font.Medium
                            pixelSize: Appearance.font.pixelSize.large
                        }
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: root.trackArtist.length > 0
                        text: root.trackArtist
                        color: "#dddddd"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // Lyrics: vertically scrolling, Spotify-style
        Rectangle {
            id: lyricsBox
            Layout.fillWidth: true
            Layout.preferredHeight: 112
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1
            clip: true

            readonly property real rowHeight: 32

            Item {
                id: lyricsViewport
                anchors.fill: parent
                clip: true

                Item {
                    id: lyricsTrack
                    width: parent.width
                    height: Math.max(1, root.lines.length * lyricsBox.rowHeight)
                    y: lyricsViewport.height / 2 - (root.displayLine + 0.5) * lyricsBox.rowHeight

                    Behavior on y {
                        NumberAnimation {
                            duration: 420
                            easing.type: Easing.OutCubic
                        }
                    }

                    Repeater {
                        model: root.lines

                        delegate: Item {
                            id: lyricRow
                            required property var modelData
                            required property int index

                            width: lyricsTrack.width
                            height: lyricsBox.rowHeight
                            y: index * lyricsBox.rowHeight

                            StyledText {
                                anchors {
                                    fill: parent
                                    leftMargin: 14
                                    rightMargin: 14
                                }
                                text: lyricRow.modelData.text
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                color: lyricRow.index === root.displayLine
                                    ? Appearance.colors.colPrimary
                                    : ColorUtils.transparentize(Appearance.colors.colOnSurface, 0.5)
                                opacity: lyricRow.index === root.displayLine ? 1 : 0.7
                                font {
                                    weight: lyricRow.index === root.displayLine ? Font.DemiBold : Font.Normal
                                    pixelSize: lyricRow.index === root.displayLine
                                        ? Appearance.font.pixelSize.larger
                                        : Appearance.font.pixelSize.small
                                }
                            }
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    width: parent.width - 24
                    visible: !root.hasLyrics
                    text: {
                        if (root.status === "loading") return Translation.tr("Loading lyrics...");
                        if (root.status === "error" && root.errorText.length > 0) return root.errorText;
                        return Translation.tr("No lyrics found");
                    }
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                    wrapMode: Text.Wrap
                }
            }
        }

        // Progress display and seek bar
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    text: root.elapsedText
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
                Item { Layout.fillWidth: true }
                StyledText {
                    text: root.remainingText
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }

            StyledSlider {
                Layout.fillWidth: true
                configuration: StyledSlider.Configuration.Wavy
                highlightColor: Appearance.colors.colPrimary
                trackColor: Appearance.colors.colSecondaryContainer
                handleColor: Appearance.colors.colPrimary
                enabled: MprisController.activePlayer?.canSeek ?? false
                value: root.trackLength > 0
                    ? Math.max(0, Math.min(1, root.currentPosition / root.trackLength))
                    : 0
                onMoved: {
                    if (!root.activePlayer || root.trackLength <= 0) return;
                    root.activePlayer.position = value * root.trackLength;
                    root.currentPosition = value * root.trackLength;
                    root.updateActiveLine();
                }
            }
        }

        // Playback controls
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16

            ControlButton {
                iconName: "skip_previous"
                opacity: MprisController.canGoPrevious ? 1 : 0.35
                onClicked: MprisController.previous()
            }

            ControlButton {
                iconName: MprisController.isPlaying ? "pause" : "play_arrow"
                primary: true
                opacity: MprisController.canTogglePlaying ? 1 : 0.35
                onClicked: MprisController.togglePlaying()
            }

            ControlButton {
                iconName: "skip_next"
                opacity: MprisController.canGoNext ? 1 : 0.35
                onClicked: MprisController.next()
            }
        }

        // Recommended tracks
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                MaterialSymbol {
                    text: "explore"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colPrimary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Recommended")
                    color: Appearance.colors.colOnSurface
                    font {
                        weight: Font.Medium
                        pixelSize: Appearance.font.pixelSize.small
                    }
                }
                MaterialLoadingIndicator {
                    visible: root.recommendationsLoading
                    loading: root.recommendationsLoading
                    implicitSize: 18
                }
            }

            StyledListView {
                id: recommendationsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.recommendations.length > 0
                clip: true
                spacing: 4
                model: root.recommendations

                delegate: RippleButton {
                    id: recommendationButton
                    required property var modelData

                    width: recommendationsList.width
                    implicitHeight: 52
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colLayer1
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    onClicked: root.openRecommendation(recommendationButton.modelData)

                    contentItem: RowLayout {
                        anchors {
                            fill: parent
                            margins: 6
                        }
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colLayer2
                            clip: true

                            StyledImage {
                                anchors.fill: parent
                                source: recommendationButton.modelData.album?.cover_small ?? ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: recommendationButton.modelData.title ?? ""
                                color: Appearance.colors.colOnSurface
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: recommendationButton.modelData.artist?.name ?? ""
                                color: Appearance.colors.colSubtext
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                        }

                        MaterialSymbol {
                            text: "open_in_new"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }

            StyledText {
                visible: !root.recommendationsLoading
                    && root.recommendations.length === 0
                    && root.recommendationsError.length > 0
                Layout.fillWidth: true
                text: root.recommendationsError
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.Wrap
            }
        }
    }

    // Cava visualizer: flush with the bottom edge, no padding.
    Item {
        id: cavaArea
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: 54
        visible: MprisController.isPlaying
        clip: true

        BarVisualizer {
            anchors.fill: parent
            points: root.visualizerPoints
            maxVisualizerValue: 1000
            smoothing: 2
            minimumBarHeight: 2
            color: Appearance.colors.colPrimary
        }
    }
}
