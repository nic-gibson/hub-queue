xquery version "1.0-ml";

import module namespace test = "http://marklogic.com/test" at "/test/utils/test-helper.xqy";
import module namespace qh = "http://noslogan.org/components/hub-queue/queue-handler" at "/components/queue/queue-handler.xqy";

declare namespace queue = "http://noslogan.org/hub-queue/";

declare option xdmp:mapping "false";


let $uri := qh:write(fn:doc('/handler/test/event-01.xml'))

