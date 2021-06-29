xquery version "1.0-ml";

module namespace qc = "http://noslogan.org/components/hub-queue/queue-config";

declare namespace queue = "http://noslogan.org/hub-queue";

declare private variable $config as map:map := qc:load-config();

declare option xdmp:mapping "false";

(:~
 : Get the name of the trace event to be used. Returns the value of the `queueTrace` gradle
 : property if set and the default ("hub.queue") if not set.
:)
declare function qc:trace() as xs:string {
    map:get($config, 'trace')
};

(:~
 : Get the name of the prefix used for queue URIs. If set, the value of the gradle 
 : `queuePrefix` property is used. If not the default is returned ("/noslogan.org/hub-queue/queue/")
 :)
declare function qc:uri-prefix() as xs:string {
    if (fn:ends-with(map:get($config, 'uri-prefix'), '/')) then map:get($config, 'uri-prefix') else map:get($config, 'uri-prefix') || '/'
};

(:~ 
 : Get the base name of the collection to use for queued documents.  This collection name is also 
 : used as the base of the state collection names
 : Gives the value of the `hubQueueCollectionBase` gradle property if set and the default if not.
 : @return the name of the main queue collection
 :)
declare function qc:collection() as xs:string {
    map:get($config, 'collection-base')
};

(:~ Get any additional permissions to be assigned 
 : @return a sequence of sec:permission objects
:)
declare function qc:additional-permissions() as map:map* {
    qc:parse-permissions(map:get($config, 'additional-permissions'))
};

(:~ 
 : Get all the permissions to be assigned to a new queue document : @return a sequence of permission objects 
:)
declare function qc:permissions() as map:map* {
    (
        qc:parse-permissions(map:get($config, 'queue-permissions')),
        qc:additional-permissions()
    )
};

(:~ 
 : Get all the permissions to be assigned to a new log document
 : @return a sequence of permission objects 
:)
declare function qc:log-permissions() as map:map* {
    (
        qc:parse-permissions(map:get($config, 'log-permissions')),
        qc:additional-permissions()
    )
};

(:~
 : Get the maximum number of URIs to be added to a single queue event
 : at one time. This is only enforced where creating 'internal' events but 
 : external event sources might use it too
:)
declare function qc:max-uris() as xs:integer {
    xs:integer(map:get($config, 'max-uris'))
};
 
(:~
 : Get the maximum number of event URIs to be returned when events are requested
 : over the REST interface
:)
declare function qc:max-events() as xs:integer {
    xs:integer(map:get($config, 'max-events'))
};

(:~ 
 : Get the queue database. Unless overridden this is the hub staging database
 :)
 declare function qc:database() as xs:string {
     map:get($config, 'database')
 };

(:~ 
 : Get the duration after which a pending event is considered to have timed out and 
 : should be returned to new status. This can be set using the `hubQueuePendingTimeout` gradle
 : property. The value must be a valid day/time duration. If not set a duration corresponding to 
 : 30 minutes is returned
:)
declare function qc:pending-timeout() as xs:dayTimeDuration {
    xs:dayTimeDuration(map:get($config, 'pending-timeout'))
};

(:~ 
 : Get the duration after which a new event is considered to have timed out and 
 : should be set to failed status. This can be set using the `hubQueueNewTimeout` gradle
 : property. The value must be a valid day/time duration. If not set a duration corresponding to 
 : 60 minutes is returned
:)
declare function qc:new-timeout() as xs:dayTimeDuration {
    xs:dayTimeDuration(map:get($config, 'new-timeout'))
};

(:~ 
 : Get the duration after which an executing event is considered to have timed out and 
 : should be set to failed status. This can be set using the `hubQueueExecutionTimeout` gradle
 : property. The value must be a valid day/time duration. If not set a duration corresponding to 
 : 60 minutes is returned
:)
declare function qc:execution-timeout() as xs:dayTimeDuration {
    xs:dayTimeDuration(map:get($config, 'execution-timeout'))
};

(:~
 : Return true if detailed logging is enabled 
:)
declare function qc:detailed-log() as xs:boolean {
   if (map:get($config, 'detailed-log') castable as xs:boolean) 
    then xs:boolean(map:get($config, 'detailed-log'))
    else fn:false()
};

(:~
 : Return the database that queue logs should be written to. Uses the
 : DHF log db unless overriddent
:)
 declare function qc:log-database() as xs:string {
     map:get($config, 'log-database')
 };
(:~ 
 : Return log URI prefix to use.
 : If not defined in queueLogPrefix then the normal prefix with 'log' appended
 : is used
 :)
 declare function qc:log-prefix() as xs:string {
     if (fn:ends-with(map:get($config, 'log-prefix'), '/')) then map:get($config, 'log-prefix') else map:get($config, 'log-prefix') || '/'
 };

(:~ 
 : Return log collection  to use.
 : If not defined in queueLogCollection then the base queue collection with 'log' appended
 : is used
 :)
 declare function qc:log-collection() as xs:string {
     map:get($config, 'log-collection')
 };

(:~ 
 : REturn the name of the metadata item used to store status
:)
declare function qc:status-metadata-name() as xs:string {
    map:get($config, 'status-meta')
};

(:~
 : Return the name of the metadata item used to store the timestamp
:)
declare function qc:timestamp-metadata-name() as xs:string {
    map:get($config, 'timestamp-meta')
};


(:~
 : Return the collection URI for a new event. This is normally only set
 : when an event is inserted into the queue. Recovery may lead to a pending
 : entry being returned to new status
 :)
declare function qc:new-status() {
    qc:collection-prefix() || '/status/new'
};

(:~
 : Return the collection URI for pending event. 
 :)
 declare function qc:pending-status() {
     qc:collection-prefix() || '/status/pending'
 };

 
(:~
 : Return the collection URI for execution event. 
 :)
 declare function qc:executing-status() {
     qc:collection-prefix() || '/status/executing'
 };


(:~
 : Return the collection URI for failed event. 
 :)
 declare function qc:failed-status() {
     qc:collection-prefix() || '/status/failed'
 };

(:~
 : Return the collection URI for finished events. 
 :)
 declare function qc:finished-status() {
     qc:collection-prefix() || '/status/finished'
};

(:~ 
 : Return the source type for internal events
:)
declare function qc:internal-source() {
    qc:collection-prefix() || "/source/internal"
};

(:~ 
 : Return the source type for heartbeat events
:)
declare function qc:heartbeat-source() {
    qc:collection-prefix() || "/source/heartbeat"
};


(:~
 : Return the event type for the queue reset internal event type
 :)
declare function qc:event-reset() {
    qc:collection-prefix() || '/event/reset'
};

(:~
 : Return the event type for the queue clear internal event type
 :)
declare function qc:event-clear() {
    qc:collection-prefix() || '/event/clear'
};

(:~
 : Return the event type for the queue clear internal event type
 :)
declare function qc:event-update-status() {
    qc:collection-prefix() || '/event/update-status'
};

(:~
 : Get the prefix for status/source/event collections. Defined as the queue colleciton
 : with trailing / if not already present
 :)
 declare private function qc:collection-prefix() as xs:string {
     let $collection := qc:collection()
     return if (fn:ends-with($collection, '/')) then $collection else $collection || '/'
 };


(:~
 : Load the configuration file, setting the configuration map by taking the elements from the
 : default configuration and then picking the first defined value from custom config or the default
 : and storing it in map keyed on the local name of each element
 : @return a map of the configuration for the queue
:)
declare private function qc:load-config() as map:map {
    let $xml-config := xdmp:invoke-function(
        function() { cts:search(fn:doc(), cts:element-query(xs:QName("qc:queue-config"), cts:true-query()))[1]/qc:queue-config },
        map:new() => map:with('database', xdmp:modules-database()))

    (: Use the defaults to drive the process because some defaults are not overwritten by custom configuration :)
    return map:new(
        for $item in $xml-config/qc:default-config/*
            let $potential-default := $xml-config/qc:custom-config/*[name=fn:name($item)]/data()
            return map:entry(fn:local-name($item), (
                if (fn:starts-with($potential-default, "%%")) then () else $potential-default,
                $item/data())[1]))
};


(:~ 
 : Convert a sequence of role/capability pairs into permissions 
 : @param $permissions-string the strings to be parsed
 : @return a sequence of permission maps
 :)
 declare function qc:parse-permissions($permission-string as xs:string?) as map:map* {
    let $tokens := if ($permission-string = '') then () else fn:tokenize($permission-string, '\s*,\s*')

    (: if it's not divisible by two something is wrong :)
    return if (fn:count($tokens) mod 2 = 1) 
        then fn:error(
                xs:QName("queue:BADPERMISSIONS"), 
                "The permissions string must consist of paired values.",
                map:entry('permissions', $permission-string))
        else 
            let $roles := $tokens[position() mod 2 = 1]
            let $capabilities := $tokens[position() mod 2 = 0]
            return for $role at $n in $roles 
                (: this will raise an exception if either capability or role is wrong :)
                return xdmp:permission($role, $capabilities[$n], 'object')
};