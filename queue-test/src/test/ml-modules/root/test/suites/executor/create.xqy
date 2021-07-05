xquery version "1.0-ml";

import module namespace test = "http://marklogic.com/test" at "/test/utils/test-helper.xqy";
import module namespace qc = "http://noslogan.org/components/hub-queue/queue-config" at "/components/hub-queue/queue-config.xqy";
import module namespace qh = "http://noslogan.org/components/hub-queue/queue-handler" at "/components/hub-queue/queue-handler.xqy";

declare namespace queue = "http://noslogan.org/hub-queue";

declare option xdmp:mapping "false";

let $event := qh:get-event('10f5a58d-8c14-4cae-981d-6a67d644df65', qc:executing-status())
return test:assert-exists($event);

(: ---- next transaction ----- :)

import module namespace test = "http://marklogic.com/test" at "/test/utils/test-helper.xqy";
import module namespace qx = "http://noslogan.org/components/hub-queue/queue-executor" at "/components/hub-queue/queue-executor.xqy";
import module namespace qc = "http://noslogan.org/components/hub-queue/queue-config" at "/components/hub-queue/queue-config.xqy";
import module namespace qh = "http://noslogan.org/components/hub-queue/queue-handler" at "/components/hub-queue/queue-handler.xqy";
import module namespace qe = "http://noslogan.org/components/hub-queue/queue-event" at "/components/hub-queue/queue-event.xqy";


let $event := qh:get-event('10f5a58d-8c14-4cae-981d-6a67d644df65', ())
let $executor := qx:find-executor($event)
return (
    test:assert-equal(qc:executing-status(), qh:get-status('10f5a58d-8c14-4cae-981d-6a67d644df65')),
    test:assert-exists($executor, "Event executor not found")
);




(: ---- next transaction ----- :)

import module namespace test = "http://marklogic.com/test" at "/test/utils/test-helper.xqy";
import module namespace qx = "http://noslogan.org/components/hub-queue/queue-executor" at "/components/hub-queue/queue-executor.xqy";
import module namespace qc = "http://noslogan.org/components/hub-queue/queue-config" at "/components/hub-queue/queue-config.xqy";
import module namespace qh = "http://noslogan.org/components/hub-queue/queue-handler" at "/components/hub-queue/queue-handler.xqy";
import module namespace qe = "http://noslogan.org/components/hub-queue/queue-event" at "/components/hub-queue/queue-event.xqy";

let $result := qx:execute-event('10f5a58d-8c14-4cae-981d-6a67d644df65')

return (
    test:assert-equal(qc:finished-status(), $result)
)

