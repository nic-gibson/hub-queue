xquery version "1.0-ml";

import module namespace ql = "http://noslogan.org/components/hub-queue/queue-log" at "/components/hub-queue/queue-log.xqy";
import module namespace ql = "http://noslogan.org/components/hub-queue/queue-event" at "/components/hub-queue/queue-event.xqy";
import module namespace qh = "http://noslogan.org/components/hub-queue/queue-handler" at "/components/hub-queue/queue-handler.xqy";

declare namespace queue = "http://noslogan.org/hub-queue";

declare variable $q:source as xs:string external;
declare variable $q:type as xs:string external;
declare variable $q:payload as item() external;
declare variable $q:config as element(q:config)? external;
declare variable $q:uris as xs:string* external;


(:~ 
 : Handle the heartbeat event used to identify timed out events. Timeouts occur in three ways --
 : 1) Events left in pending state for too long. This event causes the event to be moved back to the new state. "Too long" is defined as exceeding the pending
 : timeout defined via config. 
 : 2) Events left in the executing state longer than the maximum request period.
 : 3) Events left in the new state longer than the allowed time (the new event time defined via config)
:)

let $pending := qe:create-batch(qc:event-update-status(), qc:internal-source(), qc:status-failed(), qh:pending-event-uris-for-timeout())
let $executing := qe:create-batch(qc:event-update-status(), qc:internal-source(), qc:status-failed(), qh:executing-event-uris-for-timeout())
let $new := qe:create-batch(qc:event-update-status(), qc:internal-source(), qc:status-failed(), qh:new-event-uris-for-timeout())

let $_ := ($pending, $executing, $new) ! qh:write(.)

return qc:status-finished()
