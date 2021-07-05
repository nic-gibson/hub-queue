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
 : Given an event id, load and process the event, setting the status
 : to the result of the query. process the event if it is found; if not
 : found just issure a warning. If the executor is not found, fail the event
 : and issue an error.
 : @param $id the event id
 : @return the new status set
:)
declare function qx:execute-event($id as xs:string) as xs:string? {

    let $event := qh:get-event($id, qc:executing-status())
    
    let $status := if (fn:exists($event))
        then
            let $executor := qx:find-executor($event)
            return if (fn:exists($executor)) 
                then
                    let $status := (
                        qx:execute($executor, $event),
                        qc:finished-status())[1]
                    return (
                        ql:trace-events("Event executed", $event),
                        ql:audit-events("Event executed", $id, $event, $status, (), ()),
                        $status
                    )
                else (
                    ql:audit-events("Event executor does not exist", $id, $event, qc:failed-status(), (), ()),
                    ql:error-events("Event executor does not exist", (), $event),
                    qc:failed-status()
                )

            else (
                ql:audit-events("Event ID does not exist", $id, (), (), (), ()),
                ql:warn-ids("Event ID does not exist", $id)
            )

    return qh:set-status($id, $status)
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
            cts:element-query(xs:QName("queue:executor"),
                cts:and-query((
                    cts:element-value-query(xs:QName("queue:type"), $event/queue:type),
                    cts:element-value-query(xs:QName("queue:source"), $event/queue:source)
                ))))//queue:executor)[1]
    }, map:new() => map:with('database', xdmp:modules-database()))
};


(:~
 : Execute an event executor definition. 
 : This function invokes the module specified. 
 : That wrapper includes an import of the module and wraps the actual call in a try/catch
 : statement so that we can return enough information we can handle the error cleanly.
 : @param $config - the configuration element
 : @param $event - the event to be executed
 : @return the result of the called module. 
 :)
 declare function qx:execute($executor as element(queue:executor), $event as element(queue:event)) as xs:string? {

    try {
        let $is-xquery := qx:is-xquery($executor)
        let $module :=  if ($is-xquery) then $executor/queue:module/data() else qx:javascript($executor)
        let $variables := qx:variables($is-xquery, $executor, $event)
        let $options := map:new() 
            => map:with('isolation', 'different-transaction')
            => map:with('update', 'auto')
            => map:with('commit', 'auto') 

            return if ($is-xquery) 
                then xdmp:invoke($module, $variables, $options)
                else xdmp:javascript-eval($module, $variables, $options)
    } catch ($e) {
        (
            ql:error-ids("Error executing event", $e, qe:id($event), qe:source($event), qe:type($event)),
            ql:audit-events("Error executing event", $event, (), (), (), $e),
            qc:failed-status()            
        )
    }
 };

(:~
 : Generate the variables to be passed to ML for execution. Generates a map with the correct keys for the 
 : type of execution. 
 : @param $xquery - true if it's xquery, false if javascript
 : @param $executor - the execution module  definition
 : @param $event - the event to be executed
 : @return a map to use as variables
 :)
declare private function qx:variables($xquery as xs:boolean, $executor as element(queue:executor), $event as element(queue:event)) {
    let $fn := function($key as xs:string) { if ($xquery) then xdmp:key-from-QName(xs:QName('queue:' || $key)) else $key }
    return map:new()
        => map:with($fn('source'), qe:source($event))
        => map:with($fn('type'), qe:type($event))
        => map:with($fn('payload'), qe:payload($event))
        => map:with($fn('uris'), qe:uris($event))
        => map:with($fn('config'), $executor/queue:config)
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