xquery version "1.0-ml";

import module namespace test = "http://marklogic.com/test" at "/test/utils/test-helper.xqy";
import module namespace qt = "http://noslogan.org/components/hub-queue/queue-heartbeat" at "/components/queue/queue-heartbeat.xqy";

declare namespace queue = "http://noslogan.org/hub-queue";

declare option xdmp:mapping "false";


(:~
 : Tests for the heartbeat event loader and generator
:)

let $uri := qt:create-heartbeat-events(qt:find-heartbeat-configs('OneMinute'))



return (
    test:assert-all-exist(1, qt:find-heartbeat-configs('OneMinute')),
    test:assert-all-exist(1, qt:find-heartbeat-configs('FiveMinute')),
    test:assert-all-exist(1, qt:find-heartbeat-configs('FifteenMinute')),
    test:assert-exists(fn:doc($uri))
)
