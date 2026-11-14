import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
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
    property string configTemperatureInput: Plasmoid.configuration.temperatureInput || "max-all"
    property var tempHistory: []
    property int historyLimit: 1000
    property int lastHistoryUpdated: 0
    property var graphCanvasItem: null
    readonly property int graphDuration: Math.max(10, Math.min(900, Plasmoid.configuration.graphDuration || 60))
    readonly property color graphAccentColor: Qt.lighter(Kirigami.Theme.highlightColor, 1.4)
    readonly property bool graphShowRaw: Plasmoid.configuration.graphShowRaw !== false
    readonly property bool graphShowSmoothed: Plasmoid.configuration.graphShowSmoothed !== false
    readonly property bool graphShowGuides: Plasmoid.configuration.graphShowGuides !== false
    readonly property bool graphShowPeak: Plasmoid.configuration.graphShowPeak !== false
    readonly property bool graphShowLegend: Plasmoid.configuration.graphShowLegend !== false
    readonly property bool graphFill: Plasmoid.configuration.graphFill === true
    readonly property string graphRawStyle: validGraphStyle(Plasmoid.configuration.graphRawStyle, "dashed")
    readonly property string graphSmoothStyle: validGraphStyle(Plasmoid.configuration.graphSmoothStyle, "solid")
    readonly property int minFanLevel: Math.max(3, Math.min(7, configMinLevel))
    readonly property string iconSource: {
        var source = Plasmoid.configuration.iconSource
        return (source === undefined || source === null) ? "../icons/fan.svg" : source
    }
    readonly property bool showIcon: (Plasmoid.configuration.showIcon !== false) && iconSource.trim().length > 0
    readonly property bool showGaugeLevel: Plasmoid.configuration.showGaugeLevel !== false
    readonly property bool showGaugeNumber: Plasmoid.configuration.showGaugeNumber !== false
    readonly property bool showGaugeTemp: Plasmoid.configuration.showGaugeTemp !== false
    readonly property bool showGauge: (Plasmoid.configuration.showGauge !== false) && (showGaugeLevel || showGaugeNumber || showGaugeTemp)
    readonly property string gaugeShape: Plasmoid.configuration.gaugeShape === "arc" ? "arc" : "full"
    readonly property bool showLevel: Plasmoid.configuration.showLevel === true
    readonly property bool showStatus: Plasmoid.configuration.showStatus !== false
    readonly property bool showTemperature: Plasmoid.configuration.showTemperature !== false
    readonly property bool boldStatus: Plasmoid.configuration.boldStatus === true
    readonly property bool boldTemperature: Plasmoid.configuration.boldTemperature === true
    readonly property bool boldGauge: Plasmoid.configuration.boldGauge !== false
    readonly property bool boldLevel: Plasmoid.configuration.boldLevel !== false
    readonly property bool darkTheme: {
        var bg = Kirigami.Theme.backgroundColor
        return (0.2126 * bg.r + 0.7152 * bg.g + 0.0722 * bg.b) < 0.5
    }
    readonly property color gaugeLevelColor: {
        if (fanCurve === "aggressive") {
            return darkTheme ? "#ffb74d" : "#a35f00"
        }
        if (fanCurve === "power-save") {
            return darkTheme ? "#7fdc9c" : "#1d7a3d"
        }
        return Kirigami.Theme.textColor
    }
    readonly property int compactColumns: {
        var count = 0
        if (showIcon) {
            count += 1
        }
        if (showGauge) {
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
    function tempUnitLabel(celsius) {
        if (useFahrenheit) {
            return Math.round(celsius * 9 / 5 + 32) + " °F"
        }
        return Math.round(celsius) + " °C"
    }
    readonly property string tempLabel: fanTemp < 0 ? "N/A" : tempUnitLabel(fanTemp)

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

            if (typeof state.temp === "number") {
                var stamp = state.updated || 0
                if (stamp !== lastHistoryUpdated) {
                    lastHistoryUpdated = stamp
                    var controlTemp = (typeof state.control === "number") ? state.control : state.temp
                    var history = tempHistory.slice()
                    var cutoff = stamp - graphDuration
                    while (history.length > 0 && history[0].t < cutoff) {
                        history.shift()
                    }
                    history.push({ "t": stamp, "raw": state.temp, "control": controlTemp })
                    while (history.length > historyLimit) {
                        history.shift()
                    }
                    tempHistory = history
                    if (graphCanvasItem) {
                        graphCanvasItem.requestPaint()
                    }
                }
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

    function validInput(name) {
        if (name === "max-core" || name === "avg-core" || name === "package") {
            return name
        }
        return "max-all"
    }

    function writeTemperatureInput() {
        var mode = validInput(configTemperatureInput)
        runCommand("sh -c 'printf \"%s\" " + mode + " > /run/thinkbook-fan/input'")
    }

    function resetHistory() {
        tempHistory = []
        lastHistoryUpdated = 0
        refreshGraph()
    }

    function refreshGraph() {
        if (graphCanvasItem) {
            graphCanvasItem.requestPaint()
        }
    }

    function validCurve(name) {
        if (name === "power-save" || name === "aggressive") {
            return name
        }
        return "auto"
    }

    function validGraphStyle(value, fallback) {
        if (value === "solid" || value === "dashed" || value === "dotted") {
            return value
        }
        return fallback
    }

    function legendSegments(style) {
        if (style === "solid") {
            return [{ "width": 14, "height": 2, "radius": 0 }]
        }
        if (style === "dashed") {
            return [
                { "width": 4, "height": 2, "radius": 0 },
                { "width": 4, "height": 2, "radius": 0 },
                { "width": 4, "height": 2, "radius": 0 }
            ]
        }
        return [
            { "width": 2, "height": 2, "radius": 1 },
            { "width": 2, "height": 2, "radius": 1 },
            { "width": 2, "height": 2, "radius": 1 },
            { "width": 2, "height": 2, "radius": 1 }
        ]
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
        Qt.callLater(root.writeTemperatureInput)
    }
    onConfigMinLevelChanged: writeMinLevel()
    onConfigCurveAcChanged: writeCurveConfig()
    onConfigCurveDefaultChanged: writeCurveConfig()
    onConfigCurvePowerSaveChanged: writeCurveConfig()
    onConfigTemperatureInputChanged: {
        writeTemperatureInput()
        resetHistory()
    }
    onGraphDurationChanged: {
        var cutoff = lastHistoryUpdated - graphDuration
        var trimmed = []
        for (var i = 0; i < tempHistory.length; ++i) {
            if (tempHistory[i].t >= cutoff) {
                trimmed.push(tempHistory[i])
            }
        }
        tempHistory = trimmed
        refreshGraph()
    }
    onGraphShowRawChanged: refreshGraph()
    onGraphShowSmoothedChanged: refreshGraph()
    onGraphShowGuidesChanged: refreshGraph()
    onGraphShowPeakChanged: refreshGraph()
    onGraphShowLegendChanged: refreshGraph()
    onGraphFillChanged: refreshGraph()
    onGraphRawStyleChanged: refreshGraph()
    onGraphSmoothStyleChanged: refreshGraph()

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
        if (pinnedNow) {
            parts.push("Scroll to change, middle click to resume the curve")
        } else {
            parts.push("Scroll to change, click for options")
        }
        return parts.join(", ")
    }

    compactRepresentation: Item {
        id: compact

        Layout.minimumWidth: Math.max(content.implicitWidth, Kirigami.Units.iconSizes.small)
        Layout.preferredWidth: Layout.minimumWidth
        Layout.maximumWidth: Layout.minimumWidth
        Layout.minimumHeight: Kirigami.Units.iconSizes.small
        Layout.preferredHeight: Kirigami.Units.gridUnit + Kirigami.Units.smallSpacing * 3

        GridLayout {
            id: content
            anchors.fill: parent
            columns: root.compactColumns
            columnSpacing: Kirigami.Units.smallSpacing
            rowSpacing: 0

            Loader {
                visible: root.showIcon
                Layout.preferredWidth: root.showIcon ? Kirigami.Units.iconSizes.small : 0
                Layout.preferredHeight: root.showIcon ? Kirigami.Units.iconSizes.small : 0
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                sourceComponent: root.showIcon ? (root.iconSource.indexOf("/") >= 0 ? imageIcon : themeIcon) : null
            }

            Item {
                id: levelGauge
                visible: root.showGauge
                Layout.preferredWidth: root.showGauge ? gaugeSize : 0
                Layout.preferredHeight: root.showGauge ? gaugeSize : 0
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter

                readonly property int gaugeSize: Math.max(Kirigami.Units.iconSizes.small, Math.min(compact.height, Kirigami.Units.gridUnit * 2))
                readonly property int partCount: (root.showGaugeLevel ? 1 : 0) + (root.showGaugeNumber ? 1 : 0) + (root.showGaugeTemp ? 1 : 0)
                readonly property real ringWidth: partCount >= 3 ? 1.8 : partCount === 2 ? 2.4 : 3.2
                readonly property real ringGap: partCount >= 3 ? 3.5 : partCount === 2 ? 4.0 : 2.4
                readonly property int numberSize: Math.max(8, Math.round(gaugeSize * (partCount >= 3 ? 0.36 : partCount === 2 ? 0.46 : 0.58)))
                readonly property real startAngle: root.gaugeShape === "arc" ? Math.PI * 0.75 : Math.PI / 2
                readonly property real sweepAngle: root.gaugeShape === "arc" ? Math.PI * 1.5 : Math.PI * 2
                property real shownLevel: root.effectiveLevel >= 0 ? root.effectiveLevel : root.minFanLevel
                property real shownTemp: root.fanTemp >= 0 ? root.fanTemp : 30

                Behavior on shownLevel {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on shownTemp {
                    NumberAnimation {
                        duration: 420
                        easing.type: Easing.OutCubic
                    }
                }

                onShownLevelChanged: if (gaugeCanvas) gaugeCanvas.requestPaint()
                onShownTempChanged: if (gaugeCanvas) gaugeCanvas.requestPaint()

                Canvas {
                    id: gaugeCanvas
                    anchors.fill: parent
                    Component.onCompleted: Qt.callLater(requestPaint)
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        if (width <= 0 || height <= 0) {
                            return;
                        }

                        var cx = width / 2;
                        var cy = height / 2;
                        var outerR = Math.min(width, height) / 2 - 0.9;
                        var innerR = outerR - levelGauge.ringGap;
                        var textColor = Kirigami.Theme.textColor;
                        var start = levelGauge.startAngle;
                        var sweep = levelGauge.sweepAngle;
                        var hasLevel = root.effectiveLevel >= 0;
                        var hasTemp = root.fanTemp >= 0;
                        var drawLevel = root.showGaugeLevel;
                        var drawTemp = root.showGaugeTemp;
                        if (!drawLevel && !drawTemp) {
                            return;
                        }
                        var ringWidth = levelGauge.ringWidth;

                        var tempColor = function(c) {
                            var t = Math.max(0, Math.min(1, (c - 30) / 70));
                            var r = 90 + (255 - 90) * t;
                            var g = 160 + (90 - 160) * t;
                            var b = 255 + (90 - 255) * t;
                            return Qt.rgba(r / 255, g / 255, b / 255, 1);
                        };

                        if (drawTemp) {
                            ctx.lineCap = levelGauge.sweepAngle < Math.PI * 2 ? "round" : "butt";
                            ctx.lineWidth = ringWidth;
                            ctx.strokeStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.25);
                            ctx.beginPath();
                            ctx.arc(cx, cy, outerR, start, start + sweep, false);
                            ctx.stroke();
                        }

                        if (drawTemp && hasTemp) {
                            var tfrac = Math.max(0, Math.min(1, (levelGauge.shownTemp - 30) / 70));
                            if (tfrac > 0.001) {
                                var steps = Math.max(2, Math.round(tfrac * 48));
                                ctx.lineCap = "butt";
                                for (var i = 0; i < steps; ++i) {
                                    var a0 = start + sweep * tfrac * (i / steps);
                                    var a1 = start + sweep * tfrac * ((i + 1) / steps);
                                    var mid = 30 + 70 * tfrac * ((i + 0.5) / steps);
                                    ctx.strokeStyle = tempColor(mid);
                                    ctx.beginPath();
                                    ctx.arc(cx, cy, outerR, a0, a1, false);
                                    ctx.stroke();
                                }
                            }
                        }

                        if (drawLevel) {
                            var levelCount = 7 - root.minFanLevel + 1;
                            var segSweep = sweep / levelCount;
                            var gapAngle = Math.PI / 10;
                            var filled = hasLevel ? Math.max(0, Math.min(levelCount, levelGauge.shownLevel - root.minFanLevel + 1)) : 0;
                            var levelWidth = ringWidth + 0.4;
                            ctx.lineCap = "butt";
                            ctx.lineWidth = levelWidth;
                            for (var s = 0; s < levelCount; ++s) {
                                var segStart = start + s * segSweep + gapAngle / 2;
                                var segEnd = start + (s + 1) * segSweep - gapAngle / 2;
                                var segFill = Math.max(0, Math.min(1, filled - s));
                                ctx.strokeStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.25);
                                ctx.beginPath();
                                ctx.arc(cx, cy, innerR, segStart, segEnd, false);
                                ctx.stroke();
                                if (segFill > 0.001) {
                                    ctx.strokeStyle = root.gaugeLevelColor;
                                    ctx.beginPath();
                                    ctx.arc(cx, cy, innerR, segStart, segStart + (segEnd - segStart) * segFill, false);
                                    ctx.stroke();
                                }
                            }
                        }
                    }
                }

                Timer {
                    interval: 200
                    running: true
                    repeat: false
                    onTriggered: gaugeCanvas.requestPaint()
                }

                PlasmaComponents3.Label {
                    anchors.centerIn: parent
                    visible: root.showGaugeNumber
                    text: root.effectiveLevel >= 0 ? root.effectiveLevel : "?"
                    color: root.gaugeLevelColor
                    font.pixelSize: levelGauge.numberSize
                    font.bold: root.boldGauge || levelGauge.partCount < 3
                }

                Rectangle {
                    visible: root.pinnedNow
                    anchors.top: parent.top
                    anchors.right: parent.right
                    width: 5
                    height: 5
                    radius: 2.5
                    color: root.graphAccentColor
                    border.width: 1
                    border.color: Kirigami.Theme.backgroundColor
                }
            }

            PlasmaComponents3.Label {
                visible: root.showLevel
                text: root.levelLabel
                font.bold: root.boldLevel
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            }

            PlasmaComponents3.Label {
                visible: root.showStatus
                text: root.modeLabel
                font.family: Kirigami.Theme.smallFont.family
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.bold: root.boldStatus
                opacity: root.boldStatus ? 1.0 : 0.8
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            }

            PlasmaComponents3.Label {
                visible: root.showTemperature
                text: root.tempLabel
                font.family: Kirigami.Theme.smallFont.family
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.bold: root.boldTemperature
                opacity: root.boldTemperature ? 1.0 : 0.8
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton

            onClicked: (mouse) => {
                if (mouse.button === Qt.MiddleButton) {
                    root.clearPin()
                    return
                }
                root.expanded = !root.expanded
            }

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
        implicitWidth: Kirigami.Units.gridUnit * 20
        implicitHeight: Kirigami.Units.gridUnit * 15
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.minimumWidth: Kirigami.Units.gridUnit * 17
        Layout.preferredHeight: Kirigami.Units.gridUnit * 15
        Layout.minimumHeight: Kirigami.Units.gridUnit * 12

        ColumnLayout {
            id: outer
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing
            clip: true

            Item {
                id: pager
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                Layout.maximumWidth: outer.width
                clip: true

                readonly property int pageCount: 2
                readonly property int pageGap: Kirigami.Units.largeSpacing
                readonly property int currentIndex: Math.max(0, Math.min(pageCount - 1, Math.round(position)))
                property real position: 0
                property real dragStart: 0

                function goTo(index) {
                    position = Math.max(0, Math.min(pageCount - 1, index))
                }

                onCurrentIndexChanged: {
                    if (currentIndex === 1 && root.graphCanvasItem) {
                        root.graphCanvasItem.requestPaint()
                    }
                }

                ColumnLayout {
                    id: controlPage
                    width: pager.width
                    height: pager.height
                    x: -pager.position * (pager.width + pager.pageGap)
                    spacing: Kirigami.Units.smallSpacing

                    Behavior on x {
                        enabled: !pagerDrag.active
                        NumberAnimation {
                            duration: Kirigami.Units.shortDuration
                            easing.type: Easing.OutCubic
                        }
                    }

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
                        Layout.preferredWidth: 0
                        Layout.minimumWidth: 0
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
                        Layout.preferredWidth: 0
                        Layout.minimumWidth: 0
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
                        Layout.preferredWidth: 0
                        Layout.minimumWidth: 0
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
                    Layout.minimumWidth: 0
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
                    Layout.minimumWidth: 0
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
                    Layout.minimumWidth: 0
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
                        Layout.minimumWidth: 0
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

            Item {
                Layout.fillHeight: true
            }
                }

                ColumnLayout {
                    id: graphPage
                    width: pager.width
                    height: pager.height
                    x: (1 - pager.position) * (pager.width + pager.pageGap)
                    spacing: Kirigami.Units.smallSpacing

                    Behavior on x {
                        enabled: !pagerDrag.active
                        NumberAnimation {
                            duration: Kirigami.Units.shortDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    Canvas {
                        id: graphCanvas
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Component.onCompleted: root.graphCanvasItem = graphCanvas
                        Component.onDestruction: {
                            if (root.graphCanvasItem === graphCanvas) {
                                root.graphCanvasItem = null
                            }
                        }
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 7
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            var w = width;
                            var h = height;
                            if (w <= 0 || h <= 0) {
                                return;
                            }

                            var textColor = Kirigami.Theme.textColor;
                            var minC = 30;
                            var maxC = 100;
                            var padLeft = root.graphShowGuides ? 36 : 8;
                            var padRight = 8;
                            var padTop = 8;
                            var padBottom = 4;
                            var plotW = Math.max(1, w - padLeft - padRight);
                            var plotH = Math.max(1, h - padTop - padBottom);
                            var yFor = function(c) {
                                return padTop + plotH - ((c - minC) / (maxC - minC)) * plotH;
                            };

                            var drawStyledLine = function(points, style, width, dash, gap) {
                                if (points.length < 2) {
                                    return;
                                }
                                ctx.lineWidth = width;
                                if (style === "solid") {
                                    ctx.lineCap = "round";
                                    ctx.beginPath();
                                    for (var p = 0; p < points.length; ++p) {
                                        if (p === 0) {
                                            ctx.moveTo(points[p].x, points[p].y);
                                        } else {
                                            ctx.lineTo(points[p].x, points[p].y);
                                        }
                                    }
                                    ctx.stroke();
                                    return;
                                }
                                var dotted = style === "dotted";
                                var onLength = dotted ? 1 : dash;
                                var offLength = gap;
                                var drawing = true;
                                var remaining = onLength;
                                ctx.lineCap = dotted ? "round" : "butt";
                                ctx.beginPath();
                                for (var i = 1; i < points.length; ++i) {
                                    var x0 = points[i - 1].x;
                                    var y0 = points[i - 1].y;
                                    var x1 = points[i].x;
                                    var y1 = points[i].y;
                                    var dx = x1 - x0;
                                    var dy = y1 - y0;
                                    var len = Math.sqrt(dx * dx + dy * dy);
                                    if (len <= 0.001) {
                                        continue;
                                    }
                                    var ux = dx / len;
                                    var uy = dy / len;
                                    var pos = 0;
                                    while (pos < len) {
                                        var step = Math.min(remaining, len - pos);
                                        if (drawing) {
                                            ctx.moveTo(x0 + ux * pos, y0 + uy * pos);
                                            ctx.lineTo(x0 + ux * (pos + step), y0 + uy * (pos + step));
                                        }
                                        pos += step;
                                        remaining -= step;
                                        if (remaining <= 0.001) {
                                            drawing = !drawing;
                                            remaining = drawing ? onLength : offLength;
                                        }
                                    }
                                }
                                ctx.stroke();
                            };

                            var drawDashedHorizontal = function(y, dash, gap) {
                                var x = padLeft;
                                while (x < w - padRight) {
                                    ctx.moveTo(x, y);
                                    ctx.lineTo(Math.min(w - padRight, x + dash), y);
                                    x += dash + gap;
                                }
                                ctx.stroke();
                            };

                            if (root.graphShowGuides) {
                                var guides = [40, 60, 80, 100];
                                ctx.font = "10px sans-serif";
                                ctx.textAlign = "right";
                                ctx.textBaseline = "middle";
                                for (var g = 0; g < guides.length; ++g) {
                                    var guideY = Math.round(yFor(guides[g])) + 0.5;
                                    ctx.strokeStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.12);
                                    ctx.lineWidth = 1;
                                    ctx.beginPath();
                                    ctx.moveTo(padLeft, guideY);
                                    ctx.lineTo(w - padRight, guideY);
                                    ctx.stroke();

                                    ctx.fillStyle = textColor;
                                    ctx.globalAlpha = 0.6;
                                    ctx.fillText(root.tempUnitLabel(guides[g]), padLeft - 6, Math.max(padTop, Math.min(h - padBottom, guideY)));
                                    ctx.globalAlpha = 1;
                                }
                            }

                            var data = root.tempHistory;
                            if (data.length < 2) {
                                ctx.fillStyle = textColor;
                                ctx.globalAlpha = 0.6;
                                ctx.font = "12px sans-serif";
                                ctx.textAlign = "center";
                                ctx.textBaseline = "middle";
                                ctx.fillText("Collecting data...", w / 2, h / 2);
                                ctx.globalAlpha = 1;
                                return;
                            }

                            var newest = data[data.length - 1].t;
                            var oldest = newest - root.graphDuration;
                            var xFor = function(t) {
                                return padLeft + ((t - oldest) / root.graphDuration) * plotW;
                            };

                            var rawPoints = [];
                            var smoothPoints = [];
                            var maxRaw = -Infinity;
                            for (var i = 0; i < data.length; ++i) {
                                rawPoints.push({ "x": xFor(data[i].t), "y": yFor(data[i].raw) });
                                smoothPoints.push({ "x": xFor(data[i].t), "y": yFor(data[i].control) });
                                if (data[i].raw > maxRaw) {
                                    maxRaw = data[i].raw;
                                }
                            }

                            ctx.save();
                            ctx.beginPath();
                            ctx.rect(padLeft, padTop, plotW, plotH);
                            ctx.clip();

                            if (root.graphFill && root.graphShowSmoothed && smoothPoints.length > 1) {
                                ctx.beginPath();
                                ctx.moveTo(smoothPoints[0].x, padTop + plotH);
                                for (var f = 0; f < smoothPoints.length; ++f) {
                                    ctx.lineTo(smoothPoints[f].x, smoothPoints[f].y);
                                }
                                ctx.lineTo(smoothPoints[smoothPoints.length - 1].x, padTop + plotH);
                                ctx.closePath();
                                ctx.fillStyle = Qt.rgba(root.graphAccentColor.r, root.graphAccentColor.g, root.graphAccentColor.b, 0.16);
                                ctx.fill();
                            }

                            if (root.graphShowRaw) {
                                ctx.strokeStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.55);
                                drawStyledLine(rawPoints, root.graphRawStyle, 1.4, 4, 3);
                            }

                            if (root.graphShowSmoothed) {
                                ctx.strokeStyle = root.graphAccentColor;
                                drawStyledLine(smoothPoints, root.graphSmoothStyle, 2, 6, 4);
                            }
                            ctx.restore();

                            if (root.graphShowPeak && maxRaw > -Infinity) {
                                var peakY = Math.round(yFor(maxRaw)) + 0.5;
                                ctx.strokeStyle = root.graphAccentColor;
                                ctx.lineWidth = 1;
                                ctx.beginPath();
                                drawDashedHorizontal(peakY, 6, 3);

                                ctx.fillStyle = textColor;
                                ctx.globalAlpha = 0.85;
                                ctx.font = "10px sans-serif";
                                ctx.textAlign = "right";
                                ctx.textBaseline = "bottom";
                                ctx.fillText("Peak " + root.tempUnitLabel(maxRaw), w - padRight - 2, Math.max(padTop + 8, peakY - 2));
                                ctx.globalAlpha = 1;
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing
                        visible: root.graphShowLegend && (root.graphShowRaw || root.graphShowSmoothed)

                        Row {
                            visible: root.graphShowRaw
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            Repeater {
                                model: root.legendSegments(root.graphRawStyle)
                                Rectangle {
                                    width: modelData.width
                                    height: modelData.height
                                    radius: modelData.radius
                                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.55)
                                }
                            }
                        }

                        PlasmaComponents3.Label {
                            visible: root.graphShowRaw
                            text: "Raw"
                            font: Kirigami.Theme.smallFont
                            opacity: 0.8
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Row {
                            visible: root.graphShowSmoothed
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            Repeater {
                                model: root.legendSegments(root.graphSmoothStyle)
                                Rectangle {
                                    width: modelData.width
                                    height: modelData.height
                                    radius: modelData.radius
                                    color: root.graphAccentColor
                                }
                            }
                        }

                        PlasmaComponents3.Label {
                            visible: root.graphShowSmoothed
                            text: "Smoothed"
                            font: Kirigami.Theme.smallFont
                            opacity: 0.8
                        }
                    }
                }

                DragHandler {
                    id: pagerDrag
                    target: null
                    xAxis.enabled: true
                    yAxis.enabled: false

                    onActiveChanged: {
                        if (active) {
                            pager.dragStart = pager.position
                            return
                        }
                        var start = pager.dragStart
                        var velocity = pagerDrag.velocity.x
                        var target = Math.round(start)
                        if (pager.position - start > 0.18 || velocity < -500) {
                            target = Math.floor(start) + 1
                        } else if (start - pager.position > 0.18 || velocity > 500) {
                            target = Math.ceil(start) - 1
                        }
                        pager.goTo(target)
                    }

                    onTranslationChanged: {
                        if (!active || pager.width <= 0) {
                            return
                        }
                        var next = pager.dragStart - translation.x / pager.width
                        pager.position = Math.max(0, Math.min(pager.pageCount - 1, next))
                    }
                }

                Timer {
                    id: settleTimer
                    interval: 260
                    repeat: false
                    running: !pagerDrag.active && Math.abs(pager.position - Math.round(pager.position)) > 0.001
                    onTriggered: pager.goTo(Math.round(pager.position))
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse
                    onWheel: (wheel) => {
                        if (wheel.angleDelta.x > 0 || wheel.angleDelta.y < 0) {
                            pager.goTo(pager.currentIndex + 1)
                        } else if (wheel.angleDelta.x < 0 || wheel.angleDelta.y > 0) {
                            pager.goTo(pager.currentIndex - 1)
                        }
                    }
                }
            }

            QQC2.PageIndicator {
                count: pager.pageCount
                currentIndex: pager.currentIndex
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
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
