pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property alias states: persistentStatesJsonAdapter
    property string fileDir: Directories.state
    property string fileName: "states.json"
    property string filePath: `${root.fileDir}/${root.fileName}`

    property bool ready: false
    property string previousHyprlandInstanceSignature: ""
    property bool isNewHyprlandInstance: previousHyprlandInstanceSignature !== states.hyprlandInstanceSignature

    readonly property list<string> overlayWidgetIdentifiers: [
        "crosshair", "floatingImage", "floatingImage1", "floatingImage2",
        "floatingImage3", "floatingImage4", "floatingImage5", "floatingImage6",
        "floatingImage7", "floatingImage8", "floatingImage9", "floatingImage10",
        "floatingImage11", "floatingImage12", "fpsLimiter", "recorder",
        "resources", "volumeMixer", "notes"
    ]

    // Older state files didn't store the monitor of each overlay widget.
    // Assign the legacy overlay screen so they have a stable monitor before
    // the per-screen overlay windows are created.
    function ensureWidgetScreens() {
        const fallback = root.states.overlay.screenName || Quickshell.screens[0]?.name || "";
        if (!root.states.overlay.screenName && fallback.length > 0)
            root.states.overlay.screenName = fallback;
        for (const identifier of root.overlayWidgetIdentifiers) {
            const state = root.states.overlay[identifier];
            if (state && !state.screenName && fallback.length > 0)
                state.screenName = fallback;
        }
    }

    onReadyChanged: {
        root.previousHyprlandInstanceSignature = root.states.hyprlandInstanceSignature
        root.states.hyprlandInstanceSignature = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || ""
        root.ensureWidgetScreens()
    }

    Timer {
        id: fileReloadTimer
        interval: 100
        repeat: false
        onTriggered: {
            persistentStatesFileView.reload()
        }
    }

    Timer {
        id: fileWriteTimer
        interval: 100
        repeat: false
        onTriggered: {
            persistentStatesFileView.writeAdapter()
        }
    }

    FileView {
        id: persistentStatesFileView
        path: root.filePath

        watchChanges: true
        onFileChanged: fileReloadTimer.restart()
        onAdapterUpdated: fileWriteTimer.restart()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            console.log("Failed to load persistent states file:", error);
            if (error == FileViewError.FileNotFound) {
                fileWriteTimer.restart();
            }
        }

        adapter: JsonAdapter {
            id: persistentStatesJsonAdapter

            property string hyprlandInstanceSignature: ""

            property JsonObject ai: JsonObject {
                property string model: "gemini-2.5-flash"
                property real temperature: 0.5
            }

            property JsonObject cheatsheet: JsonObject {
                property int tabIndex: 0
            }

            property JsonObject sidebar: JsonObject {
                property JsonObject leftPanel: JsonObject {
                    property bool ai: true
                    property bool translator: true
                    property bool anime: true
                    property bool social: true
                    property bool lyrics: true
                }
                property JsonObject social: JsonObject {
                    property string subreddit: "unixporn"
                }
                property JsonObject bottomGroup: JsonObject {
                    property bool collapsed: false
                    property int tab: 0
                }
            }

            property JsonObject booru: JsonObject {
                property bool allowNsfw: false
                property string provider: "yandere"
            }

            property JsonObject idle: JsonObject {
                property bool inhibit: false
            }

            property JsonObject overlay: JsonObject {
                property list<string> open: ["crosshair", "recorder", "volumeMixer", "resources"]
                // Monitor where pinned overlay widgets were last positioned.
                // Keeping it makes their local coordinates stable across sessions.
                property string screenName: ""
                property JsonObject crosshair: JsonObject {
                    property bool pinned: false
                    property string screenName: ""
                    property bool clickthrough: true
                    property real x: 827
                    property real y: 441
                    property real width: 250
                    property real height: 100
                }
                property JsonObject floatingImage: JsonObject {
                    property bool pinned: false
                    property string screenName: ""
                    property bool clickthrough: false
                    property real x: 1650
                    property real y: 390
                    property real width: 0
                    property real height: 0
                }
                // Fixed slots used by the multi-image overlay. Each slot keeps
                // its own position, scale and image source.
                property JsonObject floatingImage1: JsonObject {
                    property bool pinned: false
                    property string screenName: ""
                    property bool clickthrough: false
                    property real x: 220
                    property real y: 220
                    property real width: 0
                    property real height: 0
                    property real scale: 0.5
                    property string imageSource: ""
                }
                property JsonObject floatingImage2: JsonObject {
                    property bool pinned: false
                    property string screenName: ""
                    property bool clickthrough: false
                    property real x: 310
                    property real y: 220
                    property real width: 0
                    property real height: 0
                    property real scale: 0.5
                    property string imageSource: ""
                }
                property JsonObject floatingImage3: JsonObject {
                    property bool pinned: false
                    property string screenName: ""
                    property bool clickthrough: false
                    property real x: 400
                    property real y: 220
                    property real width: 0
                    property real height: 0
                    property real scale: 0.5
                    property string imageSource: ""
                }
                property JsonObject floatingImage4: JsonObject {
                    property bool pinned: false
                    property string screenName: ""
                    property bool clickthrough: false
                    property real x: 490
                    property real y: 220
                    property real width: 0
                    property real height: 0
                    property real scale: 0.5
                    property string imageSource: ""
                }
                property JsonObject floatingImage5: JsonObject {
                    property bool pinned: false
                    property string screenName: ""
                    property bool clickthrough: false
                    property real x: 220
                    property real y: 310
                    property real width: 0
                    property real height: 0
                    property real scale: 0.5
                    property string imageSource: ""
                }
                property JsonObject floatingImage6: JsonObject {
                    property bool pinned: false
                    property string screenName: ""
                    property bool clickthrough: false
                    property real x: 310
                    property real y: 310
                    property real width: 0
                    property real height: 0
                    property real scale: 0.5
                    property string imageSource: ""
                }
                property JsonObject floatingImage7: JsonObject {
                    property bool pinned: false
                    property string screenName: ""
                    property bool clickthrough: false
                    property real x: 400
                    property real y: 310
                    property real width: 0
                    property real height: 0
                    property real scale: 0.5
                    property string imageSource: ""
                }
                property JsonObject floatingImage8: JsonObject {
                    property bool pinned: false
                    property string screenName: ""
                    property bool clickthrough: false
                    property real x: 490
                    property real y: 310
                    property real width: 0
                    property real height: 0
                    property real scale: 0.5
                    property string imageSource: ""
                }
                property JsonObject floatingImage9: JsonObject {
                    property bool pinned: false
                    property string screenName: ""
                    property bool clickthrough: false
                    property real x: 220
                    property real y: 400
                    property real width: 0
                    property real height: 0
                    property real scale: 0.5
                    property string imageSource: ""
                }
                property JsonObject floatingImage10: JsonObject {
                    property bool pinned: false
                    property string screenName: ""
                    property bool clickthrough: false
                    property real x: 310
                    property real y: 400
                    property real width: 0
                    property real height: 0
                    property real scale: 0.5
                    property string imageSource: ""
                }
                property JsonObject floatingImage11: JsonObject {
                    property bool pinned: false
                    property string screenName: ""
                    property bool clickthrough: false
                    property real x: 400
                    property real y: 400
                    property real width: 0
                    property real height: 0
                    property real scale: 0.5
                    property string imageSource: ""
                }
                property JsonObject floatingImage12: JsonObject {
                    property bool pinned: false
                    property string screenName: ""
                    property bool clickthrough: false
                    property real x: 490
                    property real y: 400
                    property real width: 0
                    property real height: 0
                    property real scale: 0.5
                    property string imageSource: ""
                }
                property JsonObject fpsLimiter: JsonObject {
                    property bool pinned: false
                    property string screenName: ""
                    property bool clickthrough: false
                    property real x: 1570
                    property real y: 615
                    property real width: 280
                    property real height: 80
                }
                property JsonObject recorder: JsonObject {
                    property bool pinned: false
                    property string screenName: ""
                    property bool clickthrough: false
                    property real x: 80
                    property real y: 80
                    property real width: 350
                    property real height: 130
                }
                property JsonObject resources: JsonObject {
                    property bool pinned: false
                    property string screenName: ""
                    property bool clickthrough: true
                    property real x: 1500
                    property real y: 770
                    property real width: 350
                    property real height: 200
                    property int tabIndex: 0
                }
                property JsonObject volumeMixer: JsonObject {
                    property bool pinned: false
                    property string screenName: ""
                    property bool clickthrough: false
                    property real x: 80
                    property real y: 280
                    property real width: 350
                    property real height: 600
                    property int tabIndex: 0
                }
                property JsonObject notes: JsonObject {
                    property bool pinned: false
                    property string screenName: ""
                    property bool clickthrough: true
                    property real x: 1400
                    property real y: 42
                    property real width: 460
                    property real height: 330
                }
            }

            property JsonObject timer: JsonObject {
                property JsonObject pomodoro: JsonObject {
                    property bool running: false
                    property int start: 0
                    property bool isBreak: false
                    property int cycle: 0
                }
                property JsonObject stopwatch: JsonObject {
                    property bool running: false
                    property int start: 0
                    property list<var> laps: []
                }
            }
        }
    }
}
