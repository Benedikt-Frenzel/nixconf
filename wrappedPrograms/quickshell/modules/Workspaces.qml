import QtQuick 2.15
import QtQuick.Layouts 1.15
import Quickshell.Hyprland

ColumnLayout {
    id: workspacesColumn
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 10

    Repeater {
        model: Hyprland.workspaces
        delegate: Rectangle {
            implicitHeight: 22
            implicitWidth: 22
            radius: 6
            color: modelData.focused ? "#83a598" : (modelData.active ? "#83a598" : "#3c3836")

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                radius: 100
                color: modelData.focused ? "#282828" : modelData.urgent ? "#fb4934" : "#ebdbb2"

                implicitHeight: 10
                implicitWidth: 10
            }

            MouseArea {
                anchors.fill: parent
                onClicked: modelData.activate()
                hoverEnabled: true
                onEntered: parent.opacity = 0.9
                onExited: parent.opacity = 1.0
            }
        }
    }
}
