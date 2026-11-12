import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_minLevel: levelSpin.value

    Kirigami.FormLayout {
        QQC2.SpinBox {
            id: levelSpin
            Kirigami.FormData.label: "Minimum fan level:"
            from: 3
            to: 7
            stepSize: 1
        }
    }
}
