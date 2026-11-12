import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property string cfg_curveAc: "auto"
    property string cfg_curveDefault: "auto"
    property string cfg_curvePowerSave: "power-save"
    property bool initialized: false

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
        page.syncCombo(curveAcBox, cfg_curveAc)
        page.syncCombo(curveDefaultBox, cfg_curveDefault)
        page.syncCombo(curvePowerSaveBox, cfg_curvePowerSave)
        page.initialized = true
    }

    Kirigami.FormLayout {
        QQC2.ComboBox {
            id: curveAcBox
            Layout.fillWidth: true
            Kirigami.FormData.label: "On AC power:"
            textRole: "label"
            model: [
                { "label": "Balanced", "value": "auto" },
                { "label": "Power Save", "value": "power-save" },
                { "label": "Aggressive", "value": "aggressive" }
            ]
            onCurrentIndexChanged: {
                if (page.initialized && currentIndex >= 0 && currentIndex < model.length) {
                    cfg_curveAc = model[currentIndex]["value"]
                }
            }
        }

        QQC2.ComboBox {
            id: curveDefaultBox
            Layout.fillWidth: true
            Kirigami.FormData.label: "Default:"
            textRole: "label"
            model: [
                { "label": "Balanced", "value": "auto" },
                { "label": "Power Save", "value": "power-save" },
                { "label": "Aggressive", "value": "aggressive" }
            ]
            onCurrentIndexChanged: {
                if (page.initialized && currentIndex >= 0 && currentIndex < model.length) {
                    cfg_curveDefault = model[currentIndex]["value"]
                }
            }
        }

        QQC2.ComboBox {
            id: curvePowerSaveBox
            Layout.fillWidth: true
            Kirigami.FormData.label: "On power save:"
            textRole: "label"
            model: [
                { "label": "Balanced", "value": "auto" },
                { "label": "Power Save", "value": "power-save" },
                { "label": "Aggressive", "value": "aggressive" }
            ]
            onCurrentIndexChanged: {
                if (page.initialized && currentIndex >= 0 && currentIndex < model.length) {
                    cfg_curvePowerSave = model[currentIndex]["value"]
                }
            }
        }
    }
}
