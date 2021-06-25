xquery version "1.0-ml";

import module namespace qc = "http://noslogan.org/components/hub-queue/queue-config" at "/components/hub-queue/queue-config.xqy";
import module namespace qh = "http://noslogan.org/components/hub-queue/queue-handler" at "/components/hub-queue/queue-handler.xqy";
import module namespace ql = "http://noslogan.org/components/hub-queue/queue-log" at "/components/hub-queue/queue-log.xqy";


declare namespace queue = "http://noslogan.org/hub-queue";

declare variable $queue:source as xs:string external;
declare variable $queue:type as xs:string external;
declare variable $queue:payload as item() external;
declare variable $queue:config as element(q:config)? external;
declare variable $queue:uris as xs:string* external;


(:~ 
 : This is a multi purpose queue handler. It deals with events of the following types
 :      * http://noslogan.org/hub-queue/event/reset
 :      * http://noslogan.org/hub-queue/event/clear
 : Both of these should have the source set to 'http://noslogan.org/hub-queue/status/internal'. The payload is ignored
 : for this event and there is no config.
 :)

(: clear - actually removes documents from the queue and logs that it's done :)
if ($q:type = qc:event-clear())
    then qh:delete-events($queue:uris)

(: reset - sets the status back to new :)
else if ($q:type = qc:event-reset())
    then qh:set-status($queue:uris, qc:status-new())

(: We really shouldn't be here! :)
else ql:warn-uris("QUEUE RECOVERY with wrong type", $uris, $source, $type)
    
