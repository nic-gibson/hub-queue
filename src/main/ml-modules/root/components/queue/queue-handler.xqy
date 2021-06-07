xquery version "1.0-ml";

module namespace qh = "http://marklogic.com/community/queue/queue-handler";

import module namespace qc = "http://marklogic.com/community/queue/config" at "queue-config.xqy";

declare namespace queue = "http://marklogic.com/community/queue";

(:~ Queue creation and update  code :)

declare option xdmp:mapping "false";

(:~
 : Create a new queue event element ready to be stored to the queue. 
 : @param $type the queue event type used to define the processor to be applied when the queue event is applied
 : @param $source a string used to identify the creator of the event
 : @param $payload the data to be passed to the queue processor
 : @param $uris the sequence of URIs to be processed
 : @return a queue event element to be stored into the queue
 :)
declare function qh:create-with-node($type as xs:string, $source as xs:string, $payload as node(), $uris as xs:string*) as element(queue:event) {
    qh:create($type, $source, $payload, $uris)
};

(:~
 : Create a new queue event element ready to be stored to the queue. 
 : @param $type the queue event type used to define the processor to be applied when the queue event is applied
 : @param $source a string used to indentify the creator of the event
 : @param $payload the data to be passed to the queue processor
 : @param $uris the sequence of URIs to be added to the event
 : @return a queue event element to be stored into the queue
 :)
 declare function qh:create-with-map($type as xs:string, $source as xs:string, $payload as map:map, $uris as xs:string*) as element(queue:event) {
    qh:create($type, $source, document { $payload }/node(), $uris)
};

(:~
 : Create a new queue event element ready to be stored to the queue. 
 : @param $type the queue event type used to define the processor to be applied when the queue event is applied
 : @param $source a string used to indentify the creator of the event
 : @param $payload the data to be passed to the queue processor
 : @param $uris the sequence of URIs to be processed
 : @return a queue event element to be stored into the queue
 :)
declare function qh:create($type as xs:string, $source as xs:string, $payload as item(), $uris as xs:string*) as element(queue:event) {

    element queue:event {
        element queue:type { $type },
        element queue:source { $source },
        element queue:source-transaction { xdmp:transaction() },
        element queue:source-host { xdmp:host-name(xdmp:host())},
        element queue:timestamp { fn:current-dateTime() },
        element queue:payload {
            attribute kind { xdmp:node-kind($payload) },
            typeswitch ($payload)
              case object-node() return xdmp:from-json($payload)
              case array-node() return xdmp:from-json($payload)
              default return $payload
        }
        element queue:uris {
            $uris ! element queue:uri { . }
        }
    }
};

(:~
 : Given a queue event, get the payload back in the original format
 : @param $event a queue event
 : @return the payload from the queue event
 :)
declare function qh:payload($event as element(queue:event)) as item() {

    switch ($event/queue:payload/@kind) 
        case "object"
        case "array"
            return xdmp:from-json($event/queue:payload/node())
        default return $payload
};

(:~ 
 : Get the URI for a new queue event.
 : @return a URI
 :)
 declare function qh:uri() as xs:anyURI {
    qc:uri-prefix() || sem:uuid-string() || '.json';
 };



(:~
 : Store an event to the queue
 : @param $enty the queue event to be written
 : @return the URI of the newly created 
 :)
 declare function qh:write($event as element(queue:event)) as xs:string() {
    if (xdmp:database() = xdmp:database(qc:database())) 
        then
            let $uri := qh:uri()
            return 
            (
                xdmp:document-insert(
                    $uri,
                    $event,
                    map:new() 
                        => map:with("collections", (qh:status-new(), qc:collection()))
                        => map:with("permissions", qc:permissions())
                ), 
                $uri
            )
        else xdmp:invoke-function( 
            function() { qh:write($event) }, 
                map:new() => map:with("database", qc:database()))
};


(:~
 : Return the collection URI for a new event. This is normally only set
 : when an event is inserted into the queue. Recovery may lead to a pending
 : entry being returned to new status
 :)
declare function qh:status-new() {
    qc:collection() || 'new'
};

(:~
 : Return the collection URI for pending event. 
 :)
 declare function qh:status-pending() {
     qc:collection() || 'pending'
 };

 
(:~
 : Return the collection URI for execution event. 
 :)
 declare function qh:status-executing() {
     qc:collection() || 'executing'
 };


(:~
 : Return the collection URI for failed event. 
 :)
 declare function qh:status-pending() {
     qc:collection() || 'failed'
 };

(:~
 : Mark a queue entry with a status and timestamp 
 : Queue status is defined by a collection prefixed with the value of the queue primary collection.
 : Given that changing a collection changes document update time we use that as our timestamp.
 : This is not wrapped in a transaction is status should be set on multiple URIs at a time.
 : @param $uri the URI of the event to be updated.
 : @param $status the new status to be set
 : @return empty sequence
~:)
declare function qh:set-status($uri as xs:string, $status as xs:string) {
    xdmp:document-set-collections($uri, ($status, qc:collection()))
};