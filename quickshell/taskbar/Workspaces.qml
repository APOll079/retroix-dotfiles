import Quickshell
import Quickshell.Hyprland
import Quickshell.I3
import QtQuick
import QtQuick.Layouts

import ".."

// Plain raised BarButtons, no box around them; the active one is toggled (sunken, dithered face).
// Bar.qml places it.
RowLayout {
    id: workspaces
    spacing: MenuStyle.gap

     property bool usingHyprland: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")

    // TODO: Improve this functionality
    property var currentWorkspaces: usingHyprland ? Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor && w.monitor.name == taskbar.screen.name).sort((a, b) => a.id - b.id) : I3.workspaces.values.filter(w => w.monitor && w.monitor.name == taskbar.screen.name)


    Repeater {
        model: parent.currentWorkspaces
        //model: Hyprland.workspaces.values.filter(w => w.monitor.name == taskbar.screen.name)
        BarButton {
            id: control
            iconFontValue: ""
            toggledIconFontValue: ""
            label: usingHyprland ? modelData.id : modelData.number
            urgent: modelData.urgent
            isToggled: usingHyprland ? modelData.active : (I3.focusedWorkspace && modelData.number == I3.focusedWorkspace.number)
            onClicked: {
                if(usingHyprland) {
                    Hyprland.dispatch("hl.dsp.focus({ workspace = " + modelData.id + " })");
                }else {
                  I3.dispatch(`workspace ` + modelData.number);
                }
            }
        }
    }
}
