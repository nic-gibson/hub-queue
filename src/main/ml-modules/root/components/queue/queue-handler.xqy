xquery version "1.0-ml";

module namespace qh = "http://noslogan.org/components/hub-queue/queue-handler";

import module namespace qc = "http://noslogan.org/components/hub-queue/queue-config" at "queue-config.xqy";
import module namespace qe = "http://noslogan.org/components/hub-queue/queue-event" at "queue-event.xqy";
import module namespace ql = "http://noslogan.org/components/hub-queue/queue-log" at "queue-log.xqy";

import module namespace op = "http://marklogic.com/optic" at "/MarkLogic/optic.xqy";


declare namespace queue = "http://noslogan.org/hub-queue/";

(:~ Code that deals with queue documents in the database :)

declare option xdmp:mapping "false";



(:~ 
 : Get the URI for a new queue event.
 : @return a URI
 :)
 declare function qh:uri($id as xs:string) as xs:anyURI {
    xs:anyURI(qc:uri-prefix() || $id || '.json')
 };



(:~
 : Store an event to the queue
 : @param $enty the queue event to be written
 : @return the URI of the newly created 
 :)
 declare function qh:write($event as element(queue:event)) as xs:string {

    if (xdmp:database() = xdmp:database(qc:database())) 
        then
            let $_ := xdmp:security-assert(qc:queue-privilege, 'execute')
            let $uri := qh:uri(qe:id($event))
            return 
            (
                xdmp:document-insert(
                    $uri,
                    $event,
                    map:new() 
                        => map:with("collections", qc:collection())
                        => map:with("permissions", qc:permissions())
                        => map:with('metadata', map:new() 
                            => map:with(qc:status-metadata-name(), qc:status-new())
                            => map:with(qc:timestamp-metadata-name(), fn:current-dateTime())
                        )
                ), 
                ql:trace-uris("New event", $uri),
                $uri
            )
        else xdmp:invoke-function( 
            function() { qh:write($event) }, 
                map:new() 
                    => map:with("database", qc:database()
                    => map:with("isolation", "different-transaction")
                    => map:with("update", "true")))
};

(:~
 : Mark one or more events with a status and timestamp 
 : Queue status is defined by a metadata value. Setting status also updates
 : the queue timestamp;
 : This is not wrapped in a transaction as status should be set on multiple URIs at a time.
 : @param $uris the URIs of the event(s) to be updated.
 : @param $status the new status to be set
 : @return empty sequence
~:)
declare function qh:set-status($uris as xs:string, $status as xs:string) as empty-sequence() {

    let $_ := xdmp:security-assert(qc:queue-privilege, 'execute')
    let $_ := for $uri in $uris return  xdmp:document-set-metadata($uri,
        xdmp:document-get-metadata($uri)
            => map:with('status', $status)
            => map:with('timestamp', fn:current-dateTime()))

    return (
        ql:trace-uris("Status updated to  " || $status, $uris),
        ql:audit-events("Status set to " || $status, $uris, if (qc:detailed-log()) then  ($uris ! fn:doc(.)) else (), (), (), ())
    )
};


(:~
 : Get N event URIs from the queue, setting the status if a status is provided
 : Events are retrieved in time order (oldest first)
 : @param $count the number of event URIs to retrieve from the queue
 : @param $current-status the status of the events to be retrieved
 : @param $new-status the status to be set if required
 : @return a sequence of document uris
 :)
 declare function qh:get-event-uris($count as xs:positiveInteger, $current-status as xs:string, $new-status as xs:string?) as xs:string* {

    (
        xdmp:security-assert(qc:queue-privilege, 'execute'),
        xdmp:invoke-function( function() {

            let $results := (op:from-view('queue', 'queue')
                => op:order-by('updated')
                => op:where(op:eq(op:col('status'), $current-status))
                => op:select('uri')
                => op:limit($count)
                => op:result('object')) ! map:get(., 'queue.queue.uri')

            let $_ := if (fn:exists($new-status)) 
                then $results ! qh:set-status(., $new-status)
                else ()

            return $results

        }, map:new() 
            => map:with("database", xdmp:database(qc:database()))
            => map:with("isolation", "different-transaction")
            => map:with("update", "true"))
    )
 };


 (:~
 : Get N event dcouments from the queue, setting the status if a status is provided
 : Events are retrieved in time order (oldest first)
 : @param $count the number of event documents to retrieve from the queue
 : @param $current-status the status of the events to be retrieved
 : @param $new-status the status to be set if required
 : @return a sequence of queue:event nodes
 :)
 declare function qh:get-event-documents($count as xs:positiveInteger, $current-status as xs:string, $new-status as xs:string?) as element(queue:event)* {

    (
        xdmp:security-assert(qc:queue-privilege, 'execute'),
        xdmp:invoke-function( function() {

            let $results := (op:from-view('queue', 'queue', ()) 
                => op:order-by('updated')
                => op:where(op:eq(op:col('status'), $current-status))
                => op:select('uri')
                => op:limit($count)
                => op:result('object')) ! map:get(., 'queue.queue.uri')

            let $_ := if (fn:exists($new-status)) 
                then $results ! qh:set-status(., $new-status)
                else ()

            return $results ! fn:doc(.)/node()

        }, map:new() 
            => map:with("database", xdmp:database(qc:database()))
            => map:with("isolation", "different-transaction")
            => map:with("update", "true"))
    )
 };

(:~ 
 : Handle physical deletion of events when either failed or completed 
 : The delete step also logs the deletion. If detailed logging is enabled then
 : the events themselves are logged too (so they are retrieved before deletion)
 : @param $uris the URIs of the events to delete
 : @return empty sequence
:)
declare function qh:event-uris-for-deletion() as xs:string* {

    let $_ := xdmp:security-assert(qc:queue-privilege, 'execute')

    return (op:from-view('queue', 'queue', ()) 
        => op:order-by('updated')
        => op:where(op:or(
            op:eq(op:col('status'), qc:status-failed()),
            op:eq(op:col('status'), qc:status-finished())))
        => op:select('uri')
        => op:result('object')) ! map:get(., 'queue.queue.uri')

  };

(:~ 
 : Handle physical deletion of events when either failed or completed 
 : The delete step also logs the deletion. If detailed logging is enabled then
 : the events themselves are logged too (so they are retrieved before deletion)
 : @param $uris the URIs of the events to delete
 : @return empty sequence
:)
declare function qh:delete-events($uris as xs:string*) as empty-sequence() {

    let $_ := xdmp:security-assert(qc:queue-privilege, 'execute')

    let $events := xdmp:eager(if (qc:detailed-log()) then  ($uris ! fn:doc(.)) else ())
    let $statuses := xdmp:eager(if (qc:detailed-log()) then ($events ! qe:event-status(.)) else ())
    let $timestamps := xdmp:eager(if (qc:detailed-log()) then ($events ! qe:event-timestamp(.)) else ())

    let $_ := $uris ! xdmp:document-delete(.)

    return ql:audit-events("Events deleted", $uris, $events, $statuses, $timestamps)

  };



(:~
 : Given an event URI, fetch the event and set the status to a new value if provided
 : @param $uri
 : @param $status an optional status
 : @return the event
 :)
 declare function qh:get-event($uri as xs:string, $status as xs:string?) as element(queue:event)? {
    (   
        xdmp:security-assert(qc:queue-privilege, 'execute'),
        if (fn:exists($tatus)) then qh:set-status($uri, $status) else (),
        xdmp:invoke-function( function() { fn:doc($uri) }, map:new() => map:with('database', qc:database())
    )
 };