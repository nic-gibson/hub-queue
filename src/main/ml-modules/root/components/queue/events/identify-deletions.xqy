xquery version "1.0-ml";

import module namespace qc = "http://noslogan.org/components/hub-queue/queue-config" at "/components/queue/queue-config.xqy";
import module namespace qh = "http://noslogan.org/components/hub-queue/queue-handler" at "/components/queue/queue-handler.xqy";


declare namespace queue = "http://noslogan.org/hub-queue/";
declare namespace q="http://noslogan.org/hub-queue/";

declare variable $q:source as xs:string external;
declare variable $q:type as xs:string external;
declare variable $q:payload as item() external;
declare variable $q:config as element(q:config)? external;
declare variable $q:uris as xs:string* external;


(:~ 
 : This queue handler identifies events for deletion. Events for deletion are found via
 : search and added to a clear type event which is then used to trigger the actual deletion
:)

let $uris :=  qh:event-uris-for-deletion(qc:max-uris)

