xquery version "1.0-ml";

import module namespace qt = "http://noslogan.org/components/hub-queue/queue-heartbeat" at "/components/hub-queue/queue-heartbeat.xqy";

(:~
 : Tests for the heartbeat event loader and generator. Note that we don't actually load the test data because
 : deploy will have placed it in the modules db where we need it to be.
:)

declare namespace queue = "http://noslogan.org/hub-queue";
qt:create-heartbeat-events(qt:find-heartbeat-configs('OneMinute'));

(: New Transaction - test the result of above:)

import module namespace qh = "http://noslogan.org/components/hub-queue/queue-handler" at "/components/hub-queue/queue-handler.xqy";
import module namespace qc = "http://noslogan.org/components/hub-queue/queue-config" at "/components/hub-queue/queue-config.xqy";
import module namespace qe = "http://noslogan.org/components/hub-queue/queue-event" at "/components/hub-queue/queue-event.xqy";
import module namespace test = "http://marklogic.com/test" at "/test/utils/test-helper.xqy";

let $event := qh:get-event-documents(1, qc:new-status(), ())

return (
    test:assert-exists($event),
    test:assert-equal(qc:heartbeat-source(), qe:source($event)),
    test:assert-equal('http://noslogan.org/hub-queue/event/ping', qe:type($event))
)

