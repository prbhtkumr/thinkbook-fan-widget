import QtQuick
import org.kde.plasma.configuration 2.0

ConfigModel {
    ConfigCategory {
        name: "Fan"
        icon: "cpu"
        source: "configFan.qml"
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
}
