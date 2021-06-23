xquery version "1.0-ml";

import module namespace test = "http://marklogic.com/test" at "/test/utils/test-helper.xqy";
import module namespace qc = "http://noslogan.org/components/hub-queue/queue-config" at "/components/queue/queue-config.xqy";

let $metadata := map:new() => map:with('queue-timestamp', fn:current-dateTime()) => map:with('queue-status', qc:status-new())
return (
    test:load-test-file('event-01.xml', xdmp:database(), '/handler/test/event-01.xml', xdmp:default-permissions(), 'common-queue-test', $metadata),
    test:load-test-file('event-02.xml', xdmp:database(), '/handler/test/event-02.xml', xdmp:default-permissions(), 'common-queue-test', $metadata)
)