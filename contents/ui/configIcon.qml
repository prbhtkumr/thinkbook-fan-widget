import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_showIcon: showIconCheck.checked
    property alias cfg_iconSource: iconField.text

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: showIconCheck
            Kirigami.FormData.label: "Visibility:"
            text: "Show icon"
        }

        QQC2.ComboBox {
            id: iconPreset
            Layout.fillWidth: true
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

        QQC2.TextField {
            id: iconField
            Layout.fillWidth: true
            Kirigami.FormData.label: "Source:"
            placeholderText: "cpu or ../icons/fan.svg"
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: "Use a theme icon name or a path to an SVG file. Clear the field or uncheck Show icon to hide it."
            font: Kirigami.Theme.smallFont
            opacity: 0.8
            wrapMode: Text.WordWrap
        }
    }
}
