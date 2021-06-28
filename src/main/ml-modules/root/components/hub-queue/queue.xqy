xquery version "1.0-ml";

module namespace q = "http://noslogan.org/components/hub-queue/queue";

import module namespace qe = "http://noslogan.org/components/hub-queue/queue-event" at "queue-event.xqy";
import module namespace qh = "http://noslogan.org/components/hub-queue/queue-handler" at "queue-handler.xqy";


declare namespace queue = "http://noslogan.org/hub-queue";

(:~
 : Public interfaces to the queue. Only this and queue-config (if required) should be consumed directly by client code
:)

(:~ 
 : Create one or more events by breaking up the URIs to be more than the configured maximum 
 : @param $type the queue event type used to define the processor to be applied when the queue event is applied
 : @param $source a string used to indentify the creator of the event
 : @param $payload the data to be passed to the queue processor
 : @param $uris the sequence of URIs to be processed
 : @return URIs of the events written to the queue
:)
declare function q:create-batch($type as xs:string, $source as xs:string, $payload as item(), $uris as xs:string*) as xs:string+ {
    qe:create-batch($type, $source, $payload, $uris) ! qh:write(.)
};


(:~ 
 : Create a single event and write it. 
 : @param $type the queue event type used to define the processor to be applied when the queue event is applied
 : @param $source a string used to indentify the creator of the event
 : @param $payload the data to be passed to the queue processor
 : @param $uris the sequence of URIs to be processed
 : @return URI of the event written to the queue
:)
declare function q:create($type as xs:string, $source as xs:string, $payload as item(), $uris as xs:string*) as xs:string {
    qh:write(qe:create($type, $source, $payload, $uris))
};