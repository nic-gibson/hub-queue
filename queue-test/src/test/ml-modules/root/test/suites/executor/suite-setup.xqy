xquery version "1.0-ml";

import module namespace test = "http://marklogic.com/test" at "/test/utils/test-helper.xqy";
import module namespace qc = "http://noslogan.org/components/hub-queue/queue-config" at "/components/hub-queue/queue-config.xqy";


let $metadata := map:new()
    => map:with(qc:status-metadata-name(), qc:new-status())
    => map:with(qc:timestamp-metadata-name(), fn:current-dateTime())

return (
    test:load-test-file('10f5a58d-8c14-4cae-981d-6a67d644df65.xml', xdmp:database(), 
        '/noslogan.org/hub-queue/queue/10f5a58d-8c14-4cae-981d-6a67d644df65.xml', qc:permissions('element'), qc:collection(), $metadata),
    test:load-test-file('1.xml', xdmp:database(), '/test/1.xml', xdmp:default-permissions(), 'common-queue-test'),
    test:load-test-file('2.xml', xdmp:database(), '/test/2.xml', xdmp:default-permissions(), 'common-queue-test')
)