import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols

RowLayout {
    id: root

    property string value: ""
    property color fallbackColor: Kirigami.Theme.textColor
    property bool showAlphaChannel: false
    readonly property color resolvedColor: value.length > 0 ? value : fallbackColor

    signal colorPicked(color color)
    signal resetRequested()

    ColorButton {
        id: colorButton
        color: root.resolvedColor
        showAlphaChannel: root.showAlphaChannel
        dialogTitle: "Choose a color"
        onAccepted: (color) => root.colorPicked(color)

        QQC2.ToolTip.text: root.value.length > 0 ? root.value : "Default color"
        QQC2.ToolTip.visible: hovered
    }

    QQC2.ToolButton {
        icon.name: "edit-undo"
        enabled: root.value.length > 0
        onClicked: root.resetRequested()
        QQC2.ToolTip.text: "Use the default color"
        QQC2.ToolTip.visible: hovered
    }

    onValueChanged: if (colorButton) colorButton.color = root.resolvedColor
}
