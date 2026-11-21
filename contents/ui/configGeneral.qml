import QtQuick
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

KCM.SimpleKCM {
    id: page

    property alias cfg_apiKey: apiKeyField.text
    property alias cfg_pollIntervalMinutes: pollInterval.value
    property alias cfg_showDemoData: demoCheck.checked

    Kirigami.FormLayout {
        PlasmaComponents3.TextField {
            id: apiKeyField

            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
            Kirigami.FormData.label: "OpenCode Go API key:"
            echoMode: TextInput.Password
            inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
            placeholderText: "Paste the API key"

            Accessible.name: "OpenCode Go API key"
            Accessible.description: "Used as a bearer token for the OpenCode Go usage endpoint."
        }

        PlasmaComponents3.SpinBox {
            id: pollInterval

            from: 1
            to: 1440
            stepSize: 1
            editable: true
            Kirigami.FormData.label: "Refresh every:"
            textFromValue: function (value) {
                return value === 1 ? "1 minute" : value + " minutes"
            }
            valueFromText: function (text) {
                const parsed = parseInt(text, 10)
                return isNaN(parsed) ? 5 : Math.max(1, Math.min(1440, parsed))
            }
        }

        PlasmaComponents3.CheckBox {
            id: demoCheck

            text: "Show sample data when no API key is configured"
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 30
            text: "The API key is stored in this widget's Plasma configuration in your user home directory. Rotate the key if it may have been exposed."
            wrapMode: Text.WordWrap
        }
    }
}
