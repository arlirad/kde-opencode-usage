import QtQuick
import "UsageApi.js" as UsageApi

QtObject {
    id: client

    signal finished(int status, string body)
    signal failed(string message)

    readonly property bool busy: _xhr !== null

    property var _xhr: null

    function fetch(apiKey) {
        if (_xhr !== null) {
            return
        }

        const xhr = new XMLHttpRequest()
        _xhr = xhr

        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE || client._xhr !== xhr) {
                return
            }

            client._xhr = null
            if (xhr.status === 0) {
                client.failed("Can't reach OpenCode. Check your network connection.")
            } else {
                client.finished(xhr.status, xhr.responseText)
            }
        }

        xhr.ontimeout = function () {
            if (client._xhr !== xhr) {
                return
            }

            client._xhr = null
            client.failed("Request timed out.")
        }

        xhr.onerror = function () {
            if (client._xhr !== xhr) {
                return
            }

            client._xhr = null
            client.failed("Can't reach OpenCode. Check your network connection.")
        }

        xhr.open("GET", UsageApi.endpoint)
        xhr.timeout = UsageApi.requestTimeoutMs
        xhr.setRequestHeader("Accept", "application/json")
        xhr.setRequestHeader("Authorization", "Bearer " + String(apiKey).trim())
        xhr.send()
    }

    function abort() {
        if (_xhr === null) {
            return
        }

        const xhr = _xhr
        _xhr = null
        xhr.abort()
    }
}
