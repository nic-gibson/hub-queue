xquery version "1.0-ml";

import module namespace test = "http://marklogic.com/test" at "/test/test-helper.xqy";
import module namespace qe = "http://marklogic.com/community/components/queue/queue-event" at "/components/queue/queue-event.xqy";
import module namespace qh = "http://marklogic.com/community/components/queue/queue-handler" at "/components/queue/queue-handler.xqy";

declare namespace queue = "http://marklogic.com/community/queue";


declare option xdmp:mapping "false";

(: Test writing audit log records for the queue :)
