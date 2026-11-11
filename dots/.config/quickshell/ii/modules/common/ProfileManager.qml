pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var profileList: []
    property string activeId: ""
    readonly property var activeProfile: root.profileList.find(profile => profile.id === root.activeId) ?? null
    readonly property string helperPath: `${Quickshell.env("HOME")}/.config/hypr/custom/scripts/profiles.py`

    property var pendingAction: null

    Timer {
        id: tabsSaveTimer
        interval: 220
        repeat: false
        onTriggered: {
            const profile = root.activeProfile;
            if (!profile) return;
            root.updateProfile(profile.id, { tabs: profile.tabs });
        }
    }

    function reload() {
        listProcess.running = false;
        listProcess.command = ["python3", root.helperPath, "list"];
        listProcess.running = true;
    }

    function profileById(profileId) {
        return root.profileList.find(profile => profile.id === profileId) ?? null;
    }

    function tabVisible(key) {
        const tabs = root.activeProfile?.tabs;
        if (!tabs) return true;
        return tabs[key] !== false;
    }

    function replaceLocalProfile(profile) {
        const list = root.profileList.slice();
        const index = list.findIndex(item => item.id === profile.id);
        if (index >= 0) list[index] = profile;
        root.profileList = list;
    }

    // Mirror the applied profile into the live Config singleton. External
    // scripts write config.json atomically, which the running FileView does
    // not always notice, so this keeps the current session in sync too.
    function syncProfileToConfig(profile) {
        if (!profile) return;
        if (profile.wallpaper) {
            Config.options.background.wallpaperPath = profile.wallpaper;
            Config.options.background.thumbnailPath = profile.wallpaper;
        }
        Config.options.policies.weeb = profile.weebPolicy ? 1 : 0;
        Config.options.policies.floatingImages = profile.floatingImages === true;
    }

    function setTabVisible(key, value) {
        const profile = root.activeProfile;
        if (!profile) return;
        const tabs = Object.assign({}, profile.tabs ?? {}, { [key]: value });
        root.replaceLocalProfile(Object.assign({}, profile, { tabs: tabs }));
        tabsSaveTimer.restart();
    }

    function setFloatingImages(value) {
        const profile = root.activeProfile;
        if (!profile) return;
        root.replaceLocalProfile(Object.assign({}, profile, { floatingImages: value }));
        Config.options.policies.floatingImages = value;
        root.updateProfile(profile.id, { floatingImages: value });
    }

    function runAction(args, callback) {
        if (actionProcess.running) {
            root.pendingAction = { args: args, callback: callback };
            return;
        }
        // The Python helper rewrites config.json. Make sure any pending QML
        // changes (weather city, wallpaper, policies...) are already on disk
        // so they are not lost when the helper loads and saves the file.
        Config.flush();
        actionProcess.command = ["python3", root.helperPath].concat(args);
        actionProcess.currentCallback = callback;
        actionProcess.running = true;
    }

    function rotateWallpaper() {
        const profile = root.activeProfile;
        if (!profile) return;
        root.runAction(["rotate-wallpaper", profile.id], (text, exitCode) => {
            if (exitCode !== 0) return;
            try {
                const updated = JSON.parse(text);
                if (updated && !updated.error) {
                    root.replaceLocalProfile(updated);
                    root.syncProfileToConfig(updated);
                }
            } catch (error) {
                // Ignore malformed output, the next reload will resync.
            }
        });
    }

    readonly property int wallpaperInterval: root.activeProfile?.wallpaperInterval ?? 0

    Timer {
        id: wallpaperRotationTimer
        // 0 (or a missing value) disables rotation.
        running: root.wallpaperInterval > 0 && root.activeProfile !== null
        repeat: true
        interval: Math.max(5, root.wallpaperInterval) * 1000
        onTriggered: root.rotateWallpaper()
    }

    function applyProfile(profileId, callback) {
        root.runAction(["apply", profileId], (text, exitCode) => {
            if (exitCode === 0) {
                try {
                    const parsed = JSON.parse(text);
                    root.activeId = parsed.id ?? profileId;
                    root.syncProfileToConfig(parsed);
                } catch (error) {
                    root.activeId = profileId;
                }
            }
            if (callback) callback(text, exitCode);
        });
    }

    function createProfile(name, callback) {
        root.runAction(["create", name ?? "New mode"], (text, exitCode) => {
            let created = null;
            try { created = JSON.parse(text); } catch (error) { created = null; }
            if (callback) callback(created, exitCode);
        });
    }

    function updateProfile(profileId, patch, callback) {
        root.runAction(["update", profileId, JSON.stringify(patch)], (text, exitCode) => {
            let updated = null;
            try { updated = JSON.parse(text); } catch (error) { updated = null; }
            if (updated && !updated.error) root.replaceLocalProfile(updated);
            if (callback) callback(updated, exitCode);
        });
    }

    function deleteProfile(profileId, callback) {
        root.runAction(["delete", profileId], (text, exitCode) => {
            let remaining = null;
            try { remaining = JSON.parse(text); } catch (error) { remaining = null; }
            if (remaining && !remaining.error) {
                root.activeId = remaining.id;
                root.syncProfileToConfig(remaining);
            }
            if (callback) callback(remaining, exitCode);
        });
    }

    function setWallpaperForActive(imagePath, callback) {
        root.runAction(["set-wallpaper", imagePath], (text, exitCode) => {
            let updated = null;
            try { updated = JSON.parse(text); } catch (error) { updated = null; }
            if (updated && !updated.error) {
                root.replaceLocalProfile(updated);
                root.syncProfileToConfig(updated);
            }
            if (callback) callback(updated, exitCode);
        });
    }

    function setVesktopBackground(profileId, imagePath, callback) {
        root.runAction(["set-vesktop-background", profileId, imagePath], (text, exitCode) => {
            let updated = null;
            try { updated = JSON.parse(text); } catch (error) { updated = null; }
            if (updated && !updated.error) root.replaceLocalProfile(updated);
            if (callback) callback(updated, exitCode);
        });
    }

    function clearVesktopBackground(profileId, callback) {
        root.runAction(["clear-vesktop-background", profileId], (text, exitCode) => {
            let updated = null;
            try { updated = JSON.parse(text); } catch (error) { updated = null; }
            if (updated && !updated.error) root.replaceLocalProfile(updated);
            if (callback) callback(updated, exitCode);
        });
    }

    function setSpotifastBackground(profileId, imagePath, callback) {
        root.runAction(["set-spotifast-background", profileId, imagePath], (text, exitCode) => {
            let updated = null;
            try { updated = JSON.parse(text); } catch (error) { updated = null; }
            if (updated && !updated.error) root.replaceLocalProfile(updated);
            if (callback) callback(updated, exitCode);
        });
    }

    function clearSpotifastBackground(profileId, callback) {
        root.runAction(["clear-spotifast-background", profileId], (text, exitCode) => {
            let updated = null;
            try { updated = JSON.parse(text); } catch (error) { updated = null; }
            if (updated && !updated.error) root.replaceLocalProfile(updated);
            if (callback) callback(updated, exitCode);
        });
    }

    Component.onCompleted: reload()

    Process {
        id: listProcess
        running: false
        command: ["python3", root.helperPath, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    // Set the active id first so the first profileListChanged
                    // handler selects the active profile instead of the first.
                    root.activeId = parsed.active ?? "";
                    root.profileList = parsed.profiles ?? [];
                } catch (error) {
                    root.profileList = [];
                    root.activeId = "";
                }
            }
        }
    }

    Process {
        id: actionProcess
        running: false
        property var currentCallback: null
        command: ["python3", root.helperPath, "list"]
        stdout: StdioCollector {
            id: actionOutput
        }
        onExited: (exitCode, exitStatus) => {
            const text = actionOutput.text;
            const callback = actionProcess.currentCallback;
            actionProcess.currentCallback = null;
            if (callback) callback(text, exitCode);
            root.reload();
            if (root.pendingAction) {
                const pending = root.pendingAction;
                root.pendingAction = null;
                root.runAction(pending.args, pending.callback);
            }
        }
    }
}
