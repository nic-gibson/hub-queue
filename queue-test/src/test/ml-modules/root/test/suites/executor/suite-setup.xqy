xquery version "1.0-ml";

import module namespace test = "http://marklogic.com/test" at "/test/utils/test-helper.xqy";
import module namespace qc = "http://noslogan.org/components/hub-queue/queue-config" at "/components/hub-queue/queue-config.xqy";
import module namespace qh = "http://noslogan.org/components/hub-queue/queue-handler" at "/components/hub-queue/queue-handler.xqy";

let $event := <queue:event xmlns:queue="http://noslogan.org/hub-queue">
    <queue:id>10f5a58d-8c14-4cae-981d-6a67d644df65</queue:id>
    <queue:type>http://noslogan.org/hub-queue/event/ping</queue:type>
    <queue:source>http://noslogan.org/hub-queue/source/heartbeat</queue:source>
    <queue:transaction>15710557944335112285</queue:transaction>
    <queue:host>newt.noslogan.org</queue:host>
    <queue:creation-timestamp>2021-06-08T21:20:09.372938+01:00</queue:creation-timestamp>
    <queue:payload kind="element">
        <foo>
        </foo>
    </queue:payload>
    <queue:uris>
        <queue:uri>/test/1.xml</queue:uri>
        <queue:uri>/test/2.xml</queue:uri>
    </queue:uris>
</queue:event>


return 
(
    qh:write($event),
    test:load-test-file('1.xml', xdmp:database(), '/test/1.xml', xdmp:default-permissions(), 'common-queue-test'),
    test:load-test-file('2.xml', xdmp:database(), '/test/2.xml', xdmp:default-permissions(), 'common-queue-test')
)