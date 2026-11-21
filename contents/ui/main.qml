pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    readonly property UsageProvider usageProvider: UsageProvider {}

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : null

    compactRepresentation: CompactRepresentation {
        provider: root.usageProvider
        plasmoidItem: root
    }

    fullRepresentation: FullRepresentation {
        provider: root.usageProvider
    }

    toolTipMainText: "OpenCode Usage"
    toolTipSubText: root.usageProvider.summaryText()
}
