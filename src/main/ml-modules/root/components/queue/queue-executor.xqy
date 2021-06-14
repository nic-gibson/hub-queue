xquery version "1.0-ml";

module namespace qx = "http://marklogic.com/community/components/queue/queue-executor";

declare namespace queue = "http://marklogic.com/community/queue";

declare option xdmp:mapping "false";

(:~
 : Functions to execute processes for the queue.
 : 
 :)



(:~
 : Execute a javascript event executor. 
 : This function creates a wrapper to eval (it's not easy to call JS from XQuery)
 : That wrapper includes an import of the module and wraps the actual call in a try/catch
 : statement so that we can return enough information across the language boundary to actually
 : handle the error cleanly.
 : @param $config - the configuration element
 : @param $source - the event source
 : @param $type - the event type
 : @param $payload - the event payload
 : @param $uris - the event URIs
 : @return the result of the called module. 
 :)
 declare function qx:exec-javascript($executor as element(q:executor), $source as xs:string, $type as xs:string, $payload as item(), $uris as xs:string*) as xs:string? {
     let $module := $executor/q:module/data()
     let $config := $executor/q:config
     let $js := '
        "use strict";
        var config;
        var source;
        var type;
        var payload;
        
        const executor = require(' || $module || ');
        '
 }