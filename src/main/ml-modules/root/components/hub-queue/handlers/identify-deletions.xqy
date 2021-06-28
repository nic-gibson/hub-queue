xquery version "1.0-ml";

import module namespace qc = "http://noslogan.org/components/hub-queue/queue-config" at "/components/hub-queue/queue-config.xqy";
import module namespace qh = "http://noslogan.org/components/hub-queue/queue-handler" at "/components/hub-queue/queue-handler.xqy";
import module namespace qe = "http://noslogan.org/components/hub-queue/queue-event" at "/components/hub-queue/queue-event.xqy";

declare namespace queue = "http://noslogan.org/hub-queue";

declare variable $queue:source as xs:string external;
declare variable $queue:type as xs:string external;
declare variable $queue:payload as item() external;
declare variable $queue:config as element(queue:config)? external;
declare variable $queue:uris as xs:string* external;


(:~ 
 : This queue handler identifies events for deletion. Events for deletion are found via
 : search and added to a clear type event which is then used to trigger the actual deletion
:)

let $uris := qh:event-uris-for-deletion()
let $event-count := xs:integer(fn:ceil(fn:count($uris) div qc:max-uris()))
let $new-uris := qe:create-batch(qc:event-clear(), qc:internal-source(), (), $uris) ! qh:write(.)

return qc:finished-status()