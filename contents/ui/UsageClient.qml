import QtQuick
import "UsageApi.js" as UsageApi

QtObject {
    id: client

    signal finished(int status, string body)
    signal failed(string message)

    readonly property bool busy: _xhr !== null

    property var requestFactory: null
    property var _xhr: null

    readonly property Timer watchdogTimer: Timer {
        interval: UsageApi.requestTimeoutMs
        repeat: false
        onTriggered: client._handleTimeout()
    }

    function fetch(apiKey) {
        if (_xhr !== null) {
            return
        }

        var xhr = null
        try {
            xhr = client.requestFactory !== null ? client.requestFactory() : new XMLHttpRequest()
        } catch (error) {
            xhr = null
        }

        if (!xhr) {
            client.failed("Can't create the usage request.")
            return
        }

        client._xhr = xhr
        client.watchdogTimer.restart()

        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE || client._xhr !== xhr) {
                return
            }

            client._xhr = null
            client.watchdogTimer.stop()

            if (xhr.status === 0) {
                client.failed("Can't reach OpenCode. Check your network connection.")
                return
            }

            client.finished(xhr.status, xhr.responseText)
        }

        try {
            xhr.open("GET", UsageApi.endpoint)
            xhr.setRequestHeader("Accept", "application/json")
            xhr.setRequestHeader("Authorization", "Bearer " + String(apiKey).trim())
            xhr.send()
        } catch (error) {
            client._xhr = null
            client.watchdogTimer.stop()
            client.failed("Can't reach OpenCode. Check your network connection.")
        }
    }

    function abort() {
        if (client._xhr === null) {
            return
        }

        const xhr = client._xhr
        client._xhr = null
        client.watchdogTimer.stop()
        try {
            xhr.abort()
        } catch (error) {
        }
    }

    function _handleTimeout() {
        if (client._xhr === null) {
            return
        }

        const xhr = client._xhr
        client._xhr = null
        client.watchdogTimer.stop()
        try {
            xhr.abort()
        } catch (error) {
        }
        client.failed("Request timed out.")
    }
}
