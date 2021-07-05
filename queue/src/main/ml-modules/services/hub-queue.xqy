xquery version "1.0-ml";

module namespace resource = "http://marklogic.com/rest-api/resource/hub-queue";

import module namespace qc = "http://noslogan.org/components/hub-queue/queue-config" at "/components/hub-queue/queue-config.xqy";
import module namespace qh = "http://noslogan.org/components/hub-queue/queue-handler" at "/components/hub-queue/queue-handler.xqy";
import module namespace qx = "http://noslogan.org/components/hub-queue/queue-executor" at "/components/hub-queue/queue-executor.xqy";

declare namespace list = "http://noslogan.org/hub-queue/event-list";

declare option xdmp:mapping "false";


declare function get($context as map:map, $params as map:map) as document-node()? {

    let $count-param := map:get($params, "count")
    let $count := if (fn:exists($count-param))
        then if ($count-param castable as xs:integer) 
            then xs:integer($count-param)
            else fn:error((), "RESTAPISRVEXERR", (500, "Server Error", "'count' parameter is not an integer"))
        else qc:max-uris()

    let $output := map:get($context, "accept-types")[. = ("text/xml", "application/json", "text/plain")][1]
    let $_ := if (fn:exists($output)) 
        then () 
        else fn:error((), "RESTAPISRVEXERR", (415, "Unsupported media type", "Output must be JSON, XML or text"))

    let $events := qh:get-event-ids($count, qc:new-status(), qc:pending-status())

    return (
        map:put($context, "output-type", $output),
        document {
            if ($output = "text/xml") 
                then element list:event-list {  
                    $events ! element list:event-id { . }
                }
            else if ($output = "application/json") 
                then json:object() => map:with("eventList", json:to-array($events))
                else fn:string-join($events, "&#x0D;&#x0A;")
        }
    )
};



declare function put(
    $context as map:map,
    $params  as map:map,
    $input   as document-node()*
) as document-node()?
{
    let $output := map:get($context, "accept-types")[. = ("text/xml", "application/json", "text/plain")][1]
    let $_ := if (fn:exists($output)) 
        then () 
        else fn:error((), "RESTAPISRVEXERR", (415, "Unsupported media type", "Output must be JSON, XML or text"))

    let $ids := for $doc at $pos in $input 
        let $input-type := map:get($context, "input-types")[$pos]
        return if ($input-type = "application/json")
            then $doc/node()/*
            else if ($input-type = "text/xml")
                then $doc/list:event-list/list:event/list:event-id/data()
            else fn:error((), "RESTAPISRVEXERR", (415, "Unsupported media type", "Input must be JSON or XML"))

    let $status-list := $ids ! qx:execute-event(.)
    
    return (
        map:put($context, "output-type", $output),
        document {
            if ($output = "text/xml") 
                then element list:event-list {  
                    for $id at $pos in $ids return 
                        element list:event {
                            element list:event-id { $id },
                            element list:event-status { $status-list[$pos] }
                        }
                }
            else if ($output = "application/json") 
                then json:object() => map:with("resultList", json:to-array(
                    for $id at $pos in $ids return 
                        json:object() => map:with("id", $id) => map:with("status", $status-list[$pos])))
                else fn:string-join(
                    (for $id at $pos in $ids return $id || "," || $status-list[$pos]),
                     "&#x0D;&#x0A;")
        }
    )
};





declare function delete(
    $context as map:map,
    $params  as map:map
) as document-node()?
{
    fn:error((),"RESTAPI-SRVEXERR",(405, "Method not allowed","DELETE not implemented"))
};



declare function post(
    $context as map:map,
    $params  as map:map,
    $input   as document-node()*
) as document-node()*
{
    fn:error((),"RESTAPI-SRVEXERR",(405, "Method not allowed", "POST not implemented"))

};