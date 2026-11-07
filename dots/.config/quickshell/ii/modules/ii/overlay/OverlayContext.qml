pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import qs.modules.common

Singleton {
    id: root

    signal requestCenter(string identifier)

    readonly property int maxFloatingImages: 12
    property int floatingImageSpawnCounter: 0

    readonly property bool floatingImagesEnabled: Config.options.policies.weeb !== 0

    readonly property list<var> availableWidgets: [
        { identifier: "crosshair", materialSymbol: "point_scan" },
        { identifier: "fpsLimiter", materialSymbol: "animation" },
        ...(root.floatingImagesEnabled ? [{ identifier: "floatingImage", materialSymbol: "imagesmode" }] : []),
        { identifier: "recorder", materialSymbol: "screen_record" },
        { identifier: "resources", materialSymbol: "browse_activity" },
        { identifier: "notes", materialSymbol: "note_stack" },
        { identifier: "volumeMixer", materialSymbol: "volume_up" },
    ]

    readonly property bool hasPinnedWidgets: root.pinnedWidgetIdentifiers.length > 0

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

    function floatingImageSourceFor(index: int): string {
        const options = Config.options.overlay.floatingImage.sources ?? [];
        const sources = options.length > 0
            ? options
            : [Config.options.overlay.floatingImage.imageSource];
        return sources[index % sources.length] ?? "";
    }

    function spawnFloatingImage(): string {
        if (!root.floatingImagesEnabled) return "";

        for (let index = 1; index <= root.maxFloatingImages; ++index) {
            const identifier = `floatingImage${index}`;
            if (Persistent.states.overlay.open.includes(identifier)) continue;

            const state = Persistent.states.overlay[identifier];
            if (!state) continue;

            state.imageSource = root.floatingImageSourceFor(root.floatingImageSpawnCounter);
            root.floatingImageSpawnCounter += 1;
            state.pinned = false;
            state.clickthrough = false;

            Persistent.states.overlay.open.push(identifier);
            return identifier;
        }
        return "";
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
