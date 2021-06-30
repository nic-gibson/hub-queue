xquery version "1.0-ml";

import module namespace ql = "http://noslogan.org/components/hub-queue/queue-log" at "/components/hub-queue/queue-log.xqy";

declare namespace queue = "http://noslogan.org/hub-queue";

declare variable $queue:source as xs:string external;
declare variable $queue:type as xs:string external;
declare variable $queue:payload as item() external;
declare variable $queue:config as element(queue:config)? external;
declare variable $queue:uris as xs:string* external;


(:~ 
 : This is a test event handler. It deals with events of the following type
 :      * http://noslogan.org/hub-queue//event/ping
 : This writes a message to the error log and returns the finished status
 : and updates the collections on each of the URIs to add "PINGED" to them
 :)
(
    ql:log-uris("PING EVENT", $queue:uris, $queue:source, $queue:type),
    $queue:uris ! xdmp:document-add-collections(., 'PINGED')
)
