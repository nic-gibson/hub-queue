xquery version "1.0-ml";

module namespace qx = "http://noslogan.org/components/hub-queue/queue-executor";

import module namespace qc = "http://noslogan.org/components/hub-queue/queue-config" at "queue-config.xqy";
import module namespace ql = "http://noslogan.org/components/hub-queue/queue-log" at "queue-log.xqy";
import module namespace qe = "http://noslogan.org/components/hub-queue/queue-event" at "queue-event.xqy";
import module namespace qh = "http://noslogan.org/components/hub-queue/queue-handler" at "queue-handler.xqy";


declare namespace queue = "http://noslogan.org/hub-queue";

declare option xdmp:mapping "false";

(:~
 : Functions to execute processes for the queue.
:)


(:~ 
 : Given an event URI, load and process the event, setting the status
 : to the result of the query. process the event if it is found; if not
 : found just issure a warning. If the executor is not found, fail the event
 : and issue an error.
 : @param $uri the event URI
 : @return the new status set
:)
declare function qx:handle-event($uri as xs:string) as xs:string? {

    let $event := qh:get-event($uri, qc:executing-status())
    
    return if (fn:exists($event))
        then
            let $executor := qx:find-executor($event)
            return if (fn:exists($executor)) 
                then
                    let $status := (
                        qx:execute($executor, qe:source($event), qe:type($event), qe:payload($event), qe:uris($event)),
                        qc:finished-status())[1]
                    return (
                        qh:set-status($uri, $status),
                        ql:trace-events("Event executed", $event),
                        ql:audit-events("Event executed", $uri, $event, $status, (), ()),
                        $status
                    )
                else (
                    ql:audit-events("Event executor does not exist", $uri, $event, qc:failed-status(), (), ()),
                    ql:warn-events("Event executor does not exist", $event),
                    qh:set-status($uri, qc:failed-status()),
                    qc:failed-status()
                )

            else (
                ql:audit-events("Event URI does not exist", $uri, (), (), (), ()),
                ql:warn-uris("Event URI does not exist", $uri)
            )

};


(:~ 
 : Identify the appropriate queue executor for an event.
 : @param $event the event to search with
 : @return the matching event executor if found.
:)
declare function qx:find-executor($event as element(queue:event)) as element(queue:executor)? {

    xdmp:invoke-function(function() {
        (cts:search(
            fn:doc(),
            cts:element-query(xs:QName('queue:executor'),
                cts:and-query((
                    cts:element-value-query('queue:type', $event/queue:type),
                    cts:element-value-query('queue:source', $event/queue:source)
                ))))//queue:executor)[1]
    }, map:new() => map:with('database', xdmp:modules-database()))
};


(:~
 : Execute an event executor definition. 
 : This function invokes the module specified. 
 : That wrapper includes an import of the module and wraps the actual call in a try/catch
 : statement so that we can return enough information we can handle the error cleanly.
 : @param $config - the configuration element
 : @param $source - the event source
 : @param $type - the event type
 : @param $payload - the event payload
 : @param $uris - the event URIs
 : @return the result of the called module. 
 :)
 declare function qx:execute($executor as element(queue:executor), $source as xs:string, $type as xs:string, $payload as item(), $uris as xs:string*) as xs:string? {

    try {
        let $is-xquery := qx:is-xquery($executor)
        let $module :=  if ($is-xquery) then $executor/queue:module/data() else qx:javascript($executor)
        let $variables := qx:variables($is-xquery, $executor, $source, $type, $payload, $uris)
        let $options := map:new() 
            => map:with('isolation', 'different-transaction')
            => map:with('update', 'auto')
            => map:with('commit', 'auto') 

            return if ($is-xquery) 
                then xdmp:invoke($module, $variables, $options)
                else xdmp:javascript-eval($module, $variables, $options)
    } catch ($e) {
        (
            ql:error-uris("Error executing event", $e, $uris, $source, $type),
            ql:audit-events("Error executing event", $uris, (), (), (), $e),
            qc:failed-status()            
        )
    }
 };

(:~
 : Generate the variables to be passed to ML for execution. Generates a map with the correct keys for the 
 : type of execution. 
 : @param $xquery - true if it's xquery, false if javascript
 : @param $executor - the execution module  definition
 : @param $source - the event source
 : @param $type - the event type
 : @param $payload - the event payload
 : @param $uris - the event URIs
 : @return a map to use as variables
 :)
declare private function qx:variables($xquery as xs:boolean, $executor as element(queue:executor), $source as xs:string, $type as xs:string, $payload as item(), $uris as xs:string*) {
    let $fn := function($key as xs:string) { if ($xquery) then xdmp:key-from-QName(xs:QName('queue:' || $key)) else $key }
    return map:new()
        => map:with(xdmp:key-from-QName($fn('source')), $source)
        => map:with(xdmp:key-from-QName($fn('type')), $type)
        => map:with(xdmp:key-from-QName($fn('payload')), $payload)
        => map:with(xdmp:key-from-QName($fn('uris')), $uris)
        => map:with(xdmp:key-from-QName($fn('config')), $executor/queue:config)
};

(:~
 : Determine if a module to be executed is xquery or javascript. We assume javascript if we can't
 : identify it as XQuery.
 : @param $executor - the execution module  definition
 : @return true if xquery, false if javascript
:)
declare private function qx:is-xquery($executor as element(queue:executor)) as xs:boolean {
    if (fn:lower-case($executor/queue:language) = 'xquery')
        then fn:true()
        else if (fn:lower-case($executor/queue:language) = 'javascript')
            then fn:false()
            else if (fn:matches($executor/queue:module, '\.xq(uer)?y$'))
                then fn:true()
                else fn:false()
};

(:~
 : Generate the javascript to be evaluated. 
 : @param $executor - the execution moduel configuration
 : @return a string of javascript
:)
declare private function qx:javascript($executor as element(queue:exector)) as xs:string {
     "'use strict';

        declareUpdate();

        var source;
        var type;
        var payload;
        var uris;
        var config;
         
        const executor = require('"  || $executor/queue:module/data() || "');  executor.main(source, type, payload, uris, config);"
};