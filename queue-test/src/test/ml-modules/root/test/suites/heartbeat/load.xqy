xquery version "1.0-ml";

import module namespace test = "http://marklogic.com/test" at "/test/utils/test-helper.xqy";
import module namespace qt = "http://noslogan.org/components/hub-queue/queue-heartbeat" at "/components/hub-queue/queue-heartbeat.xqy";

declare namespace queue = "http://noslogan.org/hub-queue";

declare option xdmp:mapping "false";


(:~
 : Tests for the heartbeat event loader and generator. Note that we don't actually load the test data because
 : deploy will have placed it in the modules db where we need it to be.
:)

(
    test:assert-all-exist(1, qt:find-heartbeat-configs('OneMinute')),
    test:assert-all-exist(1, qt:find-heartbeat-configs('FiveMinute')),
    test:assert-all-exist(1, qt:find-heartbeat-configs('FifteenMinute'))
)
