pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    readonly property UsageProvider usageProvider: UsageProvider {
        apiKey: Plasmoid.configuration.apiKey
        pollIntervalMinutes: Plasmoid.configuration.pollIntervalMinutes
    }

    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : null

    compactRepresentation: CompactRepresentation {
        provider: root.usageProvider
        plasmoidItem: root
    }

    fullRepresentation: FullRepresentation {
        provider: root.usageProvider
        onConfigureRequested: root.openConfiguration()
    }

    toolTipMainText: "OpenCode Usage"
    toolTipSubText: root.usageProvider.summaryText()

    Component.onCompleted: root.usageProvider.refresh()

    Connections {
        target: root.usageProvider

        function onApiKeyChanged() {
            root.usageProvider.refresh()
        }
    }

    function openConfiguration() {
        const action = Plasmoid.internalAction("configure")
        if (action) {
            action.trigger()
        }
    }
}
