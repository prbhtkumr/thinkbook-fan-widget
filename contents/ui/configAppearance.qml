import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property alias cfg_showIcon: showIconCheck.checked
    property alias cfg_iconSource: iconField.text
    property alias cfg_showGauge: showGaugeCheck.checked
    property alias cfg_showGaugeLevel: showGaugeLevelCheck.checked
    property alias cfg_showGaugeNumber: showGaugeNumberCheck.checked
    property alias cfg_showGaugeTemp: showGaugeTempCheck.checked
    property alias cfg_boldGauge: boldGaugeCheck.checked
    property alias cfg_showLevel: showLevelCheck.checked
    property alias cfg_boldLevel: boldLevelCheck.checked
    property alias cfg_showStatus: showStatusCheck.checked
    property alias cfg_boldStatus: boldStatusCheck.checked
    property alias cfg_showTemperature: showTemperatureCheck.checked
    property alias cfg_boldTemperature: boldTemperatureCheck.checked

    property string cfg_gaugeBalancedColor: ""
    property string cfg_gaugeAggressiveColor: ""
    property string cfg_gaugePowerSaveColor: ""
    property string cfg_gaugeTempLowColor: ""
    property string cfg_gaugeTempHighColor: ""
    property string cfg_gaugePinColor: ""
    property string cfg_temperatureUnit: "auto"
    property string cfg_gaugeShape: "full"
    property bool initialized: false

    readonly property bool darkTheme: {
        var bg = Kirigami.Theme.backgroundColor
        return (0.2126 * bg.r + 0.7152 * bg.g + 0.0722 * bg.b) < 0.5
    }

    readonly property color gaugeBalancedFallback: Kirigami.Theme.textColor
    readonly property color gaugeAggressiveFallback: darkTheme ? "#ffb74d" : "#a35f00"
    readonly property color gaugePowerSaveFallback: darkTheme ? "#7fdc9c" : "#1d7a3d"
    readonly property color gaugeTempLowFallback: "#5aa0ff"
    readonly property color gaugeTempHighFallback: "#ff5a5a"
    readonly property color gaugePinFallback: Qt.lighter(Kirigami.Theme.highlightColor, 1.4)

    onCfg_temperatureUnitChanged: page.syncCombo(temperatureUnitBox, cfg_temperatureUnit)
    onCfg_gaugeShapeChanged: page.syncCombo(gaugeShapeBox, cfg_gaugeShape)

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
        page.syncCombo(gaugeShapeBox, cfg_gaugeShape)
        page.initialized = true
    }

    Kirigami.FormLayout {
        QQC2.Label {
            Kirigami.FormData.isSection: true
            text: "Units"
        }

        QQC2.ComboBox {
            id: temperatureUnitBox
            Layout.preferredWidth: Kirigami.Units.gridUnit * 15
            implicitWidth: Kirigami.Units.gridUnit * 15
            Kirigami.FormData.label: "Temperature unit:"
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
            text: "Gauge"
        }

        RowLayout {
            Kirigami.FormData.label: "Level gauge:"
            spacing: Kirigami.Units.largeSpacing

            QQC2.CheckBox {
                id: showGaugeCheck
                text: "Show"
            }

            QQC2.CheckBox {
                id: boldGaugeCheck
                text: "Bold"
            }
        }

        QQC2.ComboBox {
            id: gaugeShapeBox
            Layout.preferredWidth: Kirigami.Units.gridUnit * 15
            implicitWidth: Kirigami.Units.gridUnit * 15
            Kirigami.FormData.label: "Gauge shape:"
            textRole: "label"
            model: [
                { "label": "Full circle", "value": "full" },
                { "label": "Arc", "value": "arc" }
            ]
            onCurrentIndexChanged: {
                if (page.initialized && currentIndex >= 0 && currentIndex < model.length) {
                    cfg_gaugeShape = model[currentIndex]["value"]
                }
            }
        }

        RowLayout {
            Kirigami.FormData.label: "Gauge parts:"
            spacing: Kirigami.Units.largeSpacing

            QQC2.CheckBox {
                id: showGaugeLevelCheck
                text: "Level lines"
            }

            QQC2.CheckBox {
                id: showGaugeNumberCheck
                text: "Number"
            }

            QQC2.CheckBox {
                id: showGaugeTempCheck
                text: "Temp line"
            }
        }

        QQC2.Label {
            Kirigami.FormData.isSection: true
            text: "Gauge colors"
        }

        ColorSetting {
            Kirigami.FormData.label: "Balanced:"
            value: page.cfg_gaugeBalancedColor
            fallbackColor: page.gaugeBalancedFallback
            onColorPicked: (color) => page.cfg_gaugeBalancedColor = color.toString()
            onResetRequested: page.cfg_gaugeBalancedColor = ""
        }

        ColorSetting {
            Kirigami.FormData.label: "Aggressive:"
            value: page.cfg_gaugeAggressiveColor
            fallbackColor: page.gaugeAggressiveFallback
            onColorPicked: (color) => page.cfg_gaugeAggressiveColor = color.toString()
            onResetRequested: page.cfg_gaugeAggressiveColor = ""
        }

        ColorSetting {
            Kirigami.FormData.label: "Power save:"
            value: page.cfg_gaugePowerSaveColor
            fallbackColor: page.gaugePowerSaveFallback
            onColorPicked: (color) => page.cfg_gaugePowerSaveColor = color.toString()
            onResetRequested: page.cfg_gaugePowerSaveColor = ""
        }

        ColorSetting {
            Kirigami.FormData.label: "Temp low:"
            value: page.cfg_gaugeTempLowColor
            fallbackColor: page.gaugeTempLowFallback
            onColorPicked: (color) => page.cfg_gaugeTempLowColor = color.toString()
            onResetRequested: page.cfg_gaugeTempLowColor = ""
        }

        ColorSetting {
            Kirigami.FormData.label: "Temp high:"
            value: page.cfg_gaugeTempHighColor
            fallbackColor: page.gaugeTempHighFallback
            onColorPicked: (color) => page.cfg_gaugeTempHighColor = color.toString()
            onResetRequested: page.cfg_gaugeTempHighColor = ""
        }

        ColorSetting {
            Kirigami.FormData.label: "Pin marker:"
            value: page.cfg_gaugePinColor
            fallbackColor: page.gaugePinFallback
            onColorPicked: (color) => page.cfg_gaugePinColor = color.toString()
            onResetRequested: page.cfg_gaugePinColor = ""
        }

        QQC2.Label {
            Kirigami.FormData.isSection: true
            text: "Title text"
        }

        RowLayout {
            Kirigami.FormData.label: "Level text:"
            spacing: Kirigami.Units.largeSpacing

            QQC2.CheckBox {
                id: showLevelCheck
                text: "Show"
            }

            QQC2.CheckBox {
                id: boldLevelCheck
                text: "Bold"
            }
        }

        RowLayout {
            Kirigami.FormData.label: "Status:"
            spacing: Kirigami.Units.largeSpacing

            QQC2.CheckBox {
                id: showStatusCheck
                text: "Show"
            }

            QQC2.CheckBox {
                id: boldStatusCheck
                text: "Bold"
            }
        }

        RowLayout {
            Kirigami.FormData.label: "Temperature:"
            spacing: Kirigami.Units.largeSpacing

            QQC2.CheckBox {
                id: showTemperatureCheck
                text: "Show"
            }

            QQC2.CheckBox {
                id: boldTemperatureCheck
                text: "Bold"
            }
        }

        QQC2.Label {
            Kirigami.FormData.isSection: true
            text: "Icon"
        }

        QQC2.CheckBox {
            id: showIconCheck
            Kirigami.FormData.label: "Visibility:"
            text: "Show icon"
        }

        QQC2.TextField {
            id: iconField
            Layout.preferredWidth: Kirigami.Units.gridUnit * 18
            Layout.maximumWidth: Kirigami.Units.gridUnit * 18
            Kirigami.FormData.label: "Source:"
            placeholderText: "Theme icon name or /path/to/icon.svg"
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 26
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            text: "Use a theme icon name or a path to an SVG file. Clear the field or uncheck Show icon to hide it."
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
        }
    }
}
