import QtQuick
import QtTest
import "../contents/ui" as UsageUi

TestCase {
    id: testCase

    name: "UsageClient"

    readonly property string testKey: "test-key-not-real"

    UsageUi.UsageClient {
        id: client
    }

    SignalSpy {
        id: failedSpy

        target: client
        signalName: "failed"
    }

    SignalSpy {
        id: finishedSpy

        target: client
        signalName: "finished"
    }

    function makeRequest() {
        var request = {
            readyState: 0,
            status: 0,
            responseText: "",
            onreadystatechange: null,
            method: "",
            url: "",
            headers: [],
            sent: false,
            aborted: false
        }

        request.open = function (method, url) {
            request.method = method
            request.url = url
        }
        request.setRequestHeader = function (name, value) {
            request.headers.push({ name: name, value: value })
        }
        request.send = function () {
            request.sent = true
        }
        request.abort = function () {
            request.aborted = true
        }

        return request
    }

    function cleanup() {
        client.abort()
        client.requestFactory = null
        client.watchdogTimer.interval = 15000
        failedSpy.clear()
        finishedSpy.clear()
    }

    function test_requestUsesEndpointAndBearerHeader() {
        const request = testCase.makeRequest()
        client.requestFactory = function () {
            return request
        }
        client.watchdogTimer.interval = 5000
        client.fetch("  " + testCase.testKey + "  ")

        compare(client.busy, true)
        compare(request.sent, true)
        compare(request.method, "GET")
        compare(request.url, "https://opencode.ai/zen/go/v1/usage")
        compare(request.headers.length, 2)
        compare(request.headers[0].name, "Accept")
        compare(request.headers[0].value, "application/json")
        compare(request.headers[1].name, "Authorization")
        compare(request.headers[1].value, "Bearer " + testCase.testKey)
    }

    function test_secondRequestIsIgnoredWhileBusy() {
        const first = testCase.makeRequest()
        client.requestFactory = function () {
            return first
        }
        client.watchdogTimer.interval = 5000
        client.fetch(testCase.testKey)

        const second = testCase.makeRequest()
        client.requestFactory = function () {
            return second
        }
        client.fetch(testCase.testKey)

        compare(client.busy, true)
        compare(first.sent, true)
        compare(second.sent, false)
        compare(failedSpy.count, 0)
    }

    function test_timeoutAbortsClearsBusyAndEmitsOnce() {
        const first = testCase.makeRequest()
        client.requestFactory = function () {
            return first
        }
        client.watchdogTimer.interval = 20
        client.fetch(testCase.testKey)

        compare(client.busy, true)
        compare(client.watchdogTimer.running, true)

        tryCompare(client, "busy", false, 2000)

        compare(first.aborted, true)
        compare(client.watchdogTimer.running, false)
        compare(failedSpy.count, 1)
        compare(failedSpy.signalArguments[0][0], "Request timed out.")
        compare(finishedSpy.count, 0)

        first.readyState = 4
        first.status = 200
        first.responseText = "{}"
        first.onreadystatechange()

        compare(failedSpy.count, 1)
        compare(finishedSpy.count, 0)
        compare(client.busy, false)
    }

    function test_requestCanStartAfterTimeout() {
        const first = testCase.makeRequest()
        client.requestFactory = function () {
            return first
        }
        client.watchdogTimer.interval = 20
        client.fetch(testCase.testKey)
        tryCompare(client, "busy", false, 2000)
        compare(failedSpy.count, 1)

        const second = testCase.makeRequest()
        client.requestFactory = function () {
            return second
        }
        client.watchdogTimer.interval = 5000
        client.fetch(testCase.testKey)

        compare(client.busy, true)
        compare(second.sent, true)
        compare(second.aborted, false)

        second.readyState = 4
        second.status = 200
        second.responseText = "{\"usage\":{}}"
        second.onreadystatechange()

        compare(client.busy, false)
        compare(client.watchdogTimer.running, false)
        compare(finishedSpy.count, 1)
        compare(finishedSpy.signalArguments[0][0], 200)
        compare(finishedSpy.signalArguments[0][1], "{\"usage\":{}}")
        compare(failedSpy.count, 1)
    }

    function test_statusZeroUsesFailurePath() {
        const request = testCase.makeRequest()
        client.requestFactory = function () {
            return request
        }
        client.watchdogTimer.interval = 5000
        client.fetch(testCase.testKey)

        request.readyState = 4
        request.status = 0
        request.onreadystatechange()

        compare(client.busy, false)
        compare(client.watchdogTimer.running, false)
        compare(failedSpy.count, 1)
        verify(failedSpy.signalArguments[0][0].indexOf("network") >= 0)
        compare(finishedSpy.count, 0)
    }

    function test_abortInvalidatesRequestAndStopsWatchdog() {
        const request = testCase.makeRequest()
        client.requestFactory = function () {
            return request
        }
        client.watchdogTimer.interval = 5000
        client.fetch(testCase.testKey)

        client.abort()

        compare(client.busy, false)
        compare(client.watchdogTimer.running, false)
        compare(request.aborted, true)

        request.readyState = 4
        request.status = 200
        request.onreadystatechange()

        compare(finishedSpy.count, 0)
        compare(failedSpy.count, 0)
    }
}
