import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property alias cfg_minLevel: levelSpin.value
    property string cfg_temperatureInput: "max-all"
    property string cfg_curveAc: "auto"
    property string cfg_curveDefault: "auto"
    property string cfg_curvePowerSave: "power-save"
    property bool initialized: false

    readonly property var curveModel: [
        { "label": "Balanced", "value": "auto" },
        { "label": "Power Save", "value": "power-save" },
        { "label": "Aggressive", "value": "aggressive" }
    ]

    onCfg_temperatureInputChanged: page.syncCombo(inputBox, cfg_temperatureInput)
    onCfg_curveAcChanged: page.syncCombo(curveAcBox, cfg_curveAc)
    onCfg_curveDefaultChanged: page.syncCombo(curveDefaultBox, cfg_curveDefault)
    onCfg_curvePowerSaveChanged: page.syncCombo(curvePowerSaveBox, cfg_curvePowerSave)

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
        page.syncCombo(curveAcBox, cfg_curveAc)
        page.syncCombo(curveDefaultBox, cfg_curveDefault)
        page.syncCombo(curvePowerSaveBox, cfg_curvePowerSave)
        page.initialized = true
    }

    Kirigami.FormLayout {
        QQC2.Label {
            Kirigami.FormData.isSection: true
            text: "Fan level"
        }

        QQC2.SpinBox {
            id: levelSpin
            Kirigami.FormData.label: "Minimum fan level:"
            from: 0
            to: 7
            stepSize: 1
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 26
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            text: "Every curve and manual pin stays at or above this level. Level 0 stops the fan; the service still raises it near the safety limit."
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
        }

        QQC2.Label {
            Kirigami.FormData.isSection: true
            text: "Temperature"
        }

        QQC2.ComboBox {
            id: inputBox
            Layout.preferredWidth: Kirigami.Units.gridUnit * 15
            implicitWidth: Kirigami.Units.gridUnit * 15
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

        QQC2.Label {
            Layout.fillWidth: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 26
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            text: "Sensor used by the curve and the graph."
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
        }

        QQC2.Label {
            Kirigami.FormData.isSection: true
            text: "Curves"
        }

        QQC2.ComboBox {
            id: curveAcBox
            Layout.preferredWidth: Kirigami.Units.gridUnit * 15
            implicitWidth: Kirigami.Units.gridUnit * 15
            Kirigami.FormData.label: "On AC power:"
            textRole: "label"
            model: page.curveModel
            onCurrentIndexChanged: {
                if (page.initialized && currentIndex >= 0 && currentIndex < model.length) {
                    cfg_curveAc = model[currentIndex]["value"]
                }
            }
        }

        QQC2.ComboBox {
            id: curveDefaultBox
            Layout.preferredWidth: Kirigami.Units.gridUnit * 15
            implicitWidth: Kirigami.Units.gridUnit * 15
            Kirigami.FormData.label: "Default:"
            textRole: "label"
            model: page.curveModel
            onCurrentIndexChanged: {
                if (page.initialized && currentIndex >= 0 && currentIndex < model.length) {
                    cfg_curveDefault = model[currentIndex]["value"]
                }
            }
        }

        QQC2.ComboBox {
            id: curvePowerSaveBox
            Layout.preferredWidth: Kirigami.Units.gridUnit * 15
            implicitWidth: Kirigami.Units.gridUnit * 15
            Kirigami.FormData.label: "On power save:"
            textRole: "label"
            model: page.curveModel
            onCurrentIndexChanged: {
                if (page.initialized && currentIndex >= 0 && currentIndex < model.length) {
                    cfg_curvePowerSave = model[currentIndex]["value"]
                }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 26
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            text: "Balanced follows the normal curve. Power Save keeps the fan lower. Aggressive ramps up sooner. The curve is used unless a manual level is pinned."
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
        }
    }
}
