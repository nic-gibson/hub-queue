xquery version "1.0-ml";

module namespace ql = "http://noslogan.org/components/hub-queue/queue-log";

import module namespace qc = "http://noslogan.org/components/hub-queue/queue-config" at "queue-config.xqy";
import module namespace qe = "http://noslogan.org/components/hub-queue/queue-event" at "queue-event.xqy";


declare namespace queue = "http://noslogan.org/hub-queue";

(:~ Code that deals with queue logging :)

declare option xdmp:mapping "false";

(:~
 : Write an audit message for zero or more events
 : @param $message the text for this log entry
 : @param $ids - a sequence of event ids
 : @param $events a sequence of zero or more events (in order with $ids)
 : @param $status the matching statuses for the nodes (used when documents have been deleted)
 : @param $timestamp the matching timestamps for the nodes (used when documents have been deleted)
 : @param $errors any errors to be included in the audit
 : @return empty sequence
 :)
declare function ql:audit-events($message as xs:string, $ids as xs:string*, $events as element(queue:event)*, $statuses as xs:string*, $timestamps as xs:dateTime*, $errors as item()*) as empty-sequence() {

    if (xdmp:database() = xdmp:database(qc:log-database())) 
        then xdmp:invoke-function( function() { xdmp:document-insert(
            qc:log-prefix() || sem:uuid-string() || ".xml",
            element queue-log {
                element queue:message { $message },
                element queue:timestamp { fn:current-dateTime() },
                element queue:transaction { xdmp:transaction() },
                element queue:host { xdmp:host-name()},
                element queue:user { xdmp:get-current-user() },
                element queue:ids {
                    $ids ! element queue:id { . }
                },
                if (fn:exists($errors))
                    then element queue:errors { $errors }
                    else (),
                element queue:events {
                    for $event at $pos in $events return  element queue:event {
                        $event/*,
                        element queue:status { $statuses[$pos] },
                        element queue:update-timestamp { $timestamps[$pos] } 
                    }
                  }
            },
            map:new() 
                => map:with('collections', qc:log-collection())
                => map:with('permissions', qc:permissions())
        ) }, map:new() => map:with('isolation', 'different-transaction') => map:with('update', 'true'))
        else xdmp:invoke-function( 
            function() { ql:audit-events($message, $ids, $events, $statuses, $timestamps, ()) }, 
                map:new() => map:with("database", xdmp:database(qc:log-database())))
};

(:~ 
 : Write trace events for event ids with a bit of additional data when enabled
 : @param $message - the message
 : @param $ids - sequence of ids
 : @return empty sequence
:)
declare function ql:trace-ids($message as xs:string, $ids as xs:string*) as empty-sequence() {
    ql:trace-ids($message, $ids, (), ())
};

(:~ 
 : Write trace events for event ids with a bit of additional data when enabled
 : @param $message - the message
 : @param $ids - sequence of ids
 : @param $source - optional source info
 : @param $type - optional type info
 : @return empty sequence
:)
declare function ql:trace-ids($message as xs:string, $ids as xs:string*, $source as xs:string?, $type as xs:string?) as empty-sequence() {
    if (xdmp:trace-enabled(qc:trace()))
        then xdmp:trace(qc:trace(), ql:format-with-ids($message, $ids, $source, $type, ()))
        else ()
};

(:~ 
 : Log event ids to the error log with a bit of additional data as INFO level logging
 : @param $message - text to log
 : @param $ids - sequence of ids
 : @return empty sequence
:)
declare function ql:log-ids($message as xs:string, $ids as xs:string*) as empty-sequence() {
    ql:log-ids($message, $ids, (), ())
};

(:~ 
 : Log event ids to the error log with a bit of additional data as INFO level logging
 : @param $message - text to log
 : @param $ids - sequence of ids
 : @param $source - optional source string
 : @param $type - optional type string
 : @return empty sequence
:)
declare function ql:log-ids($message as xs:string, $ids as xs:string*, $source as xs:string?, $type as xs:string?) as empty-sequence() {
    xdmp:log(ql:format-with-ids($message, $ids, $source, $type, ()))
};

(:~ 
 : Log event ids to the error log with a bit of additional data as WARNING level logging
 : @param $message - text to log
 : @param $ids - sequence of ids
 : @return empty sequence
:)
declare function ql:warn-ids($message as xs:string, $ids as xs:string*) as empty-sequence() {
    ql:warn-ids($message, $ids, (), ())
};

(:~ 
 : Log event ids to the error log with a bit of additional data as WARNING level logging
 : @param $message - text to log
 : @param $ids - sequence of ids
 : @param $source - optional source string
 : @param $type - optional type string
 : @return empty sequence
:)
declare function ql:warn-ids($message as xs:string, $ids as xs:string*, $source as xs:string?, $type as xs:string?) as empty-sequence() {
    xdmp:log(ql:format-with-ids($message, $ids, $source, $type, ()), 'warning')
};



(:~ 
 : Log event ids to the error log with a bit of additional data as ERROR level logging
 : @param $message - text to log
 : @param $ids - sequence of ids
 : @return empty sequence
:)
declare function ql:error-ids($message as xs:string, $error as item()?, $ids as xs:string*) as empty-sequence() {
    ql:error-ids($message, $error, $ids, (), ())
};

(:~ 
 : Log event ids to the error log with a bit of additional data as ERROR level logging
 : @param $message - text to log
 : @param $ids - sequence of ids
 : @param $source - optional source string
 : @param $type - optional type string
 : @return empty sequence
:)
declare function ql:error-ids($message as xs:string, $error as item()?, $ids as xs:string*, $source as xs:string?, $type as xs:string?) as empty-sequence() {
    xdmp:log(ql:format-with-ids($message, $ids, $source, $type, $error), 'error')
};

(:~ 
 : Write trace events with a bit of additional data when enabled
 : @param $message - text to log
 : @param $events - sequence of event elements
 : @return empty sequence
:)
declare function ql:trace-events($message, $events) as empty-sequence() {
    ql:trace-events($message, $events, (), ())
};

(:~ 
 : Write trace events with a bit of additional data when enabled
 : @param $message - text to log
 : @param $events - sequence of event elements
 : @param $source - optional source string
 : @param $type - optional type string
 : @return empty sequence
:)
declare function ql:trace-events($message as xs:string, $events as element(queue:event)*, $source as xs:string?, $type as xs:string?) as empty-sequence() {
    if (xdmp:trace-enabled(qc:trace()))
        then xdmp:trace(qc:trace(), ql:format-with-events($message, $events, $source, $type, ()))
        else ()
};

(:~ 
 : Log events to the error log with a bit of additional data when enabled as INFO level logging
 : @param $message
 : @param $events 
 : @return empty sequence
:)
declare function ql:log-events($message as xs:string, $events as element(queue:event)*) as empty-sequence() {
    ql:log-events($message, $events, (), ())
};

(:~ 
 : Log events to the error log with a bit of additional data when enabled as INFO level logging
 : @param $message
 : @param $events 
 : @param $source the source string if provided
 : @param $type - the type string if provided
 : @return empty sequence
:)
declare function ql:log-events($message as xs:string, $events as element(queue:event)*, $source as xs:string?, $type as xs:string?) as empty-sequence() {
    xdmp:log(ql:format-with-events($message, $events, $source, $type, ()))
};

(:~ 
 : Log events to the error log with a bit of additional data when enabled as WARNING level logging
 : @param $message
 : @param $events 
 : @return empty sequence
:)
declare function ql:warn-events($message as xs:string, $events as element(queue:event)*) as empty-sequence() {
    ql:warn-events($message, $events, (), ())
};

(:~ 
 : Log events to the error log with a bit of additional data when enabled as WARNING level logging
 : @param $message
 : @param $events 
 : @param $source the source string if provided
 : @param $type - the type string if provided
 : @return empty sequence
:)
declare function ql:warn-events($message as xs:string, $events as element(queue:event)*, $source as xs:string?, $type as xs:string?) as empty-sequence() {
    xdmp:log(ql:format-with-events($message, $events, $source, $type, ()), 'warning')
};

(:~ 
 : Log events to the error log with a bit of additional data when enabled as ERROR level logging
 : @param $message
 : @param $error - error if provided
 : @param $events 
 : @return empty sequence
:)
declare function ql:error-events($message as xs:string, $error as item()?, $events as element(queue:event)*) as empty-sequence() {
    ql:error-events($message, $error, $events, (), ())
};

(:~ 
 : Log events to the error log with a bit of additional data when enabled as ERROR level logging
 : @param $message
 : @param $events 
 : @param $source the source string if provided
 : @param $type - the type string if provided
 : @return empty sequence
:)
declare function ql:error-events($message as xs:string, $error as item()?, $events as element(queue:event)*, $source as xs:string?, $type as xs:string?) as empty-sequence() {
    xdmp:log(ql:format-with-events($message, $events, $source, $type, $error), 'error')
};

(:~ 
 : Just construct the string used to write a log or trace
 : @param $message - trace/log message
 : @param $ids - associated ids
 : @param $source the source string if provided
 : @param $type - the type string if provided
 : @param $error - error if provided
:)
declare private function ql:format-with-ids($message as xs:string, $ids as xs:string*, $source as xs:string?, $type as xs:string?, $error as item()?) {
 fn:string-join((
    "message=" || $message,
    if (fn:exists($source)) then "source=" || $source else (),
    if (fn:exists($type)) then "type=" || $type else (),
    "transaction=" || xdmp:transaction(),
    "user=" || xdmp:get-current-user(),
    "ids=" || fn:string-join($ids, ', '),
    if (fn:exists($error)) then "error=" || xdmp:quote($error) else ()), ' || ')
};

(:~ 
 : Just construct the string used to write a log or trace of events
 : @param $message - trace/log message
 : @param $events - associated events
 : @param $source the source string if provided
 : @param $type - the type string if provided
 : @param $error - error if provided
:)
declare private function ql:format-with-events($message as xs:string, $events as element(queue:event)*, $source as xs:string?, $type as xs:string?, $error as item()?) {
 fn:string-join((
    "message=" || $message,
    if (fn:exists($source)) then "source=" || $source else (),
    if (fn:exists($type)) then "type=" || $type else (),   
    "transaction=" || xdmp:transaction(),
    "user=" || xdmp:get-current-user(),
    "events=" || ql:format-events($events),
    if (fn:exists($error)) then "error=" || xdmp:quote($error) else ()), ' || ')
};

(:~ 
 : Simple format of a sequence of events.
 :)
declare private function ql:format-events($events as element(queue:event)) as xs:string {
    fn:string-join(($events ! ("&#x09;" || xdmp:quote(.))), "&#x0A;")
};
