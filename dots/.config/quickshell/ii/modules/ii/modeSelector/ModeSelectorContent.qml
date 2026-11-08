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
    signal closeRequested()

    property string selectedId: ""
    property var draft: null
    property bool dirty: false
    property bool busy: false
    property bool deleteArmed: false

    function cloneProfile(profile) {
        return JSON.parse(JSON.stringify(profile));
    }

    function selectProfile(profileId) {
        const profile = ProfileManager.profileById(profileId);
        if (!profile) return;
        root.selectedId = profileId;
        root.draft = root.cloneProfile(profile);
        root.dirty = false;
        root.deleteArmed = false;
    }

    function updateDraft(patch) {
        if (!root.draft) return;
        root.draft = Object.assign({}, root.draft, patch);
        root.dirty = true;
    }

    function draftTab(key) {
        return root.draft?.tabs?.[key] !== false;
    }

    function setDraftTab(key, value) {
        const tabs = Object.assign({}, root.draft?.tabs ?? {}, { [key]: value });
        root.updateDraft({ tabs: tabs });
    }

    function saveDraft(callback) {
        if (!root.draft) return;
        root.busy = true;
        ProfileManager.updateProfile(root.draft.id, root.draft, (updated, exitCode) => {
            root.busy = false;
            if (exitCode === 0 && updated && !updated.error) {
                root.draft = updated;
                root.dirty = false;
                if (callback) callback();
            }
        });
    }

    function applyDraft() {
        root.saveDraft(() => {
            root.busy = true;
            ProfileManager.applyProfile(root.draft.id, (text, exitCode) => {
                root.busy = false;
                if (exitCode === 0) root.closeRequested();
            });
        });
    }

    function createMode() {
        root.busy = true;
        ProfileManager.createProfile("New mode", (profile, exitCode) => {
            root.busy = false;
            if (exitCode === 0 && profile && !profile.error) {
                root.selectedId = profile.id;
                root.draft = profile;
                root.dirty = false;
                ProfileManager.reload();
            }
        });
    }

    function deleteMode() {
        if (!root.draft) return;
        if (ProfileManager.profileList.length <= 1) return;
        if (!root.deleteArmed) {
            root.deleteArmed = true;
            deleteResetTimer.restart();
            return;
        }
        root.busy = true;
        ProfileManager.deleteProfile(root.draft.id, (remaining, exitCode) => {
            root.busy = false;
            root.deleteArmed = false;
            if (exitCode === 0 && remaining && !remaining.error) {
                root.selectedId = remaining.id;
                root.draft = remaining;
                root.dirty = false;
                ProfileManager.reload();
            }
        });
    }

    function browseFolder() {
        pickFolderProcess.running = true;
    }

    function browseImage() {
        pickImageProcess.running = true;
    }

    Connections {
        target: ProfileManager
        function onProfileListChanged() {
            if (ProfileManager.profileList.length === 0) return;
            if (root.selectedId.length === 0 || !ProfileManager.profileById(root.selectedId)) {
                root.selectProfile(ProfileManager.activeId || ProfileManager.profileList[0].id);
                return;
            }
            if (!root.dirty) {
                const profile = ProfileManager.profileById(root.selectedId);
                if (profile) {
                    root.draft = root.cloneProfile(profile);
                }
            }
        }
    }

    Component.onCompleted: {
        if (ProfileManager.profileList.length > 0) {
            root.selectProfile(ProfileManager.activeId || ProfileManager.profileList[0].id);
        }
    }

    Timer {
        id: deleteResetTimer
        interval: 3500
        onTriggered: root.deleteArmed = false
    }

    Process {
        id: pickFolderProcess
        running: false
        command: ["bash", "-c", `kdialog --getexistingdirectory "$HOME/Pictures/Wallpapers"`]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path.length > 0) root.updateDraft({ wallpaperFolder: path });
            }
        }
    }

    Process {
        id: pickImageProcess
        running: false
        command: ["bash", "-c", `kdialog --getopenfilename "$HOME/Pictures/Wallpapers" "Images (*.png *.jpg *.jpeg *.webp *.gif *.avif *.bmp)"`]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path.length > 0) root.updateDraft({ wallpaper: path });
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#00000077"
        z: -2
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        z: -1
        onClicked: root.closeRequested()
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        z: 1
        implicitWidth: Math.min(parent.width - 80, 1240)
        implicitHeight: Math.min(parent.height - 80, 820)
        radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1
        color: Appearance.colors.colLayer0
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.closeRequested();
                event.accepted = true;
            }
        }

        StyledRectangularShadow {
            target: panel
            z: -1
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            z: 0
            onClicked: {}
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: 20
            }
            z: 10
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                MaterialSymbol {
                    text: "palette"
                    iconSize: Appearance.font.pixelSize.huge
                    color: Appearance.colors.colPrimary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: Translation.tr("Desktop modes")
                        color: Appearance.colors.colOnSurface
                        font {
                            weight: Font.Medium
                            pixelSize: Appearance.font.pixelSize.larger
                        }
                    }
                    StyledText {
                        text: Translation.tr("Choose a profile or create your own desktop setup")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }

                IconToolbarButton {
                    implicitHeight: 36
                    text: "close"
                    onClicked: root.closeRequested()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16

                ColumnLayout {
                    Layout.preferredWidth: 360
                    Layout.fillHeight: true
                    spacing: 8

                    RippleButton {
                        Layout.fillWidth: true
                        implicitHeight: 38
                        buttonRadius: Appearance.rounding.small
                        colBackground: Appearance.colors.colPrimaryContainer
                        onClicked: root.createMode()

                        contentItem: RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialSymbol {
                                text: "add"
                                iconSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                            StyledText {
                                text: Translation.tr("New mode")
                                color: Appearance.colors.colOnPrimaryContainer
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                        }
                    }

                    StyledListView {
                        id: profileList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6
                        model: ProfileManager.profileList

                        delegate: RippleButton {
                            id: profileCard
                            required property var modelData

                            width: profileList.width
                            implicitHeight: 88
                            buttonRadius: Appearance.rounding.small
                            toggled: root.selectedId === profileCard.modelData.id
                            colBackground: Appearance.colors.colLayer1
                            colBackgroundToggled: Appearance.colors.colSecondaryContainer
                            onClicked: root.selectProfile(profileCard.modelData.id)

                            contentItem: RowLayout {
                                anchors {
                                    fill: parent
                                    margins: 8
                                }
                                spacing: 10

                                ModePreview {
                                    width: 118
                                    height: 68
                                    radius: Appearance.rounding.small
                                    compact: true
                                    profile: profileCard.modelData
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: profileCard.modelData.name
                                            color: root.selectedId === profileCard.modelData.id
                                                ? Appearance.colors.colOnSecondaryContainer
                                                : Appearance.colors.colOnSurface
                                            font {
                                                weight: Font.Medium
                                                pixelSize: Appearance.font.pixelSize.normal
                                            }
                                            elide: Text.ElideRight
                                        }

                                        MaterialSymbol {
                                            visible: profileCard.modelData.id === ProfileManager.activeId
                                            text: "check_circle"
                                            iconSize: 16
                                            color: root.selectedId === profileCard.modelData.id
                                                ? Appearance.colors.colOnSecondaryContainer
                                                : Appearance.colors.colPrimary
                                        }
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: profileCard.modelData.wallpaperFolder.split("/").filter(Boolean).pop() ?? ""
                                        color: root.selectedId === profileCard.modelData.id
                                            ? Appearance.colors.colOnSecondaryContainer
                                            : Appearance.colors.colSubtext
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        elide: Text.ElideRight
                                    }

                                    RowLayout {
                                        spacing: 4

                                        StyledText {
                                            text: profileCard.modelData.weebPolicy ? "weeb" : "sober"
                                            color: Appearance.colors.colPrimary
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                        }
                                        StyledText {
                                            visible: profileCard.modelData.floatingImages
                                            text: "• floating"
                                            color: Appearance.colors.colSubtext
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    ModePreview {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 220
                        profile: root.draft
                    }

                    StyledText {
                        text: Translation.tr("Name")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                    ToolbarTextField {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        Layout.fillHeight: false
                        text: root.draft?.name ?? ""
                        placeholderText: Translation.tr("Profile name")
                        onEditingFinished: root.updateDraft({ name: text })
                        onAccepted: root.updateDraft({ name: text })
                    }

                    StyledText {
                        text: Translation.tr("Wallpaper folder")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        ToolbarTextField {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            Layout.fillHeight: false
                            text: root.draft?.wallpaperFolder ?? ""
                            placeholderText: "/home/user/Pictures/Wallpapers/mode"
                            onEditingFinished: root.updateDraft({ wallpaperFolder: text })
                            onAccepted: root.updateDraft({ wallpaperFolder: text })
                        }
                        IconToolbarButton {
                            implicitHeight: 36
                            text: "folder_open"
                            onClicked: root.browseFolder()
                        }
                    }

                    StyledText {
                        text: Translation.tr("Wallpaper")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        ToolbarTextField {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            Layout.fillHeight: false
                            text: root.draft?.wallpaper ?? ""
                            placeholderText: "/home/user/Pictures/Wallpapers/mode/wallpaper.jpg"
                            onEditingFinished: root.updateDraft({ wallpaper: text })
                            onAccepted: root.updateDraft({ wallpaper: text })
                        }
                        IconToolbarButton {
                            implicitHeight: 36
                            text: "image"
                            onClicked: root.browseImage()
                        }
                    }

                    StyledText {
                        text: Translation.tr("Desktop style")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        ToggleChip {
                            label: Translation.tr("Weeb shell")
                            iconName: "auto_awesome"
                            value: root.draft?.weebPolicy === true
                            onClicked: root.updateDraft({ weebPolicy: !(root.draft?.weebPolicy === true) })
                        }
                        ToggleChip {
                            label: Translation.tr("Floating images")
                            iconName: "imagesmode"
                            value: root.draft?.floatingImages === true
                            onClicked: root.updateDraft({ floatingImages: !(root.draft?.floatingImages === true) })
                        }
                        ToggleChip {
                            label: "Pokemon"
                            iconName: "pets"
                            value: root.draft?.terminal === "pokemon"
                            onClicked: root.updateDraft({ terminal: "pokemon" })
                        }
                        ToggleChip {
                            label: "CachyOS"
                            iconName: "terminal"
                            value: root.draft?.terminal !== "pokemon"
                            onClicked: root.updateDraft({ terminal: "cachyos" })
                        }
                    }

                    StyledText {
                        text: Translation.tr("Sidebar tabs")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        ToggleChip {
                            label: Translation.tr("AI Chat")
                            iconName: "neurology"
                            value: root.draftTab("ai")
                            onClicked: root.setDraftTab("ai", !root.draftTab("ai"))
                        }
                        ToggleChip {
                            label: Translation.tr("Translator")
                            iconName: "translate"
                            value: root.draftTab("translator")
                            onClicked: root.setDraftTab("translator", !root.draftTab("translator"))
                        }
                        ToggleChip {
                            label: Translation.tr("Anime")
                            iconName: "bookmark_heart"
                            value: root.draftTab("anime")
                            onClicked: root.setDraftTab("anime", !root.draftTab("anime"))
                        }
                        ToggleChip {
                            label: "Reddit"
                            iconName: "dynamic_feed"
                            value: root.draftTab("social")
                            onClicked: root.setDraftTab("social", !root.draftTab("social"))
                        }
                        ToggleChip {
                            label: Translation.tr("Lyrics")
                            iconName: "lyrics"
                            value: root.draftTab("lyrics")
                            onClicked: root.setDraftTab("lyrics", !root.draftTab("lyrics"))
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        RippleButton {
                            implicitHeight: 36
                            horizontalPadding: 14
                            buttonRadius: Appearance.rounding.small
                            enabled: ProfileManager.profileList.length > 1 && !root.busy
                            colBackground: root.deleteArmed ? Appearance.colors.colErrorContainer : Appearance.colors.colLayer2
                            onClicked: root.deleteMode()

                            contentItem: StyledText {
                                anchors.centerIn: parent
                                text: root.deleteArmed ? Translation.tr("Confirm delete") : Translation.tr("Delete")
                                color: root.deleteArmed ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnSurface
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        StyledText {
                            visible: root.busy
                            text: Translation.tr("Applying...")
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                        }

                        RippleButton {
                            implicitHeight: 36
                            horizontalPadding: 14
                            buttonRadius: Appearance.rounding.small
                            enabled: !root.busy
                            onClicked: root.saveDraft()

                            contentItem: StyledText {
                                anchors.centerIn: parent
                                text: Translation.tr("Save")
                                color: Appearance.colors.colOnSurface
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                        }

                        RippleButton {
                            implicitHeight: 36
                            horizontalPadding: 16
                            buttonRadius: Appearance.rounding.small
                            toggled: true
                            enabled: !root.busy
                            onClicked: root.applyDraft()

                            contentItem: StyledText {
                                anchors.centerIn: parent
                                text: Translation.tr("Apply mode")
                                color: Appearance.colors.colOnPrimary
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                        }
                    }
                }
            }
        }
    }

    component ToggleChip: RippleButton {
        id: chip
        required property string label
        required property string iconName
        required property bool value

        implicitHeight: 34
        implicitWidth: chipContent.implicitWidth + 24
        buttonRadius: height / 2
        toggled: value
        colBackground: Appearance.colors.colLayer1
        colBackgroundToggled: Appearance.colors.colSecondaryContainer

        contentItem: RowLayout {
            id: chipContent
            anchors.centerIn: parent
            spacing: 5

            MaterialSymbol {
                text: chip.iconName
                iconSize: 16
                color: chip.value ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant
            }
            StyledText {
                text: chip.label
                color: chip.value ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }
    }
}
