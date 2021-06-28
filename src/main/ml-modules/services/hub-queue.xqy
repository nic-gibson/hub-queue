xquery version "1.0-ml";

module namespace resource = "http://marklogic.com/rest-api/resource/hub-queue";

import module namespace qc = "http://noslogan.org/components/hub-queue/queue-config" at "/components/hub-queue/queue-config.xqy";
import module namespace qh = "http://noslogan.org/components/hub-queue/queue-handler" at "/components/hub-queue/queue-handler.xqy";
import module namespace qx = "http://noslogan.org/components/hub-queue/queue-executor" at "/components/hub-queue/queue-executor.xqy";

declare namespace list = "http://noslogan.org/hub-queue/event-list";

declare function get($context as map:map, $params as map:map) as document-node()? {

    let $count-param := map:get($params, 'count')
    let $count := if (fn:exists($count-param))
        then if ($count-param castable as xs:integer) 
            then xs:integer($count-param)
            else fn:error((), "RESTAPISRVEXERR", (500, "Server Error", "'count' parameter is not an integer"))
        else qc:max-uris()

    let $accept := map:get($context, 'accept-types')[. = ('text/xml', 'application/json')]
    let $_ := if (fn:exists($accept)) 
        then () 
        else fn:error((), "RESTAPISRVEXERR", (415, "Unsupported media type", "Output must be JSON or XML"))
    let $output := if ($accept = 'text/xml') then 'text/xml' else 'application/json'

    let $events := qh:get-event-uris($count, qc:new-status(), qc:pending-status())

    return (
        map:put($context, 'output-type', $output),
        document {
            if ($output = 'text/xml') 
                then element list:event-list {  
                    $events ! element list:event-uri { . }
                }
            else json:object() => map:with('eventList', json:to-array($events))
        }
    )
};



declare function put(
    $context as map:map,
    $params  as map:map,
    $input   as document-node()*
) as document-node()?
{
    let $accept := map:get($context, 'accept-types')[. = ('text/xml', 'application/json')]
    let $_ := if (fn:exists($accept)) 
        then () 
        else fn:error((), "RESTAPISRVEXERR", (415, "Unsupported media type", "Output must be JSON or XML"))
    let $output := if ($accept = 'text/xml') then 'text/xml' else 'application/json'

    let $uris := for $doc at $pos in $input 
        let $input-type := map:get($context, 'input-types')[$pos]
        return if ($input-type = 'application/json')
            then $doc/node()/eventList/data()
            else if ($input-type = "text/xml")
                then $doc/list:event-list/list:event-uri/data()
            else fn:error((), "RESTAPISRVEXERR", (415, "Unsupported media type", "Input must be JSON or XML"))

    let $status-list := $uris ! qx:handle-event(.)
    
    return (
        map:put($context, 'output-type', $output),
        document {
            if ($output = 'text/xml') 
                then element list:result-list {  
                    for $uri at $pos in $uris return 
                        element list:result {
                            element list:event-uri { $uri },
                            element list:result { $status-list[$pos] }
                        }
                }
            else json:object() => map:with('resultList', json:to-array(
                for $uri at $pos in $uris return 
                    json:object() => map:with('uri', $uri) => map:with('result', $status-list[$pos])))
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