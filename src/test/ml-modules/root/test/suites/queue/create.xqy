xquery version "1.0-ml";

import module namespace test = "http://marklogic.com/test" at "/test/test-helper.xqy";
import module namespace qe = "http://marklogic.com/community/components/queue/queue-event" at "/components/queue/queue-event.xqy";
import module namespace qh = "http://marklogic.com/community/components/queue/queue-handler" at "/components/queue/queue-handler.xqy";

declare namespace queue = "http://marklogic.com/community/queue";


declare option xdmp:mapping "false";


let $uris := ('/test/1.xml', '/test/2.json', '/test/3.xml')
let $params := map:new() => map:with('param1', 'value1') => map:with('param2', 'value2')
let $source := 'testing'
let $type := 'create-test'

let $event := qe:create($type, $source, $params, $uris)

return (
    test:assert-equal($type, $event/queue:type/data()),
    test:assert-equal($type, qe:type($event)),

    test:assert-equal($source, $event/queue:source/data()),
    test:assert-equal($source, qe:source($event)),
    
    test:assert-equal(document { $params }/node(), $event/queue:payload/node()),
    test:assert-equal(<test>{$params}</test>, <test>{qe:payload($event)}</test>),

    test:assert-equal($uris, $event/queue:uris/queue:uri/data()),
    test:assert-equal($uris, qe:uris($event))
)

