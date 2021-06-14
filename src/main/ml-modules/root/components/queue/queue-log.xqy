xquery version "1.0-ml";

module namespace ql = "http://marklogic.com/community/components/queue/queue-log";

import module namespace qc = "http://marklogic.com/community/components/queue/queue-config" at "queue-config.xqy";
import module namespace qe = "http://marklogic.com/community/components/queue/queue-event" at "queue-event.xqy";


declare namespace queue = "http://marklogic.com/community/queue";

(:~ Code that deals with queue logging :)

declare option xdmp:mapping "false";

(:~
 : Write a log message for zero or more events, If logging is not in detail mode only the URIs will be 
 : be included in the log. Logs are written in XML because events are written in XML
 : @param $message the text for this log entry
 : @param $events a sequence of zero or more events (in order with $uris)
 : @param $status the matching statuses for the nodes (used when documents have been deleted)
 : @param $timestamp the matching timestamps for the nodes (used when documents have been deleted)
 : @return empty sequence
 :)
declare function ql:log-events($message as xs:string, $uris as xs:string*, $events as element(queue:event)*, $statuses as xs:string*, $timestamps as xs:dateTime*) as empty-sequence() {

    if (xdmp:database() = xdmp:database(qc:log-database())) 
        then xdmp:document-insert(
            qc:log-prefix() || sem:uuid-string() || ".xml",
            element queue-log {
                element queue:message { $message },
                element queue:timestamp { fn:current-dateTime() },
                element queue:transaction { xdmp:transaction() },
                element queue:host { xdmp:host-name()},
                element queue:user { xdmp:get-current-user() },
                element queue:uris {
                    $uris ! element queue:uri { . }
                },
                if (qc:detailed-log()) 
                    then element queue:events {
                        for $event at $pos in $events return  element queue:event {
                            $event/*,
                            element queue:status { (qe:event-status(.), $statuses[$pos])[1] },
                            element queue:update-timestamp { (qe:event-timestamp(.), $timestamps[$pos])[1] } 
                        }
                    }

                    else ()
            }
            ,
            map:new() 
                => map:with('collections', qc:log-collection())
                => map:with('permissions', qc:permissions())
        )
        else xdmp:invoke-function( 
            function() { ql:log-events($message, $uris, $events, $statuses, $timestamps) }, 
                map:new() => map:with("database", qc:log-database()))
};


(:~ 
 : Write trace events with a bit of additional data when enabled
 : @param $message
 : @param $uris
 : @return empty sequence
:)
declare function ql:trace($message, $uris) as empty-sequence() {
    if (xdmp:trace-enabled(qc:trace))
        then 
            xdmp:trace(qc:trace(), fn:string-join((
                "message=" || $message,
                "transaction=" || xdmp:transaction(),
                "user=" || xdmp:get-current-user(),
                "uris=" || fn:string-join($uris, ', ')

            ), ' || '))
        else ()
};