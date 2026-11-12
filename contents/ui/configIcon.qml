import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.components as PlasmaComponents3

KCM.SimpleKCM {
    property alias cfg_showIcon: showIconCheck.checked
    property alias cfg_iconSource: iconField.text

    Kirigami.FormLayout {
        PlasmaComponents3.CheckBox {
            id: showIconCheck
            Kirigami.FormData.label: "Visibility:"
            text: "Show icon"
        }

        PlasmaComponents3.ComboBox {
            id: iconPreset
            Kirigami.FormData.label: "Preset:"
            textRole: "label"
            model: [
                { "label": "Fan (bundled)", "value": "../icons/fan.svg" },
                { "label": "CPU", "value": "cpu" },
                { "label": "Temperature", "value": "temperature-normal-symbolic" },
                { "label": "System monitor", "value": "utilities-system-monitor" }
            ]
            onActivated: (index) => {
                iconField.text = model[index]["value"]
                showIconCheck.checked = true
            }
        }

        PlasmaComponents3.TextField {
            id: iconField
            Kirigami.FormData.label: "Source:"
            placeholderText: "cpu or ../icons/fan.svg"
        }

        PlasmaComponents3.Label {
            text: "Use a theme icon name or a path to an SVG file. Clear the field or uncheck Show icon to hide it."
            font: Kirigami.Theme.smallFont
            opacity: 0.8
            Layout.fillWidth: true
        }
    }
}
