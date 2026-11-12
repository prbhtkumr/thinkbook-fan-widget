import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_graphDuration: durationSpin.value

    Kirigami.FormLayout {
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
            text: "History window for the Graph tab."
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
    }
}
