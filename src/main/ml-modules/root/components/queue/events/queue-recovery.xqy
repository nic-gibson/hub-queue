xquery version "1.0-ml";

import module namespace qc = "http://marklogic.com/community/components/queue/queue-config" at "/components/queue/queue-config.xqy";
import module namespace qh = "http://marklogic.com/community/components/queue/queue-handler" at "/components/queue/queue-handler.xqy";


declare namespace queue = "http://marklogic.com/community/queue";
declare namespace q="http://marklogic.com/community/queue";

declare variable $q:source as xs:string external;
declare variable $q:type as xs:string external;
declare variable $q:payload as item() external;
declare variable $q:config as element(q:config)? external;
declare variable $q:uris as xs:string* external;


(:~ 
 : This is a multi purpose queue handler. It deals with events of the following types
 :      * reset
 :      * clear
 : Both of these should have the source set to 'queue-internal'. The payload is ignored
 : for this event and there is no config.
 :)

(: Reset - actually removes documents from the queue and logs that it's done :)
if ($q:type = qc:event-clear())
    then qh:delete-events($q:uris)
else if ($q:type = qc:event-reset())
    then qh:set-status($q:uris, qc:status-new())
else ()


