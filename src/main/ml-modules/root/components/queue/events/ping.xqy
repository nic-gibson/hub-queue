xquery version "1.0-ml";

import module namespace ql = "http://noslogan.org/components/hub-queue/queue-log" at "/components/queue/queue-log.xqy";

declare namespace queue = "http://noslogan.org/hub-queue/";

declare variable $q:source as xs:string external;
declare variable $q:type as xs:string external;
declare variable $q:payload as item() external;
declare variable $q:config as element(q:config)? external;
declare variable $q:uris as xs:string* external;


(:~ 
 : This is a test event handler. It deals with events of the following type
 :      * http://noslogan.org/hub-queue//event/ping
 : This simply writes a message to the error log and returns the finished status. 
 :)
ql:log-uris("PING EVENT", $uris, $source, $type)
