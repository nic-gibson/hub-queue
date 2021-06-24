xquery version "1.0-ml";

import module namespace qc = "http://noslogan.org/components/hub-queue/queue-config" at "/components/queue/queue-config.xqy";
import module namespace qh = "http://noslogan.org/components/hub-queue/queue-handler" at "/components/queue/queue-handler.xqy";
import module namespace ql = "http://noslogan.org/components/hub-queue/queue-log" at "/components/queue/queue-log.xqy";


declare namespace queue = "http://noslogan.org/hub-queue";

declare variable $queue:source as xs:string external;
declare variable $queue:type as xs:string external;
declare variable $queue:payload as item() external;
declare variable $queue:config as element(q:config)? external;
declare variable $queue:uris as xs:string* external;


(:~ 
 : Process any events which simple require a status update. The same status must be applied
 : to every URI listed in the event and must be stored as the value of the payload.
 :)


(
    qh:set-status($queue:uris, $queue:payload),
    qc:status-finished()
)
    
