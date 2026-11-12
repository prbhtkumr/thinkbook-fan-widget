import QtQuick
import org.kde.plasma.configuration 2.0

ConfigModel {
    ConfigCategory {
        name: "Fan"
        icon: "cpu"
        source: "configFan.qml"
    }
    ConfigCategory {
        name: "Curves"
        icon: "office-chart-line"
        source: "configCurves.qml"
    }
    ConfigCategory {
        name: "Appearance"
        icon: "preferences-desktop-theme"
        source: "configAppearance.qml"
    }
    ConfigCategory {
        name: "Graph"
        icon: "view-statistics"
        source: "configGraph.qml"
    }
    ConfigCategory {
        name: "Icon"
        icon: "preferences-desktop-icons"
        source: "configIcon.qml"
    }
}
