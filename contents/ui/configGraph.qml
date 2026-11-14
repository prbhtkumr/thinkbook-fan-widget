import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property alias cfg_graphDuration: durationSpin.value
    property alias cfg_graphShowRaw: showRawCheck.checked
    property alias cfg_graphShowSmoothed: showSmoothCheck.checked
    property alias cfg_graphShowGuides: showGuidesCheck.checked
    property alias cfg_graphShowPeak: showPeakCheck.checked
    property alias cfg_graphShowLegend: showLegendCheck.checked
    property alias cfg_graphFill: fillCheck.checked
    property string cfg_graphRawStyle: "dashed"
    property string cfg_graphSmoothStyle: "solid"
    property string cfg_graphRawColor: ""
    property string cfg_graphSmoothColor: ""
    property string cfg_graphFillColor: ""
    property string cfg_graphPeakColor: ""
    property string cfg_graphGuideColor: ""
    property bool initialized: false

    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color smoothFallback: Qt.lighter(Kirigami.Theme.highlightColor, 1.4)
    readonly property color rawFallback: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.55)
    readonly property color fillFallback: Qt.rgba(smoothFallback.r, smoothFallback.g, smoothFallback.b, 0.16)
    readonly property color peakFallback: smoothFallback
    readonly property color guideFallback: textColor

    readonly property var styleModel: [
        { "label": "Solid", "value": "solid" },
        { "label": "Dashed", "value": "dashed" },
        { "label": "Dotted", "value": "dotted" }
    ]

    onCfg_graphRawStyleChanged: page.syncCombo(rawStyleBox, cfg_graphRawStyle)
    onCfg_graphSmoothStyleChanged: page.syncCombo(smoothStyleBox, cfg_graphSmoothStyle)

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
        page.syncCombo(rawStyleBox, cfg_graphRawStyle)
        page.syncCombo(smoothStyleBox, cfg_graphSmoothStyle)
        page.initialized = true
    }

    Kirigami.FormLayout {
        QQC2.Label {
            Kirigami.FormData.isSection: true
            text: "History"
        }

        QQC2.SpinBox {
            id: durationSpin
            Kirigami.FormData.label: "Duration (seconds):"
            from: 10
            to: 900
            stepSize: 10
            value: 60
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 26
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            text: "History window for the Graph page."
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }

        QQC2.Label {
            Kirigami.FormData.isSection: true
            text: "Lines"
        }

        RowLayout {
            Kirigami.FormData.label: "Raw line:"
            spacing: Kirigami.Units.largeSpacing

            QQC2.CheckBox {
                id: showRawCheck
                text: "Show"
            }

            QQC2.ComboBox {
                id: rawStyleBox
                Layout.preferredWidth: Kirigami.Units.gridUnit * 15
            implicitWidth: Kirigami.Units.gridUnit * 15
                textRole: "label"
                model: page.styleModel
                onCurrentIndexChanged: {
                    if (page.initialized && currentIndex >= 0 && currentIndex < model.length) {
                        cfg_graphRawStyle = model[currentIndex]["value"]
                    }
                }
            }
        }

        RowLayout {
            Kirigami.FormData.label: "Smoothed line:"
            spacing: Kirigami.Units.largeSpacing

            QQC2.CheckBox {
                id: showSmoothCheck
                text: "Show"
            }

            QQC2.ComboBox {
                id: smoothStyleBox
                Layout.preferredWidth: Kirigami.Units.gridUnit * 15
            implicitWidth: Kirigami.Units.gridUnit * 15
                textRole: "label"
                model: page.styleModel
                onCurrentIndexChanged: {
                    if (page.initialized && currentIndex >= 0 && currentIndex < model.length) {
                        cfg_graphSmoothStyle = model[currentIndex]["value"]
                    }
                }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 26
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            text: "Raw is the selected sensor. Smoothed is the median used by the curve."
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
        }

        QQC2.Label {
            Kirigami.FormData.isSection: true
            text: "Overlays"
        }

        QQC2.CheckBox {
            id: showGuidesCheck
            text: "Show guide lines and labels"
        }

        QQC2.CheckBox {
            id: showPeakCheck
            text: "Show peak line and label"
        }

        QQC2.CheckBox {
            id: showLegendCheck
            text: "Show legend"
        }

        QQC2.CheckBox {
            id: fillCheck
            text: "Fill under smoothed line"
        }

        QQC2.Label {
            Kirigami.FormData.isSection: true
            text: "Graph colors"
        }

        ColorSetting {
            Kirigami.FormData.label: "Raw line:"
            value: page.cfg_graphRawColor
            fallbackColor: page.rawFallback
            showAlphaChannel: true
            onColorPicked: (color) => page.cfg_graphRawColor = color.toString()
            onResetRequested: page.cfg_graphRawColor = ""
        }

        ColorSetting {
            Kirigami.FormData.label: "Smoothed line:"
            value: page.cfg_graphSmoothColor
            fallbackColor: page.smoothFallback
            onColorPicked: (color) => page.cfg_graphSmoothColor = color.toString()
            onResetRequested: page.cfg_graphSmoothColor = ""
        }

        ColorSetting {
            Kirigami.FormData.label: "Area fill:"
            value: page.cfg_graphFillColor
            fallbackColor: page.fillFallback
            showAlphaChannel: true
            onColorPicked: (color) => page.cfg_graphFillColor = color.toString()
            onResetRequested: page.cfg_graphFillColor = ""
        }

        ColorSetting {
            Kirigami.FormData.label: "Peak line:"
            value: page.cfg_graphPeakColor
            fallbackColor: page.peakFallback
            onColorPicked: (color) => page.cfg_graphPeakColor = color.toString()
            onResetRequested: page.cfg_graphPeakColor = ""
        }

        ColorSetting {
            Kirigami.FormData.label: "Guide lines:"
            value: page.cfg_graphGuideColor
            fallbackColor: page.guideFallback
            onColorPicked: (color) => page.cfg_graphGuideColor = color.toString()
            onResetRequested: page.cfg_graphGuideColor = ""
        }
    }
}
