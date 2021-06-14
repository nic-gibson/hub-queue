xquery version "1.0-ml";

module namespace qe = "http://marklogic.com/community/components/queue/queue-event";

import module namespace qc = "http://marklogic.com/community/components/queue/queue-config" at "queue-config.xqy";

declare namespace queue = "http://marklogic.com/community/queue";
declare namespace xsi = "http://www.w3.org/2001/XMLSchema-instance";
declare namespace json = "http://marklogic.com/xdmp/json";

declare option xdmp:mapping "false";

(:~ Provide an interface to a queue event. Contains functions to build an event and 
 : functions returning the various components of the  event to allow it to be treated as an opaque entity 
:)

(:~
 : Create a new queue event element ready to be stored to the queue. 
 : @param $type the queue event type used to define the processor to be applied when the queue event is applied
 : @param $source a string used to indentify the creator of the event
 : @param $payload the data to be passed to the queue processor
 : @param $uris the sequence of URIs to be processed
 : @return a queue event element to be stored into the queue
:)
declare function qe:create($type as xs:string, $source as xs:string, $payload as item(), $uris as xs:string*) as element(queue:event) {

    element queue:event {
        element queue:id { sem:uuid-string() },
        element queue:type { $type },
        element queue:source { $source },
        element queue:transaction { xdmp:transaction() },
        element queue:user { xdmp:get-current-user() },
        element queue:host { xdmp:host-name(xdmp:host())},
        element queue:creation-timestamp { fn:current-dateTime() },
        qe:serialize-payload($payload),
        element queue:uris {
            $uris ! element queue:uri { . }
        }
    }
};

(:~
 : Given a queue event return the uris as strings
 : @param $event - a queue event
 : @return a sequence of URIs
:)
declare function qe:uris($event as element(queue:event)) as xs:string* {
    $event/queue:uris/queue:uri/data()
};


(:~
 : Given a queue event, get the payload back in the original format
 : @param $event a queue event
 : @return the payload from the queue event
:)
declare function qe:payload($event as element(queue:event)) as item() {
   qe:restore-payload($event/queue:payload)
};

(:~
 : Given a queue event, get the id
 : @param $event a queue event
 : @return event id
:)
declare function qe:id($event as element(queue:event)) as xs:string {
    $event/queue:id/data()
};


(:~
 : Given a queue event, get the type
 : @param $event a queue event
 : @return event type
:)
declare function qe:type($event as element(queue:event)) as xs:string {
    $event/queue:type/data()
};


(:~
 : Given a queue event, get the source
 : @param $event a queue event
 : @return event source
:)
declare function qe:source($event as element(queue:event)) as xs:string {
    $event/queue:source/data()
};

 (:~
  : Given a queue event, get the source transaction
  : @param $event a queue event
  : @return event source transaction
 :)
  declare function qe:transaction($event as element(queue:event)) as xs:integer {
    $event/queue:transaction/data()
 };

(:~
 : Given a queue event, get the source host
 : @param $event a queue event
 : @return event source host
:)
declare function qe:host($event as element(queue:event)) as xs:string {
    $event/queue:host/data()
};

(:~
 : Given a queue event, get the creation timestamp
 : @param $event a queue event
 : @return event creation timestamp
:)
declare function qe:creation-timestamp($event as element(queue:event)) as xs:dateTime {
    $event/queue:creation-timestamp/data()
};

(:~ 
 : Get the queue status for an event node 
 : @param $event the event element
 : @return the status if the event has been written to disk and an empty sequence if not
:)
declare function qe:event-status($event as element(queue:event)) as xs:string? {
    xdmp:node-metadata-value($event, qc:status-metadata-name())
};

(:~ 
 : Get the queue timestamp for an event node 
 : @param $event the event element
 : @return the timestamp if the event has been written to disk and an empty sequence if not
:)
declare function qe:event-timestamp($event as element(queue:event)) as xs:dateTime? {
    xs:dateTime(xdmp:node-metadata-value($event, qc:timestamp-metadata-name()))
};


(:~
 : Given an item convert it to something we can serialize in the payload
 : and return that and the type name we want to give it as a hint on loading
 : @param $payload the item to convert
 : @return a sequence of name and serializable form
:)
declare function qe:serialize-payload($payload as item()) as element(queue:payload) {
    let $values := typeswitch ($payload)
        case element() return ('element', $payload)
        case object-node() return ('object', <dummy>{fn:data($payload)}</dummy>/node())
        case array-node() return ('array', <dummy>{fn:data($payload)}</dummy>/node())
        case json:object return ('object', document { $payload }/node() )
        case json:array return ('array', document { $payload }/node() )
        case map:map return ('map', document { $payload }/node() )
        default return ('atomic', $payload)

    return element queue:payload {
        attribute kind { $values[1] },
        $values[2]
    }
 };


(:~ 
 : Given the serialised form of a payload return something close to
 : the original (object-node and json:object are both returned as json:object 
 : for example)
 : @param $payload the payload element from an event
 : @return the 'decoded' version of the payload
:)
declare function qe:restore-payload($payload as element(queue:payload)) as item() {
    switch ($payload/@kind)
        case 'object' return json:object($payload/node())
        case 'array' return json:array($payload/node())
        case 'element' return $payload/node()
        case 'map' return map:map($payload/node())
        default return $payload/node()/data()
};