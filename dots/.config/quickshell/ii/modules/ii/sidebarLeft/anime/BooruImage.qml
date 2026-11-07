import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.utils
import qs.modules.common.widgets
import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Button {
    id: root
    property var imageData
    property var rowHeight
    property bool manualDownload: false
    property string previewDownloadPath
    property string downloadPath
    property string nsfwPath
    property string fileName: decodeURIComponent((imageData.file_url).substring((imageData.file_url).lastIndexOf('/') + 1))
    property string filePath: `${root.previewDownloadPath}/${root.fileName}`
    property int maxTagStringLineLength: 50
    property real imageRadius: Appearance.rounding.small

    property bool showActions: false

    readonly property var focusedMonitor: HyprlandData.monitors.find(monitor => monitor.focused) ?? HyprlandData.monitors[0]
    readonly property int screenWidth: root.focusedMonitor?.width ?? 1920
    readonly property int screenHeight: root.focusedMonitor?.height ?? 1080
    readonly property int imagePixelWidth: Number(root.imageData?.width ?? 0)
    readonly property int imagePixelHeight: Number(root.imageData?.height ?? 0)
    readonly property bool imageHasEnoughResolution: root.imagePixelWidth >= root.screenWidth
        && root.imagePixelHeight >= root.screenHeight
    readonly property string wallpaperCacheDir: `${Quickshell.env("HOME")}/.cache/wallpapers`
    readonly property string wallpaperHelper: `${Quickshell.env("HOME")}/.config/hypr/custom/scripts/set-wallpaper.sh`
    readonly property string wallpaperUrl: root.imageData?.file_url
        ?? root.imageData?.sample_url
        ?? root.imageData?.preview_url
        ?? ""
    readonly property string wallpaperProvider: String(root.imageData?.provider ?? "booru")
        .replace(/[^A-Za-z0-9_-]/g, "_")
    readonly property string wallpaperId: String(root.imageData?.id ?? Date.now())
        .replace(/[^A-Za-z0-9_-]/g, "_")
    readonly property string wallpaperExtension: {
        const explicit = String(root.imageData?.file_ext ?? "").replace(/^\./, "");
        if (explicit.length > 0) return explicit;
        const clean = root.wallpaperUrl.split("?")[0];
        const part = clean.substring(clean.lastIndexOf(".") + 1);
        return part.length > 0 && part.length <= 5 ? part : "jpg";
    }
    readonly property string wallpaperPath: `${root.wallpaperCacheDir}/booru_${root.wallpaperProvider}_${root.wallpaperId}.${root.wallpaperExtension}`

    function requestSetAsWallpaper() {
        if (root.wallpaperUrl.length === 0) {
            Quickshell.execDetached(["notify-send", "-a", "Anime wallpaper", "-i", "dialog-error",
                "Cannot set wallpaper", "This image has no downloadable URL."]);
            return;
        }
        if (root.imageHasEnoughResolution) root.applyWallpaper();
        else lowResDialog.open();
    }

    function applyWallpaper() {
        const userAgent = Config.options?.networking?.userAgent ?? "";
        const userAgentHeader = userAgent
            ? ` -H 'User-Agent: ${StringUtils.shellSingleQuoteEscape(userAgent)}'`
            : "";
        const url = StringUtils.shellSingleQuoteEscape(root.wallpaperUrl);
        const path = StringUtils.shellSingleQuoteEscape(root.wallpaperPath);
        const cacheDir = StringUtils.shellSingleQuoteEscape(root.wallpaperCacheDir);
        const helper = StringUtils.shellSingleQuoteEscape(root.wallpaperHelper);
        const label = `${root.wallpaperProvider} #${root.wallpaperId}`;

        const command = `if mkdir -p '${cacheDir}' && curl -sSL --max-time 180 '${url}'${userAgentHeader} -o '${path}' && '${helper}' '${path}'; then `
            + `notify-send -a 'Anime wallpaper' 'Wallpaper set' '${label}'; `
            + `else notify-send -a 'Anime wallpaper' -i 'dialog-error' 'Could not set wallpaper' 'Check the image URL or the wallpaper script.'; fi`;

        Quickshell.execDetached(["notify-send", "-a", "Anime wallpaper", "Downloading wallpaper", "Preparing the image..."]);
        Quickshell.execDetached(["bash", "-c", command]);
    }

    ImageDownloaderProcess {
        id: imageDownloader
        running: root.manualDownload
        filePath: root.filePath
        // Use the sample/file URL instead of the tiny preview thumbnail.
        sourceUrl: root.imageData.sample_url
            ?? root.imageData.file_url
            ?? root.imageData.preview_url
        onDone: (path, width, height) => {
            imageObject.source = ""
            imageObject.source = path
            if (!modelData.width || !modelData.height) {
                modelData.width = width
                modelData.height = height
                modelData.aspect_ratio = width / height
            }
        }
    }

    StyledToolTip {
        text: `${StringUtils.wordWrap(root.imageData.tags, root.maxTagStringLineLength)}`
    }

    Popup {
        id: lowResDialog
        parent: Overlay.overlay
        width: 400
        height: lowResColumn.implicitHeight + 32
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        padding: 0
        modal: true
        dim: true
        focus: true
        closePolicy: Popup.CloseOnEscape

        contentItem: Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.m3colors.m3surfaceContainer
            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            ColumnLayout {
                id: lowResColumn
                anchors {
                    fill: parent
                    margins: 16
                }
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialSymbol {
                        text: "warning"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colError
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: "Resolución baja"
                        color: Appearance.colors.colOnSurface
                        font {
                            weight: Font.Medium
                            pixelSize: Appearance.font.pixelSize.larger
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: `La imagen tiene una resolución inferior a tu pantalla (${root.imagePixelWidth}×${root.imagePixelHeight} frente a ${root.screenWidth}×${root.screenHeight}). ¿Estás seguro de que quieres aplicarla como fondo de pantalla?`
                    color: Appearance.colors.colOnSurfaceVariant
                    font.pixelSize: Appearance.font.pixelSize.small
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item {
                        Layout.fillWidth: true
                    }

                    RippleButton {
                        implicitHeight: 36
                        horizontalPadding: 16
                        buttonRadius: Appearance.rounding.small
                        onClicked: lowResDialog.close()

                        contentItem: StyledText {
                            anchors.centerIn: parent
                            text: "Cancelar"
                            color: Appearance.colors.colOnSurface
                        }
                    }

                    RippleButton {
                        implicitHeight: 36
                        horizontalPadding: 16
                        buttonRadius: Appearance.rounding.small
                        toggled: true
                        onClicked: {
                            lowResDialog.close();
                            root.applyWallpaper();
                        }

                        contentItem: StyledText {
                            anchors.centerIn: parent
                            text: "Confirmar"
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                }
            }
        }
    }

    padding: 0
    implicitWidth: root.rowHeight * modelData.aspect_ratio
    implicitHeight: root.rowHeight

    background: Rectangle {
        implicitWidth: root.rowHeight * modelData.aspect_ratio
        implicitHeight: root.rowHeight
        radius: imageRadius
        color: Appearance.colors.colLayer2
    }

    contentItem: Item {
        anchors.fill: parent

        StyledImage {
            id: imageObject
            anchors.fill: parent
            width: root.rowHeight * modelData.aspect_ratio
            height: root.rowHeight
            fillMode: Image.PreserveAspectCrop
            source: modelData.sample_url
                ?? modelData.file_url
                ?? modelData.preview_url

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: root.rowHeight * modelData.aspect_ratio
                    height: root.rowHeight
                    radius: imageRadius
                }
            }
        }

        RippleButton {
            id: menuButton
            anchors.top: parent.top
            anchors.right: parent.right
            property real buttonSize: 30
            anchors.margins: Math.max(root.imageRadius - buttonSize / 2, 8)
            implicitHeight: buttonSize
            implicitWidth: buttonSize

            buttonRadius: Appearance.rounding.full
            colBackground: ColorUtils.transparentize(Appearance.m3colors.m3surface, 0.3)
            colBackgroundHover: ColorUtils.transparentize(ColorUtils.mix(Appearance.m3colors.m3surface, Appearance.m3colors.m3onSurface, 0.8), 0.2)
            colRipple: ColorUtils.transparentize(ColorUtils.mix(Appearance.m3colors.m3surface, Appearance.m3colors.m3onSurface, 0.6), 0.1)

            contentItem: MaterialSymbol {
                horizontalAlignment: Text.AlignHCenter
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.m3colors.m3onSurface
                text: "more_vert"
            }

            onClicked: {
                root.showActions = !root.showActions
            }
        }

        Loader {
            id: contextMenuLoader
            active: root.showActions
            // Open inside the image so menus with several actions are not
            // covered by the next image row.
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 8

            sourceComponent: Item {
                width: contextMenu.width
                height: contextMenu.height

                StyledRectangularShadow {
                    target: contextMenu
                }
                Rectangle {
                    id: contextMenu
                    anchors.centerIn: parent
                    opacity: root.showActions ? 1 : 0
                    visible: opacity > 0
                    radius: Appearance.rounding.small
                    color: Appearance.m3colors.m3surfaceContainer
                    implicitHeight: contextMenuColumnLayout.implicitHeight + radius * 2
                    implicitWidth: contextMenuColumnLayout.implicitWidth

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }

                    ColumnLayout {
                        id: contextMenuColumnLayout
                        anchors.centerIn: parent
                        spacing: 0

                        MenuButton {
                            id: openFileLinkButton
                            Layout.fillWidth: true
                            buttonText: Translation.tr("Open file link")
                            onClicked: {
                                root.showActions = false
                                Hyprland.dispatch("hl.config({cursor = {no_warps = true}})")
                                Qt.openUrlExternally(root.imageData.file_url)
                                Hyprland.dispatch("hl.config({cursor = {no_warps = false}})")
                            }
                        }
                        MenuButton {
                            id: sourceButton
                            visible: root.imageData.source && root.imageData.source.length > 0
                            Layout.fillWidth: true
                            buttonText: Translation.tr("Go to source (%1)").arg(StringUtils.getDomain(root.imageData.source))
                            enabled: root.imageData.source && root.imageData.source.length > 0
                            onClicked: {
                                root.showActions = false
                                Hyprland.dispatch("hl.config({cursor = {no_warps = true}})")
                                Qt.openUrlExternally(root.imageData.source)
                                Hyprland.dispatch("hl.config({cursor = {no_warps = false}})")
                            }
                        }
                        MenuButton {
                            id: setWallpaperButton
                            Layout.fillWidth: true
                            buttonText: Translation.tr("Set as Wallpaper")
                            onClicked: {
                                root.showActions = false;
                                root.requestSetAsWallpaper();
                            }
                        }
                        MenuButton {
                            id: downloadButton
                            Layout.fillWidth: true
                            buttonText: Translation.tr("Download")
                            onClicked: {
                                root.showActions = false;
                                const targetPath = root.imageData.is_nsfw ? root.nsfwPath : root.downloadPath;
                                const userAgent = Config.options?.networking?.userAgent ?? ""
                                const userAgentHeader = userAgent ? ` -H 'User-Agent: ${StringUtils.shellSingleQuoteEscape(userAgent)}'` : ""
                                Quickshell.execDetached(["bash", "-c", 
                                    `mkdir -p '${targetPath}' && curl '${StringUtils.shellSingleQuoteEscape(root.imageData.file_url)}'${userAgentHeader} -o '${targetPath}/${root.fileName}' && notify-send '${Translation.tr("Download complete")}' '${root.downloadPath}/${root.fileName}' -a 'Shell'`
                                ])
                            }
                        }
                    }
                }
            }
        }
    }
}