xquery version "1.0-ml";

import module namespace test = "http://marklogic.com/test" at "/test/utils/test-helper.xqy";
import module namespace qc = "http://noslogan.org/components/hub-queue/queue-config" at "/components/queue/queue-config.xqy";


(
    test:load-test-file('config-multiple.xml', xdmp:database(), '/heartbeats/test/config-multiple.xml', xdmp:default-permissions(), 'common-heartbeat-test'),
    test:load-test-file('config-single.xml', xdmp:database(), '/heartbeats/test/config-single.xml', xdmp:default-permissions(), 'common-heartbeat-test')
)