import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property alias cfg_showLevel: showLevelCheck.checked
    property alias cfg_showStatus: showStatusCheck.checked
    property alias cfg_showTemperature: showTemperatureCheck.checked
    property alias cfg_boldStatus: boldStatusCheck.checked
    property alias cfg_boldTemperature: boldTemperatureCheck.checked
    property string cfg_temperatureUnit: "auto"
    property bool initialized: false

    onCfg_temperatureUnitChanged: page.syncCombo(temperatureUnitBox, cfg_temperatureUnit)

    function syncCombo(combo, value) {
        if (!combo) {
            return
        }
        for (var i = 0; i < combo.model.length; i++) {
            if (combo.model[i]["value"] === value) {
                combo.currentIndex = i
                return
            }
        }
    }

    Component.onCompleted: {
        page.syncCombo(temperatureUnitBox, cfg_temperatureUnit)
        page.initialized = true
    }

    Kirigami.FormLayout {
        QQC2.ComboBox {
            id: temperatureUnitBox
            Layout.fillWidth: true
            Kirigami.FormData.label: "Temperature:"
            textRole: "label"
            model: [
                { "label": "System locale", "value": "auto" },
                { "label": "Celsius (°C)", "value": "celsius" },
                { "label": "Fahrenheit (°F)", "value": "fahrenheit" }
            ]
            onCurrentIndexChanged: {
                if (page.initialized && currentIndex >= 0 && currentIndex < model.length) {
                    cfg_temperatureUnit = model[currentIndex]["value"]
                }
            }
        }

        QQC2.Label {
            Kirigami.FormData.isSection: true
            text: "Title items"
        }

        QQC2.CheckBox {
            id: showLevelCheck
            Kirigami.FormData.label: "Level:"
            text: "Show"
        }

        QQC2.CheckBox {
            id: showStatusCheck
            Kirigami.FormData.label: "Status:"
            text: "Show"
        }

        QQC2.CheckBox {
            id: showTemperatureCheck
            Kirigami.FormData.label: "Temperature:"
            text: "Show"
        }

        QQC2.CheckBox {
            id: boldStatusCheck
            Kirigami.FormData.label: "Status text:"
            text: "Bold"
        }

        QQC2.CheckBox {
            id: boldTemperatureCheck
            Kirigami.FormData.label: "Temperature text:"
            text: "Bold"
        }
    }
}
