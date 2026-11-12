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
    readonly property int minFanLevel: Math.max(3, Math.min(7, configMinLevel))
    readonly property string iconSource: {
        var source = Plasmoid.configuration.iconSource
        return (source === undefined || source === null) ? "../icons/fan.svg" : source
    }
    readonly property bool showIcon: (Plasmoid.configuration.showIcon !== false) && iconSource.trim().length > 0
    readonly property bool showLevel: Plasmoid.configuration.showLevel !== false
    readonly property bool showStatus: Plasmoid.configuration.showStatus !== false
    readonly property bool showTemperature: Plasmoid.configuration.showTemperature !== false
    readonly property bool boldStatus: Plasmoid.configuration.boldStatus === true
    readonly property bool boldTemperature: Plasmoid.configuration.boldTemperature === true
    readonly property bool boldLevel: Plasmoid.configuration.boldLevel !== false
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
        if (graphCanvasItem) {
            graphCanvasItem.requestPaint()
        }
    }

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
                font.bold: root.boldLevel
                Layout.alignment: Qt.AlignHCenter
            }

            PlasmaComponents3.Label {
                visible: root.showStatus
                text: root.modeLabel
                font.family: Kirigami.Theme.smallFont.family
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.bold: root.boldStatus
                opacity: root.boldStatus ? 1.0 : 0.8
                Layout.alignment: Qt.AlignHCenter
            }

            PlasmaComponents3.Label {
                visible: root.showTemperature
                text: root.tempLabel
                font.family: Kirigami.Theme.smallFont.family
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.bold: root.boldTemperature
                opacity: root.boldTemperature ? 1.0 : 0.8
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
                            var padLeft = 36;
                            var padRight = 8;
                            var padTop = 8;
                            var padBottom = 4;
                            var plotW = Math.max(1, w - padLeft - padRight);
                            var plotH = Math.max(1, h - padTop - padBottom);
                            var yFor = function(c) {
                                return padTop + plotH - ((c - minC) / (maxC - minC)) * plotH;
                            };

                            var drawDashedLine = function(points, dash, gap) {
                                var drawing = true;
                                var remaining = dash;
                                ctx.beginPath();
                                for (var p = 1; p < points.length; ++p) {
                                    var x0 = points[p - 1].x;
                                    var y0 = points[p - 1].y;
                                    var x1 = points[p].x;
                                    var y1 = points[p].y;
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
                                            remaining = drawing ? dash : gap;
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
                            var maxRaw = -Infinity;
                            for (var i = 0; i < data.length; ++i) {
                                rawPoints.push({ "x": xFor(data[i].t), "y": yFor(data[i].raw) });
                                if (data[i].raw > maxRaw) {
                                    maxRaw = data[i].raw;
                                }
                            }

                            ctx.save();
                            ctx.beginPath();
                            ctx.rect(padLeft, padTop, plotW, plotH);
                            ctx.clip();

                            ctx.strokeStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.45);
                            ctx.lineWidth = 1;
                            drawDashedLine(rawPoints, 3, 3);

                            ctx.strokeStyle = root.graphAccentColor;
                            ctx.lineWidth = 2;
                            ctx.beginPath();
                            for (var j = 0; j < data.length; ++j) {
                                var cy = yFor(data[j].control);
                                if (j === 0) {
                                    ctx.moveTo(xFor(data[j].t), cy);
                                } else {
                                    ctx.lineTo(xFor(data[j].t), cy);
                                }
                            }
                            ctx.stroke();
                            ctx.restore();

                            if (maxRaw > -Infinity) {
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

                        Row {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            Repeater {
                                model: 4
                                Rectangle {
                                    width: 3
                                    height: 2
                                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.45)
                                }
                            }
                        }

                        PlasmaComponents3.Label {
                            text: "Raw"
                            font: Kirigami.Theme.smallFont
                            opacity: 0.8
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            Layout.preferredWidth: 14
                            Layout.preferredHeight: 2
                            color: root.graphAccentColor
                        }

                        PlasmaComponents3.Label {
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
                Layout.alignment: Qt.AlignHCenter
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
