xquery version "1.0-ml";

module namespace resource = "http://marklogic.com/rest-api/resource/hub-queue-heartbeat";

import module namespace qt = "http://noslogan.org/components/hub-queue/queue-heartbeat" at "/components/hub-queue/queue-heartbeat.xqy";

declare namespace list = "http://noslogan.org/hub-queue/event-list";

declare option xdmp:mapping "false";

declare function get($context as map:map, $params as map:map) as document-node()? {
        fn:error((),"RESTAPI-SRVEXERR",(405, "Method not allowed","GET not implemented"))
};



declare function put(
    $context as map:map,
    $params  as map:map,
    $input   as document-node()*
) as document-node()?
{
    let $id := map:get($params, "heartbeat")

    let $output := map:get($context, "accept-types")[. = ("text/xml", "application/json", "text/plain")][1]
    let $_ := if (fn:exists($output)) 
        then () 
        else fn:error((), "RESTAPISRVEXERR", (415, "Unsupported media type", "Output must be JSON, XML or text"))

    return if (fn:exists($id)) 
        then
            let $uris := qt:heartbeat($id)
            return (
                map:put($context, "output-type", $output),
                document {
                    if ($output = "text/xml") 
                        then element list:result-list {  
                            for $uri at $pos in $uris return 
                                element list:result {
                                    element list:event-uri { $uri }
                                }
                            }
                        else if ($output = "application/json") 
                            then json:object() => map:with("resultList", json:to-array($uris))
                            else fn:string-join($uris, "&#x0D;&#x0A;")
                }
            )

        else fn:error((), "RESTAPISRVEXERR", (500, "Server Error", "Missing 'rs:heartbeat' parameter"))
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