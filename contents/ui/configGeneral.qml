import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.components as PlasmaComponents3

KCM.SimpleKCM {
    property alias cfg_minLevel: levelSpin.value
    property alias cfg_iconSource: iconField.text

    Kirigami.FormLayout {
        PlasmaComponents3.SpinBox {
            id: levelSpin
            Kirigami.FormData.label: "Minimum fan level:"
            from: 3
            to: 7
            stepSize: 1
        }

        PlasmaComponents3.ComboBox {
            id: iconPreset
            Kirigami.FormData.label: "Icon preset:"
            textRole: "label"
            model: [
                { "label": "Fan (bundled)", "value": "../icons/fan.svg" },
                { "label": "CPU", "value": "cpu" },
                { "label": "Temperature", "value": "temperature-normal-symbolic" },
                { "label": "System monitor", "value": "utilities-system-monitor" }
            ]
            onActivated: (index) => {
                iconField.text = model[index]["value"]
            }
        }

        PlasmaComponents3.TextField {
            id: iconField
            Kirigami.FormData.label: "Icon:"
            placeholderText: "cpu or ../icons/fan.svg"
        }

        PlasmaComponents3.Label {
            text: "Use a theme icon name or a path to an SVG file."
            font: Kirigami.Theme.smallFont
            opacity: 0.8
            Layout.fillWidth: true
        }
    }
}
