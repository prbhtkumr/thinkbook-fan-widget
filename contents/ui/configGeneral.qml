import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.components as PlasmaComponents3

KCM.SimpleKCM {
    id: page

    property alias cfg_minLevel: levelSpin.value
    property alias cfg_showIcon: showIconCheck.checked
    property alias cfg_iconSource: iconField.text
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
        PlasmaComponents3.SpinBox {
            id: levelSpin
            Kirigami.FormData.label: "Minimum fan level:"
            from: 3
            to: 7
            stepSize: 1
        }

        PlasmaComponents3.ComboBox {
            id: curveAcBox
            Kirigami.FormData.label: "On AC power:"
            textRole: "label"
            model: [
                { "label": "Auto", "value": "auto" },
                { "label": "Power Save", "value": "power-save" },
                { "label": "Aggressive", "value": "aggressive" }
            ]
            onCurrentIndexChanged: {
                if (page.initialized && currentIndex >= 0 && currentIndex < model.length) {
                    cfg_curveAc = model[currentIndex]["value"]
                }
            }
        }

        PlasmaComponents3.ComboBox {
            id: curveDefaultBox
            Kirigami.FormData.label: "Default:"
            textRole: "label"
            model: [
                { "label": "Auto", "value": "auto" },
                { "label": "Power Save", "value": "power-save" },
                { "label": "Aggressive", "value": "aggressive" }
            ]
            onCurrentIndexChanged: {
                if (page.initialized && currentIndex >= 0 && currentIndex < model.length) {
                    cfg_curveDefault = model[currentIndex]["value"]
                }
            }
        }

        PlasmaComponents3.ComboBox {
            id: curvePowerSaveBox
            Kirigami.FormData.label: "On power save:"
            textRole: "label"
            model: [
                { "label": "Auto", "value": "auto" },
                { "label": "Power Save", "value": "power-save" },
                { "label": "Aggressive", "value": "aggressive" }
            ]
            onCurrentIndexChanged: {
                if (page.initialized && currentIndex >= 0 && currentIndex < model.length) {
                    cfg_curvePowerSave = model[currentIndex]["value"]
                }
            }
        }

        PlasmaComponents3.CheckBox {
            id: showIconCheck
            Kirigami.FormData.label: "Icon:"
            text: "Show icon"
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
                showIconCheck.checked = true
            }
        }

        PlasmaComponents3.TextField {
            id: iconField
            Kirigami.FormData.label: "Icon source:"
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
