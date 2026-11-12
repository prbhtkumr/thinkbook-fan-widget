import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property alias cfg_minLevel: levelSpin.value
    property string cfg_temperatureInput: "max-all"
    property bool initialized: false

    onCfg_temperatureInputChanged: page.syncCombo(inputBox, cfg_temperatureInput)

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
        page.syncCombo(inputBox, cfg_temperatureInput)
        page.initialized = true
    }

    Kirigami.FormLayout {
        QQC2.SpinBox {
            id: levelSpin
            Kirigami.FormData.label: "Minimum fan level:"
            from: 3
            to: 7
            stepSize: 1
        }

        QQC2.ComboBox {
            id: inputBox
            Layout.fillWidth: true
            Kirigami.FormData.label: "Temperature input:"
            textRole: "label"
            model: [
                { "label": "Maximum core", "value": "max-core" },
                { "label": "Average core", "value": "avg-core" },
                { "label": "Package", "value": "package" },
                { "label": "Maximum of all sensors", "value": "max-all" }
            ]
            onCurrentIndexChanged: {
                if (page.initialized && currentIndex >= 0 && currentIndex < model.length) {
                    cfg_temperatureInput = model[currentIndex]["value"]
                }
            }
        }
    }
}
