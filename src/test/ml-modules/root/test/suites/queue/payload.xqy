xquery version "1.0-ml";

import module namespace test = "http://marklogic.com/test" at "/test/utils/test-helper.xqy";
import module namespace qe = "http://noslogan.org/components/hub-queue/queue-event" at "/components/queue/queue-event.xqy";

declare namespace queue = "http://noslogan.org/hub-queue";

declare option xdmp:mapping "false";


(:~
 : Tests to check on serialization and restoration of the payload of queue entries. 
 : NOTE - deep equal doesn't work on maps, array nodes or object nodes but forcing xml serialization fixes that. 
 :)


let $map-payload := map:new() 
    => map:with('key', 'value')
    => map:with('xkey', <value/>)

let $map-payload-serialized := <queue:payload kind="map" xmlns:queue="http://noslogan.org/hub-queue/">
    <map:map xmlns:map="http://marklogic.com/xdmp/map" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <map:entry key="xkey">
            <map:value>
                <value></value>
            </map:value>
        </map:entry>
        <map:entry key="key">
            <map:value xsi:type="xs:string">value</map:value>
        </map:entry>
    </map:map>
</queue:payload>

let $object-payload := json:object()
    => map:with('key1', 'value1')
    => map:with('key2', 'value2')

let $object-payload-serialized := <queue:payload kind="object" xmlns:queue="http://noslogan.org/hub-queue/">
    <json:object xmlns:json="http://marklogic.com/xdmp/json" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <json:entry key="key1">
            <json:value xsi:type="xs:string">value1</json:value>
        </json:entry>
        <json:entry key="key2">
            <json:value xsi:type="xs:string">value2</json:value>
        </json:entry>
    </json:object>
</queue:payload>

let $array-payload := json:to-array(('item1', 'item2', 3))

let $array-payload-serialized := <queue:payload kind="array" xmlns:queue="http://noslogan.org/hub-queue/">
    <json:array xmlns:json="http://marklogic.com/xdmp/json" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <json:value xsi:type="xs:string">item1</json:value>
        <json:value xsi:type="xs:string">item2</json:value>
        <json:value xsi:type="xs:integer">3</json:value>
    </json:array>
</queue:payload>

let $element-payload := <payload><key>value</key><item2/></payload>

let $element-payload-serialized := <queue:payload kind="element" xmlns:queue="http://noslogan.org/hub-queue/">
    <payload>
        <key>value</key>
        <item2></item2>
    </payload>
</queue:payload>

let $array-node-payload := array-node { ('item1', 'item2', 3 ) }

let $array-node-payload-serialized := <queue:payload kind="array" xmlns:queue="http://noslogan.org/hub-queue/">
    <json:array xmlns:json="http://marklogic.com/xdmp/json" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <json:value>item1</json:value>
        <json:value>item2</json:value>
        <json:value xsi:type="xs:integer">3</json:value>
    </json:array>
</queue:payload>

let $object-node-payload := object-node { 'key1': 'value1', 'key2': 'value2'}

let $object-node-payload-serialized := <queue:payload kind="object" xmlns:queue="http://noslogan.org/hub-queue/">
    <json:object xmlns:json="http://marklogic.com/xdmp/json" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <json:entry key="key1">
            <json:value>value1</json:value>
        </json:entry>
        <json:entry key="key2">
            <json:value>value2</json:value>
        </json:entry>
    </json:object>
</queue:payload>

let $date-payload := xs:dateTime('2020-11-19T09:34:23.832Z')
let $date-payload-serialized := <queue:payload kind="atomic" xmlns:queue="http://noslogan.org/hub-queue/">2020-11-19T09:34:23.832Z</queue:payload>

let $string-payload := 'string-value'
let $string-payload-serialized := <queue:payload kind="atomic" xmlns:queue="http://noslogan.org/hub-queue/">string-value</queue:payload>

return (
    test:assert-equal($map-payload-serialized, qe:serialize-payload($map-payload))  ,
    test:assert-equal(<test>{$map-payload}</test>, <test>{qe:restore-payload($map-payload-serialized)}</test>),
    test:assert-equal(<test>{$map-payload}</test>, <test>{qe:restore-payload(qe:serialize-payload($map-payload))}</test>),

    test:assert-equal($object-payload-serialized, qe:serialize-payload($object-payload)),
    test:assert-equal(<test>{$object-payload}</test>, <test>{qe:restore-payload($object-payload-serialized)}</test>),
    test:assert-equal(<test>{$object-payload}</test>, <test>{qe:restore-payload(qe:serialize-payload($object-payload))}</test>),
    
    test:assert-equal($array-payload-serialized, qe:serialize-payload($array-payload)),
    test:assert-equal($array-payload, qe:restore-payload($array-payload-serialized)),
    test:assert-equal($array-payload, qe:restore-payload(qe:serialize-payload($array-payload))),
    
    test:assert-equal($element-payload-serialized, qe:serialize-payload($element-payload)),
    test:assert-equal($element-payload, qe:restore-payload($element-payload-serialized)),
    test:assert-equal($element-payload, qe:restore-payload(qe:serialize-payload($element-payload))),

    (: NB - array *node* is restored to json:array :)
    test:assert-equal($array-node-payload-serialized, qe:serialize-payload($array-node-payload)),
    test:assert-equal(<test>{fn:data($array-node-payload)}</test>/node(), <test>{qe:restore-payload(qe:serialize-payload($array-node-payload))}</test>/node()),

    (: NB - object *node* is restored to json:object :)
    test:assert-equal($object-node-payload-serialized, qe:serialize-payload($object-node-payload)),
    test:assert-equal(<test>{fn:data($object-node-payload)}</test>/node(), <test>{qe:restore-payload(qe:serialize-payload($object-node-payload))}</test>/node()),

    (: all atomic values are serialized as strings :)
    test:assert-equal($date-payload-serialized, qe:serialize-payload($date-payload)),
    test:assert-equal($date-payload, qe:restore-payload($date-payload-serialized)),
    test:assert-equal($date-payload, xs:dateTime(qe:restore-payload(qe:serialize-payload($date-payload)))),

    test:assert-equal($string-payload-serialized, qe:serialize-payload($string-payload)),
    test:assert-equal($string-payload, qe:restore-payload($string-payload-serialized)), 
    test:assert-equal($string-payload, qe:restore-payload(qe:serialize-payload($string-payload)))
)


