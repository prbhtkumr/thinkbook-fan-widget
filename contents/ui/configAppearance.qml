import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.components as PlasmaComponents3

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
        PlasmaComponents3.ComboBox {
            id: temperatureUnitBox
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

        PlasmaComponents3.Label {
            Kirigami.FormData.isSection: true
            text: "Title items"
        }

        PlasmaComponents3.CheckBox {
            id: showLevelCheck
            Kirigami.FormData.label: "Level:"
            text: "Show"
        }

        PlasmaComponents3.CheckBox {
            id: showStatusCheck
            Kirigami.FormData.label: "Status:"
            text: "Show"
        }

        PlasmaComponents3.CheckBox {
            id: showTemperatureCheck
            Kirigami.FormData.label: "Temperature:"
            text: "Show"
        }

        PlasmaComponents3.CheckBox {
            id: boldStatusCheck
            Kirigami.FormData.label: "Status text:"
            text: "Bold"
        }

        PlasmaComponents3.CheckBox {
            id: boldTemperatureCheck
            Kirigami.FormData.label: "Temperature text:"
            text: "Bold"
        }
    }
}
