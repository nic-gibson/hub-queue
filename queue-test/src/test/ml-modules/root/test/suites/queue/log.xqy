xquery version "1.0-ml";

import module namespace test = "http://marklogic.com/test" at "/test/test-helper.xqy";
import module namespace qe = "http://noslogan.org/components/hub-queue/queue-event" at "/components/hub-queue/queue-event.xqy";
import module namespace qh = "http://noslogan.org/components/hub-queue/queue-handler" at "/components/hub-queue/queue-handler.xqy";

declare namespace queue = "http://noslogan.org/hub-queue";


declare option xdmp:mapping "false";

(: Test writing audit log records for the queue :)


1;