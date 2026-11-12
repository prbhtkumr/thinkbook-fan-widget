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
    property int fanTemp: -1
    property bool onAc: false
    property int pinnedLevel: -1
    property int pendingLevel: -1
    property double pendingUntil: 0
    property string lastError: ""
    property int actionSeq: 0

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
        if (fanMode === "battery") {
            return "BAT"
        }
        if (fanMode === "off") {
            return "OFF"
        }
        return fanMode.toUpperCase()
    }

    function parseState(text) {
        if (!text || text.trim().length === 0) {
            fanLevel = -1
            fanMode = "off"
            fanTemp = -1
            onAc = false
            pinnedLevel = -1
            pendingLevel = -1
            pendingUntil = 0
            return
        }

        try {
            var state = JSON.parse(text)
            fanLevel = (typeof state.level === "number") ? state.level : -1
            fanMode = state.mode || "off"
            fanTemp = (typeof state.temp === "number") ? state.temp : -1
            onAc = !!state.ac
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
        level = Math.max(0, Math.min(7, level))
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
            base = 0
        }
        setLevel(base + delta)
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
        if (fanLevel < 0) {
            return "No state from the fan service"
        }
        var parts = ["Level " + effectiveLevel, modeLabel]
        if (fanTemp >= 0) {
            parts.push(fanTemp + " C")
        }
        parts.push("Scroll to change, click for options")
        return parts.join(", ")
    }

    compactRepresentation: Item {
        id: compact

        Layout.minimumWidth: content.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.preferredWidth: Layout.minimumWidth
        Layout.maximumWidth: Layout.minimumWidth
        Layout.minimumHeight: content.implicitHeight + Kirigami.Units.smallSpacing * 2
        Layout.preferredHeight: Layout.minimumHeight
        Layout.maximumHeight: Layout.minimumHeight

        GridLayout {
            id: content
            anchors.centerIn: parent
            columns: Plasmoid.formFactor === PlasmaCore.Types.Vertical ? 1 : 3
            columnSpacing: Kirigami.Units.smallSpacing
            rowSpacing: 0

            Image {
                source: "../icons/fan.svg"
                sourceSize.width: Kirigami.Units.iconSizes.small
                sourceSize.height: Kirigami.Units.iconSizes.small
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                Layout.alignment: Qt.AlignHCenter
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            PlasmaComponents3.Label {
                text: root.levelLabel
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            PlasmaComponents3.Label {
                text: root.modeLabel
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
        Layout.preferredWidth: Kirigami.Units.gridUnit * 14
        Layout.preferredHeight: column.implicitHeight + Kirigami.Units.largeSpacing * 2

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true

                PlasmaComponents3.Label {
                    text: "Fan"
                    font.bold: true
                    Layout.fillWidth: true
                }

                PlasmaComponents3.Label {
                    text: root.levelLabel
                }

                PlasmaComponents3.Label {
                    text: root.modeLabel
                }

                PlasmaComponents3.Label {
                    text: root.fanTemp >= 0 ? root.fanTemp + " C" : ""
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 4
                columnSpacing: Kirigami.Units.smallSpacing
                rowSpacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: 8

                    PlasmaComponents3.Button {
                        id: levelButton
                        required property int index
                        Layout.fillWidth: true
                        text: index
                        font.bold: root.effectiveLevel === index
                        checkable: true
                        checked: root.effectiveLevel === index

                        Rectangle {
                            anchors.fill: parent
                            radius: Kirigami.Units.smallSpacing
                            color: "transparent"
                            border.width: 2
                            border.color: Kirigami.Theme.highlightColor
                            visible: levelButton.checked
                        }

                        onClicked: {
                            root.setLevel(index)
                            root.expanded = false
                        }
                    }
                }
            }

            PlasmaComponents3.Button {
                id: autoButton
                Layout.fillWidth: true
                text: "Auto"
                font.bold: !root.pinnedNow
                checkable: true
                checked: !root.pinnedNow

                Rectangle {
                    anchors.fill: parent
                    radius: Kirigami.Units.smallSpacing
                    color: "transparent"
                    border.width: 2
                    border.color: Kirigami.Theme.highlightColor
                    visible: autoButton.checked
                }

                onClicked: {
                    root.clearPin()
                    root.expanded = false
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
}
