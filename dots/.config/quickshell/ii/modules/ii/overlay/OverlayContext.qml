pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    signal requestCenter(string identifier)

    readonly property int maxFloatingImages: 12
    property string pickerTargetIdentifier: ""

    readonly property bool floatingImagesEnabled: Config.options.policies.floatingImages ?? true

    readonly property list<var> availableWidgets: [
        { identifier: "crosshair", materialSymbol: "point_scan" },
        { identifier: "fpsLimiter", materialSymbol: "animation" },
        ...(root.floatingImagesEnabled ? [{ identifier: "floatingImage", materialSymbol: "imagesmode" }] : []),
        { identifier: "recorder", materialSymbol: "screen_record" },
        { identifier: "resources", materialSymbol: "browse_activity" },
        { identifier: "notes", materialSymbol: "note_stack" },
        { identifier: "volumeMixer", materialSymbol: "volume_up" },
    ]

    readonly property bool hasPinnedWidgets: Persistent.states.overlay.open.some(identifier => {
        const state = Persistent.states.overlay[identifier];
        if (state?.pinned !== true) return false;
        const base = root.baseIdentifier(identifier);
        return root.availableWidgets.some(widget => widget.identifier === base);
    })

    function widgetScreenName(identifier) {
        const state = Persistent.states.overlay[identifier];
        return state?.screenName || Persistent.states.overlay.screenName || "";
    }

    function hasPinnedWidgetsOnScreen(screenName) {
        if (!screenName) return false;
        return Persistent.states.overlay.open.some(identifier => {
            const state = Persistent.states.overlay[identifier];
            if (state?.pinned !== true) return false;
            const base = root.baseIdentifier(identifier);
            if (!root.availableWidgets.some(widget => widget.identifier === base)) return false;
            return root.widgetScreenName(identifier) === screenName;
        });
    }

    property list<string> pinnedWidgetIdentifiers: []
    property list<var> clickableWidgets: []

    function baseIdentifier(identifier: string): string {
        return /^floatingImage\d+$/.test(identifier) ? "floatingImage" : identifier;
    }

    // Returns the model entry used by the overlay delegate. Dynamic floating
    // image slots keep their unique identifier so each one has its own state.
    function definitionFor(identifier: string): var {
        const base = root.baseIdentifier(identifier);
        const definition = root.availableWidgets.find(widget => widget.identifier === base);
        if (!definition) return null;
        return {
            identifier: identifier,
            baseIdentifier: base,
            materialSymbol: definition.materialSymbol,
        };
    }

    function defaultFloatingImageSource(): string {
        return Config.options.overlay.floatingImage.imageSource ?? "";
    }

    function spawnFloatingImage(source = "", screenName = ""): string {
        if (!root.floatingImagesEnabled) return "";

        for (let index = 1; index <= root.maxFloatingImages; ++index) {
            const identifier = `floatingImage${index}`;
            if (Persistent.states.overlay.open.includes(identifier)) continue;

            const state = Persistent.states.overlay[identifier];
            if (!state) continue;

            const initialSource = source.length > 0 ? source : root.defaultFloatingImageSource();
            state.imageSource = initialSource;
            if (screenName.length > 0) state.screenName = screenName;
            state.pinned = false;
            state.clickthrough = false;

            // Keep the image inside the active mode's own stickers folder.
            if (initialSource.length > 0) {
                ProfileManager.importSticker(ProfileManager.activeId, initialSource, (result, exitCode) => {
                    if (exitCode === 0 && result?.path) state.imageSource = result.path;
                });
            }

            Persistent.states.overlay.open.push(identifier);
            return identifier;
        }
        return "";
    }

    function stickerFolder(): string {
        return ProfileManager.activeProfile?.stickersFolder
            ?? `${Quickshell.env("HOME")}/.local/share/redOpinion_IlogicalImpulse/${ProfileManager.activeId}/stickers`;
    }

    function shellQuotedPath(value): string {
        const text = String(value ?? "").trim();
        return text.length > 0 ? `'${StringUtils.shellSingleQuoteEscape(text)}'` : '"$HOME"';
    }

    function requestFloatingImageSource(identifier: string): void {
        if (!root.floatingImagesEnabled) return;
        const state = Persistent.states.overlay[identifier];
        if (!state) return;
        root.pickerTargetIdentifier = identifier;
        const folder = root.stickerFolder();
        pickImageProcess.command = ["bash", "-c", `
            command -v kdialog >/dev/null 2>&1 || {
                notify-send -a "Floating image" -i "dialog-error" "kdialog is not installed"
                exit 1
            }
            mkdir -p ${root.shellQuotedPath(folder)}
            kdialog --title "Select floating image" \\
                --getopenfilename ${root.shellQuotedPath(folder)} \\
                "Images (*.png *.jpg *.jpeg *.gif *.webp *.avif *.bmp)"
        `];
        pickImageProcess.running = true;
    }

    Process {
        id: pickImageProcess
        running: false
        command: ["bash", "-c", `kdialog --getopenfilename "$HOME" "Images (*.png *.jpg *.jpeg *.gif *.webp *.avif *.bmp)"`]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                const identifier = root.pickerTargetIdentifier;
                if (path.length > 0 && identifier.length > 0) {
                    const state = Persistent.states.overlay[identifier];
                    if (state) {
                        // Keep sticker files inside the active mode's own
                        // stickers folder instead of ~/Pictures.
                        ProfileManager.importSticker(ProfileManager.activeId, path, (result, exitCode) => {
                            state.imageSource = exitCode === 0 && result?.path ? result.path : path;
                        });
                    }
                }
                root.pickerTargetIdentifier = "";
            }
        }
    }

    function closeAllFloatingImages(): void {
        for (let index = 1; index <= root.maxFloatingImages; ++index) {
            const identifier = `floatingImage${index}`;
            const state = Persistent.states.overlay[identifier];
            if (state) state.pinned = false;
        }
        Persistent.states.overlay.open = Persistent.states.overlay.open.filter(identifier => !/^floatingImage\d+$/.test(identifier));
    }

    function pin(identifier: string, pin = true) {
        if (pin) {
            if (!root.pinnedWidgetIdentifiers.includes(identifier)) {
                root.pinnedWidgetIdentifiers.push(identifier)
            }
        } else {
            root.pinnedWidgetIdentifiers = root.pinnedWidgetIdentifiers.filter(id => id !== identifier)
        }
    }

    function registerClickableWidget(widget: var, clickable = true) {
        if (clickable) {
            if (!root.clickableWidgets.includes(widget)) {
                root.clickableWidgets.push(widget)
            }
        } else {
            root.clickableWidgets = root.clickableWidgets.filter(w => w !== widget)
        }
    }
}
