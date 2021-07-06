xquery version "1.0-ml";

module namespace qh = "http://noslogan.org/components/hub-queue/queue-handler";

import module namespace qc = "http://noslogan.org/components/hub-queue/queue-config" at "queue-config.xqy";
import module namespace qe = "http://noslogan.org/components/hub-queue/queue-event" at "queue-event.xqy";
import module namespace ql = "http://noslogan.org/components/hub-queue/queue-log" at "queue-log.xqy";

import module namespace op = "http://marklogic.com/optic" at "/MarkLogic/optic.xqy";


declare namespace queue = "http://noslogan.org/hub-queue";

(:~ Code that deals with queue documents in the database :)

declare option xdmp:mapping "false";



(:~ 
 : Get the URI for a new queue event.
 : @return a URI
 :)
 declare function qh:uri($id as xs:string) as xs:anyURI {
    xs:anyURI(qc:uri-prefix() || $id || ".xml")
 };


(:~
 : Given a queue id, get a new status URI for it.
 : The status for a queue event is a different document. Whenever status
 : changes, the existing status is deleted and a new one written so the
 : status document URI has to be distinct too.
 :)
declare function qh:status-uri($id as xs:string, $status as xs:string) as xs:anyURI {
    xs:anyURI(qc:uri-prefix() || $id || "/status/" || $status || ".xml")
};

(:~
 : Store an event to the queue
 : @param $enty the queue event to be written
 : @return the ID of the newly created event
 :)
 declare function qh:write($event as element(queue:event)) as xs:string {

    if (xdmp:database() = xdmp:database(qc:database())) 
        then
            let $uri := qh:uri(qe:id($event))
            return 
            (
                xdmp:document-insert(
                    $uri,
                    $event,
                    map:new() 
                        => map:with("collections", (qe:id($event), qc:collection()))
                        => map:with("permissions", qc:permissions())
                ), 
                qh:set-status(qe:id($event), qc:new-status()),
                ql:trace-ids("New event", qe:id($event)),
                qe:id($event)
            )[last()]
        else xdmp:invoke-function( 
            function() { qh:write($event) }, 
                map:new() 
                    => map:with("database", qc:database()
                    => map:with("isolation", "different-transaction")
                    => map:with("update", "true")))
};


(:~
 : Mark one or more events with a status and timestamp given the event id
 : Queue status is defined by a status document. Setting status also updates
 : the queue timestamp. If there is an existing status it is deleted when the new one is added.
 : If the current status is "executing" we add a second status rather than update because
 : we would be deleting a document in the transaction we added it in otherwise. There is a scheduled
 : task running every minute to clean up that status.
 : @param $event-ids - the ids of the event(s) to be updated.
 : @param $status the new status to be set
 : @return the new status
~:)
declare function qh:set-status($event-ids as xs:string*, $status as xs:string) as xs:string* {
    
    for $id in $event-ids 
        let $uri := qh:status-uri($id, $status)
        let $current-status := qh:get-status($id)
        let $deleted := if ($current-status = qc:executing-status()) 
            then () 
            else if (fn:exists($current-status))
                then xdmp:document-delete(qh:status-uri($id, $current-status))
                else ()
        return (xdmp:document-insert($uri, 
            element queue:status {
                element queue:id { $id },
                element queue:value { $status },
                element queue:updated { fn:current-dateTime() }
            },
            map:new() 
                => map:with("collections", ($id, qc:collection()))
                => map:with("permissions", qc:permissions())
            ), 
            $status
        )
};

(:~
 : Get the status of an event.
 : Queue status is defined by a status document. We find the most recently updated
 : status document and return the status value from it. 
 : @param $event-id - the ids of the event
 : @return status string if the event id maps to a status
~:)
declare function qh:get-status($event-id as xs:string) as xs:string? {
    
    let $results := op:from-view("queue", "status") 
        => op:order-by(op:desc(op:col("updated")))
        => op:where(op:eq(op:col("id"), $event-id))   
        => op:select(op:col("status"))
        => op:limit(1)
        => op:result()

    return if (fn:exists($results)) then map:get($results, "queue.status.status") else ()
};


(:~ 
 : Get the timestamp of an event 
 : This is stored in the status document for the event so we query
 : for it just like status 
 : @param $event-id the id of the event of interest 
 : @return the timestamp of the event 
 :)
declare function qh:get-timestamp($event-id as xs:string) as xs:dateTime? {
    
    let $results := op:from-view("queue", "status") 
        => op:order-by(op:desc(op:col("updated")))
        => op:where(op:eq(op:col("id"), $event-id))   
        => op:select(op:col("updated"))
        => op:limit(1)
        => op:result()

    return map:get($results, "queue.status.updated")
};

(:~
 : Get N event ids from the queue, setting the status if a new status is provided
 : Events are retrieved in priority then time order (oldest first)
 : @param $count the number of event ids to retrieve from the queue
 : @param $current-status the status of the events to be retrieved
 : @param $new-status the status to be set if required
 : @return a sequence of document uris
 :)
 declare function qh:get-event-ids($count as xs:positiveInteger, $current-status as xs:string, $new-status as xs:string?) as xs:string* {

    xdmp:invoke-function( function() {

        let $results := (op:from-view("queue", "status")
            => op:where(op:eq(op:col("status"), $current-status))
            => op:select("id")
            => op:limit($count)
            => op:result("object")) ! map:get(., "queue.status.id")

        let $_ := if (fn:exists($new-status)) 
            then qh:set-status($results, $new-status)
            else ()

        return $results

    }, map:new() 
        => map:with("database", xdmp:database(qc:database()))
        => map:with("isolation", "different-transaction")
        => map:with("update", "true"))

 };


 (:~
 : Get N event nodes from the queue, setting the status if a status is provided
 : Events are retrieved in time order (oldest first)
 : @param $count the number of event documents to retrieve from the queue
 : @param $current-status the status of the events to be retrieved
 : @param $new-status the status to be set if required
 : @return a sequence of queue:event nodes
 :)
 declare function qh:get-event-nodes($count as xs:positiveInteger, $current-status as xs:string, $new-status as xs:string?) as element(queue:event)* {

     xdmp:invoke-function( function() {

        let $results := (op:from-view("queue", "status")
            => op:where(op:eq(op:col("status"), $current-status))
            => op:select("id")
            => op:limit($count)
            => op:result("object")) ! map:get(., "queue.status.id")

        let $_ := if (fn:exists($new-status)) 
            then qh:set-status($results, $new-status)
            else ()

        return $results ! fn:doc(qh:uri(.))/node()

    }, map:new() 
        => map:with("database", xdmp:database(qc:database()))
        => map:with("isolation", "different-transaction")
        => map:with("update", "true"))
 };

(:~ 
 : Identify events that are to be deleted and return their
 : ids
 : @return sequence of ids
:)
declare function qh:event-uris-for-deletion() as xs:string* {

    (op:from-view("queue", "queue", ()) 
        => op:order-by(op:asc(op:col("updated")))
        => op:order-by(op:desc(op:col("priority")))
        => op:where(op:or(
            op:eq(op:col("status"), qc:failed-status()),
            op:eq(op:col("status"), qc:finished-status())))
        => op:select("uri")
        => op:result("object")) ! map:get(., "queue.queue.id")
};


(:~ 
 : Find events with new status that are, in effect, timed out. 
 : These have been marked as new in the queue for too long.
 : We define "too long" as the updated time being longer ago than
 : our timeout. 
 : @return the ids of the timed out documents
:)
declare function qh:new-event-ids-for-timeout() as xs:string* {
    qh:timeouts-by-status(qc:new-status(), qc:new-timeout())
};


(:~ 
 : Find events with pending status that are, in effect, timed out. 
 : These have been marked as pending in the queue for too long.
 : We define "too long" as the updated time being longer ago than
 : our timeout. 
 : @return the ids of the timed out documents
:)
declare function qh:pending-event-ids-for-timeout() as xs:string* {
    qh:timeouts-by-status(qc:pending-status(), qc:pending-timeout())
};


(:~ 
 : Find events with executing status that are, in effect, timed out. 
 : These have been marked as executing in the queue for too long.
 : We define "too long" as the updated time being longer ago than
 : the maximum execution time for a request
 : @return the ids of the timed out documents
:)
declare function qh:execution-event-ids-for-timeout() as xs:string* {
    qh:timeouts-by-status(qc:executing-status(), qc:execution-timeout())
};



(:~ 
 : Handle physical deletion of events when either failed or completed 
 : The delete step also logs the deletion. If detailed logging is enabled then
 : the events themselves are logged too (so they are retrieved before deletion)
 : The query uses cts:uris to find documents in the main queue collection and
 : one of the id based collections which finds both status and event documents
 : @param $uris the ids of the events to delete
 : @return empty sequence
:)
declare function qh:delete-events($ids as xs:string*) as empty-sequence() {

    let $events := xdmp:eager(if (qc:detailed-log()) then  ($ids ! fn:doc(qh:uri(.))) else ())
    let $statuses := xdmp:eager(if (qc:detailed-log()) then ($events ! qh:get-status(.)) else ())
    let $timestamps := xdmp:eager(if (qc:detailed-log()) then ($events ! qh:get-timestamp(.)) else ())

    let $_ := cts:uris((), (), cts:and-query((
        cts:collection-query(qc:collection),
        cts:collection-query($ids)
        ))) ! xdmp:document-delete(.)

    return ql:audit-events("Events deleted", $ids, $events, $statuses, $timestamps, ())
};



(:~
 : Given an event URI, fetch the event and set the status to a new value if provided
 : @param $uri
 : @param $status an optional status
 : @return the event
 :)
declare function qh:get-event($id as xs:string, $status as xs:string?) as element(queue:event)? {
    
    let $new-status := if (fn:exists($status)) then qh:set-status($id, $status) else ()
    return xdmp:invoke-function( 
        function() { fn:doc(qh:uri($id))/queue:event }, 
            map:new() => map:with("database", xdmp:database(qc:database())))
};


(:~ 
 : Search for event ids by age and current status. Any document older than the
 : timeout with the desired status is returned
 : @param $status the current status
 : @param $duration an xs:dayTimeDuration to be subtracted from the current time 
 : @return a sequence of zero or more ids
:)
declare function qh:timeouts-by-status($status as xs:string, $duration as xs:dayTimeDuration) as xs:string* {

    let $max-age := fn:current-dateTime() - $duration

    return (op:from-view("queue", "queue", ())
        => op:order-by(op:desc(op:col("priority")))        
        => op:where(op:and(
            op:eq(op:col("status"), $status),
            op:lt(op:col("updated"), $max-age)))
        => op:select("id")
        => op:result("object")) ! map:get(., "queue.queue.id")
};

(:~ 
 : Clean up status records. When an executing status completes we add a new status
 : rather than replace it to avoid transaction failures. This function finds all 
 : events with more than one status document and deletes all bar the newest.
 : NOTE - this function is amped so the task can run as nobody
 : @return empty sequence
 :)
declare function qh:status-cleanup() as empty-sequence() {

    let $event-ids := (op:from-view("queue", "status")
        => op:order-by(op:asc(op:col("updated")))
        => op:group-by(op:col("id"), op:count("CountOfEvent", "status"))
        => op:where(op:gt(op:col("CountOfEvent"), 1))
        => op:select("id")
        => op:result()) ! map:get(., "id")

    (: for each of the above look for the status documents. We need to check
       if one is 'executing' and the other is 'finished' or 'failed'. If so
       then delete the executing one.  :)
    let $to-delete := for $id in ($event-ids ! map:get(., "id"))
        let $status-docs := cts:search(fn:doc(), 
            cts:and-query((
                cts:collection-query(qc:collection()),
                cts:element-query(xs:QName("queue:status"), 
                    cts:element-value-query(xs:QName("queue:id"), $id)
                )
            ))
        )

        (: check that at least one status is executing and one other is failed or finished :)
        return if ($status-docs/queue:status/queue:value = qc:executing-status() and 
            $status-docs/queue:status/queue:value = (qc:finished-status(), qc:failed-status()))
            then $status-docs[queue:status/queue:value = qc:executing-status()] ! xdmp:node-uri(.)
            else ()

    return $to-delete ! xdmp:document-delete(.)
};




(:~ Completely clear the queue :)
declare function qh:clear-queue() as empty-sequence() {
    xdmp:collection-delete(qc:collection())
};

