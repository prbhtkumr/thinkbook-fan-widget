import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property int fanLevel: -1
    property string fanMode: "off"
    property string fanCurve: ""
    property string fanState: "default"
    property int fanTemp: -1
    property int pinnedLevel: -1
    property int pendingLevel: -1
    property double pendingUntil: 0
    property string lastError: ""
    property int actionSeq: 0
    property int configMinLevel: Plasmoid.configuration.minLevel || 3
    property string configCurveAc: Plasmoid.configuration.curveAc || "auto"
    property string configCurveDefault: Plasmoid.configuration.curveDefault || "auto"
    property string configCurvePowerSave: Plasmoid.configuration.curvePowerSave || "power-save"
    readonly property int minFanLevel: Math.max(3, Math.min(7, configMinLevel))
    readonly property string iconSource: {
        var source = Plasmoid.configuration.iconSource
        return (source === undefined || source === null) ? "../icons/fan.svg" : source
    }
    readonly property bool showIcon: (Plasmoid.configuration.showIcon !== false) && iconSource.trim().length > 0
    readonly property bool showLevel: Plasmoid.configuration.showLevel !== false
    readonly property bool showStatus: Plasmoid.configuration.showStatus !== false
    readonly property bool showTemperature: Plasmoid.configuration.showTemperature !== false
    readonly property int compactColumns: {
        var count = 0
        if (showIcon) {
            count += 1
        }
        if (showLevel) {
            count += 1
        }
        if (showStatus) {
            count += 1
        }
        if (showTemperature) {
            count += 1
        }
        return Plasmoid.formFactor === PlasmaCore.Types.Vertical ? 1 : Math.max(1, count)
    }
    readonly property var levelModel: {
        var levels = []
        for (var i = minFanLevel; i <= 7; i++) {
            levels.push(i)
        }
        return levels
    }

    readonly property string stateCommand: "cat /run/thinkbook-fan/state 2>/dev/null"
    readonly property string pinFile: "/run/thinkbook-fan/pin"
    readonly property int effectiveLevel: pendingLevel >= 0 ? pendingLevel : fanLevel
    readonly property bool pinnedNow: pendingLevel >= 0 || fanMode === "pin"
    readonly property string levelLabel: effectiveLevel >= 0 ? "L" + effectiveLevel : "L?"
    readonly property string modeLabel: {
        if (pinnedNow) {
            return "PIN"
        }
        if (fanMode === "ac") {
            return "AC"
        }
        if (fanMode === "default" || fanMode === "battery") {
            return "BAT"
        }
        if (fanMode === "power-save") {
            return "PWR"
        }
        if (fanMode === "off") {
            return "OFF"
        }
        return fanMode.toUpperCase()
    }
    readonly property string curveLabel: {
        if (fanCurve === "auto") {
            return "Balanced"
        }
        if (fanCurve === "power-save") {
            return "Power Save"
        }
        if (fanCurve === "aggressive") {
            return "Aggressive"
        }
        return ""
    }
    readonly property bool useFahrenheit: {
        var unit = Plasmoid.configuration.temperatureUnit
        if (unit === "fahrenheit") {
            return true
        }
        if (unit === "celsius") {
            return false
        }
        return Qt.locale().measurementSystem === Locale.ImperialUSSystem
    }
    readonly property string tempLabel: {
        if (fanTemp < 0) {
            return "N/A"
        }
        if (useFahrenheit) {
            return Math.round(fanTemp * 9 / 5 + 32) + " °F"
        }
        return Math.round(fanTemp) + " °C"
    }

    function parseState(text) {
        if (!text || text.trim().length === 0) {
            fanLevel = -1
            fanMode = "off"
            fanCurve = ""
            fanState = "default"
            fanTemp = -1
            pinnedLevel = -1
            pendingLevel = -1
            pendingUntil = 0
            return
        }

        try {
            var state = JSON.parse(text)
            fanLevel = (typeof state.level === "number") ? state.level : -1
            fanMode = state.mode || "off"
            fanCurve = state.curve || ""
            fanState = state.state || (state.mode === "power-save" ? "power-save" : (state.ac ? "ac" : "default"))
            fanTemp = (typeof state.temp === "number") ? state.temp : -1
            pinnedLevel = (typeof state.pin === "number") ? state.pin : -1

            if (pendingLevel >= 0 && fanMode === "pin" && pinnedLevel === pendingLevel) {
                pendingLevel = -1
                pendingUntil = 0
            } else if (pendingLevel >= 0 && Date.now() > pendingUntil) {
                pendingLevel = -1
            }
        } catch (error) {
            // Keep the last good state if the file was read mid-write.
        }
    }

    function runCommand(command) {
        actionSeq += 1
        actionSource.connectSource(command + " # " + actionSeq)
    }

    function setLevel(level) {
        level = Math.max(root.minFanLevel, Math.min(7, level))
        pendingLevel = level
        pendingUntil = Date.now() + 7000
        lastError = ""
        runCommand("sh -c 'printf \"%s\" " + level + " > " + pinFile + "'")
    }

    function clearPin() {
        pendingLevel = -1
        pendingUntil = 0
        lastError = ""
        runCommand("rm -f " + pinFile)
    }

    function scrollLevel(delta) {
        var base = pendingLevel
        if (base < 0) {
            base = pinnedLevel
        }
        if (base < 0) {
            base = fanLevel
        }
        if (base < 0) {
            base = minFanLevel
        }
        setLevel(base + delta)
    }

    function writeMinLevel() {
        runCommand("sh -c 'printf \"%s\" " + minFanLevel + " > /run/thinkbook-fan/min-level'")
    }

    function validCurve(name) {
        if (name === "power-save" || name === "aggressive") {
            return name
        }
        return "auto"
    }

    function writeCurveConfig() {
        var ac = validCurve(configCurveAc)
        var def = validCurve(configCurveDefault)
        var ps = validCurve(configCurvePowerSave)
        runCommand("sh -c 'printf \"ac=%s\\ndefault=%s\\npower-save=%s\\n\" \"" + ac + "\" \"" + def + "\" \"" + ps + "\" > /run/thinkbook-fan/curves'")
    }

    function setCurve(curve) {
        if (fanState === "ac") {
            Plasmoid.configuration.curveAc = curve
        } else if (fanState === "power-save") {
            Plasmoid.configuration.curvePowerSave = curve
        } else {
            Plasmoid.configuration.curveDefault = curve
        }
        clearPin()
    }

    Component.onCompleted: {
        Qt.callLater(root.writeMinLevel)
        Qt.callLater(root.writeCurveConfig)
    }
    onConfigMinLevelChanged: writeMinLevel()
    onConfigCurveAcChanged: writeCurveConfig()
    onConfigCurveDefaultChanged: writeCurveConfig()
    onConfigCurvePowerSaveChanged: writeCurveConfig()

    P5Support.DataSource {
        id: stateSource
        engine: "executable"
        connectedSources: [root.stateCommand]
        interval: 2000

        onNewData: (source, data) => {
            if (source !== root.stateCommand) {
                return
            }
            if (!("stdout" in data)) {
                return
            }
            root.parseState(data.stdout || "")
        }
    }

    P5Support.DataSource {
        id: actionSource
        engine: "executable"

        onNewData: (source, data) => {
            if (!("stderr" in data)) {
                return
            }
            if (data.stderr && data.stderr.length > 0) {
                root.lastError = data.stderr.trim()
                root.pendingLevel = -1
                root.pendingUntil = 0
            }
            Qt.callLater(() => actionSource.disconnectSource(source))
        }
    }

    Plasmoid.icon: "cpu"
    Plasmoid.status: fanTemp >= 90 ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus

    toolTipMainText: "ThinkBook fan"
    toolTipSubText: {
        if (effectiveLevel < 0) {
            return "No state from the fan service"
        }
        var parts = ["Level " + effectiveLevel, modeLabel]
        if (!pinnedNow && curveLabel.length > 0) {
            parts.push(curveLabel)
        }
        if (fanTemp >= 0) {
            parts.push(tempLabel)
        }
        parts.push("Scroll to change, click for options")
        return parts.join(", ")
    }

    compactRepresentation: Item {
        id: compact

        Layout.minimumWidth: Math.max(content.implicitWidth, Kirigami.Units.iconSizes.small) + Kirigami.Units.smallSpacing * 2
        Layout.preferredWidth: Layout.minimumWidth
        Layout.maximumWidth: Layout.minimumWidth
        Layout.minimumHeight: Math.max(content.implicitHeight, Kirigami.Units.iconSizes.small) + Kirigami.Units.smallSpacing * 2
        Layout.preferredHeight: Layout.minimumHeight
        Layout.maximumHeight: Layout.minimumHeight

        GridLayout {
            id: content
            anchors.centerIn: parent
            columns: root.compactColumns
            columnSpacing: Kirigami.Units.smallSpacing
            rowSpacing: 0

            Loader {
                visible: root.showIcon
                Layout.preferredWidth: root.showIcon ? Kirigami.Units.iconSizes.small : 0
                Layout.preferredHeight: root.showIcon ? Kirigami.Units.iconSizes.small : 0
                Layout.alignment: Qt.AlignHCenter
                sourceComponent: root.showIcon ? (root.iconSource.indexOf("/") >= 0 ? imageIcon : themeIcon) : null
            }

            PlasmaComponents3.Label {
                visible: root.showLevel
                text: root.levelLabel
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            PlasmaComponents3.Label {
                visible: root.showStatus
                text: root.modeLabel
                font: Kirigami.Theme.smallFont
                opacity: 0.8
                Layout.alignment: Qt.AlignHCenter
            }

            PlasmaComponents3.Label {
                visible: root.showTemperature
                text: root.tempLabel
                font: Kirigami.Theme.smallFont
                opacity: 0.8
                Layout.alignment: Qt.AlignHCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton

            onClicked: root.expanded = !root.expanded

            onWheel: (wheel) => {
                if (wheel.angleDelta.y > 0) {
                    root.scrollLevel(1)
                } else if (wheel.angleDelta.y < 0) {
                    root.scrollLevel(-1)
                }
            }
        }
    }

    fullRepresentation: Item {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.preferredHeight: column.implicitHeight + Kirigami.Units.largeSpacing * 2

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: statusRow.implicitHeight + Kirigami.Units.largeSpacing * 2
                radius: Kirigami.Units.smallSpacing
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06)

                RowLayout {
                    id: statusRow
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.largeSpacing

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: "Level"
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                        }
                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: root.levelLabel
                            font.bold: true
                            font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.6)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: "Mode"
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                        }
                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: root.modeLabel
                            font.bold: true
                            font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.6)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: "Temp"
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                        }
                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: root.tempLabel
                            font.bold: true
                            font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.6)
                        }
                    }
                }
            }

            PlasmaComponents3.Label {
                text: "Curve"
                font.bold: true
                Layout.topMargin: Kirigami.Units.smallSpacing
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Button {
                    id: powerSaveButton
                    Layout.fillWidth: true
                    text: "Power Save"
                    checkable: true
                    checked: !root.pinnedNow && root.fanCurve === "power-save"
                    font.bold: checked

                    Rectangle {
                        anchors.fill: parent
                        radius: Kirigami.Units.smallSpacing
                        color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.3)
                        border.width: 2
                        border.color: Kirigami.Theme.highlightColor
                        visible: powerSaveButton.checked
                    }

                    onClicked: {
                        root.setCurve("power-save")
                        root.expanded = false
                    }
                }

                PlasmaComponents3.Button {
                    id: balancedButton
                    Layout.fillWidth: true
                    text: "Balanced"
                    checkable: true
                    checked: !root.pinnedNow && root.fanCurve === "auto"
                    font.bold: checked

                    Rectangle {
                        anchors.fill: parent
                        radius: Kirigami.Units.smallSpacing
                        color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.3)
                        border.width: 2
                        border.color: Kirigami.Theme.highlightColor
                        visible: balancedButton.checked
                    }

                    onClicked: {
                        root.setCurve("auto")
                        root.expanded = false
                    }
                }

                PlasmaComponents3.Button {
                    id: aggressiveButton
                    Layout.fillWidth: true
                    text: "Aggressive"
                    checkable: true
                    checked: !root.pinnedNow && root.fanCurve === "aggressive"
                    font.bold: checked

                    Rectangle {
                        anchors.fill: parent
                        radius: Kirigami.Units.smallSpacing
                        color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.3)
                        border.width: 2
                        border.color: Kirigami.Theme.highlightColor
                        visible: aggressiveButton.checked
                    }

                    onClicked: {
                        root.setCurve("aggressive")
                        root.expanded = false
                    }
                }
            }

            PlasmaComponents3.Label {
                text: "Manual level"
                font.bold: true
                Layout.topMargin: Kirigami.Units.smallSpacing
            }

            GridLayout {
                Layout.fillWidth: true
                columns: root.levelModel.length
                columnSpacing: Kirigami.Units.smallSpacing
                rowSpacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: root.levelModel

                    PlasmaComponents3.Button {
                        id: levelButton
                        required property int modelData
                        Layout.fillWidth: true
                        text: modelData
                        font.bold: root.effectiveLevel === modelData
                        checkable: true
                        checked: root.effectiveLevel === modelData

                        Rectangle {
                            anchors.fill: parent
                            radius: Kirigami.Units.smallSpacing
                            color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.3)
                            border.width: 2
                            border.color: Kirigami.Theme.highlightColor
                            visible: levelButton.checked
                        }

                        onClicked: {
                            root.setLevel(modelData)
                            root.expanded = false
                        }
                    }
                }
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                visible: root.lastError.length > 0
                text: root.lastError
                wrapMode: Text.WordWrap
                color: Kirigami.Theme.negativeTextColor
                font: Kirigami.Theme.smallFont
            }
        }
    }

    Component {
        id: imageIcon
        Image {
            source: root.iconSource
            width: Kirigami.Units.iconSizes.small
            height: Kirigami.Units.iconSizes.small
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }

    Component {
        id: themeIcon
        Kirigami.Icon {
            source: root.iconSource
            width: Kirigami.Units.iconSizes.small
            height: Kirigami.Units.iconSizes.small
        }
    }
}
