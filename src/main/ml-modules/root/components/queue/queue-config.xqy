xquery version "1.0-ml";

module namespace qc = "http://noslogan.org/components/hub-queue/queue-config";

import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";


declare namespace queue = "http://noslogan.org/hub-queue";

declare option xdmp:mapping "false";

(:~
 : Get the name of the trace event to be used. Returns the value of the `queueTrace` gradle
 : property if set and the default ("hub.queue") if not set.
:)
declare function qc:trace() as xs:string {
    qc:token("%%queueTrace%%", "hub.queue")
};

(:~
 : Get the name of the prefix used for queue URIs. If set, the value of the gradle 
 : `queuePrefix` property is used. If not the default is returned ("/noslogan.org/hub-queue/queue/")
 :)
declare function qc:uri-prefix() as xs:string {
    let $prefix := qc:token("%%queuePrefix%%", "/noslogan.org/hub-queue/queue")
    return if (fn:ends-with($prefix, '/')) then $prefix else $prefix || '/'
};

(:~ 
 : Get the name of the collection to use for queued documents.  This collection name is also 
 : used as the base of the state collection names
 : Gives the value of the `queueCollection` gradle property if set and the default if not.
 : @return the name of the main queue collection
 :)
declare function qc:collection() as xs:string {
    qc:token("%%queueCollection%%", "http://noslogan.org/hub-queue/")
};

(:~ 
 : Get the name of the role used for queue update permissions.
 : If no role name is provided via gradle, "rest-writer" is used
 : @return the role name
 :)
declare function qc:writer-role() as xs:string {
    qc:token("%%queueWriterRole%%", "rest-writer")
};

(:~ Get the name of the role used for queue read permissions.
 : If no role name is provided via gradle, "rest-reader" is used
 : @return the role name
 :)
declare function qc:reader-role() as xs:string {
    qc:token(("%%queueReaderRole%%", "%%mlFlowOperatorRole%%"), "rest-reader", fn:true())
};

(:~ Get any additional permissions to be assigned 
 : @return a sequence of sec:permission objects
:)
declare function qc:additional-permissions() as map:map* {
    let $permission-string := qc:token("%%queuePermissions%%", '')
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


(:~ 
 : Get all the permissions to be assigned to a new queue document
 : @return a sequence of sec:permission objects 
:)
declare function qc:permissions() as map:map* {
    (
        xdmp:permission(qc:writer-role(), 'update', 'object'),
        xdmp:permission(qc:reader-role(), 'read', 'object'),
        qc:additional-permissions()
    )
};

(:~
 : Get the maximum number of URIs to be added to a single queue event
 : at one time. This is only enforced where creating 'internal' events but 
 : external event sources might use it too
:)
declare function qc:max-uris() as xs:integer {
    qc:token("%%queueMaximumURIs%%", 500)
};
 
(:~ 
 : Use the standard gradle database names to try and work out the name of the database to write the queue to.
 : First, try the queue specific property. Then, if the DHF staging DB is set, use that. If not, 
 : try the content database. If all else fails use the current database. 
 : NOTE - this is slightly convoluted because mlAppName is very likely to exist but is very likely not to be
 : a useful database name.
 : @return the name of the database to write the queue to.
 :)
 declare function qc:database() as xs:string {
    let $name := qc:token(("%%queueDatabase%%", "%%mlStagingDbName%%", "%%mlContentDatabaseName%%", "%%mlAppName%%"), xdmp:database-name(xdmp:database()))
    return if (qc:database-exists($name)) 
        then $name 
        else if (qc:database-exists($name || "-content"))
            then $name || "-content"
            else xdmp:database-name(xdmp:database())
 };

(:~ 
 : Get the duration after which a pending event is considered to have timed out and 
 : should be returned to new status. This can be set using the `queuePendingTimeout` gradle
 : property. The value must be a valid day/time duration. If not set a duration corresponding to 
 : 30 minutes is returned
:)
declare function qc:pending-timeout() as xs:dayTimeDuration {
    xs:dayTimeDuration(qc:token("%%queuePendingTimeout%%", "PT30M"))
};

(:~ 
 : Get the duration after which a new event is considered to have timed out and 
 : should be set to failed status. This can be set using the `queueNewTimeout` gradle
 : property. The value must be a valid day/time duration. If not set a duration corresponding to 
 : 60 minutes is returned
:)
declare function qc:new-timeout() as xs:dayTimeDuration {
    xs:dayTimeDuration(qc:token("%%queueNewTimeout%%", "PT60M"))
};

(:~ 
 : Query the app server configuration for the maximum requestion execution time for this
 : app server. This is used to determine if an event marked as executing has been timed out.
:)
declare function qc:execution-timeout() as xs:dayTimeDuration {

    xs:dayTimeDuration('PT' || xs:string(admin:appserver-get-max-time-limit(admin:get-configuration(), xdmp:server())) || "S")


};

(:~
 : Return true if detailed logging is enabled 
:)
declare function qc:detailed-log() as xs:boolean {
    fn:lower-case(qc:token("%%queueDetailedLog%%", 'false')) = 'true'
};

(:~
 : Return the database that queue logs should be written to. If the DHF jobs
 : database is defined, return that. Otherwise, return the same database the queue
 : is written to.
 :)
 declare function qc:log-database() as xs:string {
    let $name := qc:token(("%%mlJobDbName%%", "%%queueDatabase%%", "%%mlStagingDbName%%", "%%mlContentDatabaseName%%", "%%mlAppName%%"), xdmp:database-name(xdmp:database()))
    return if (qc:database-exists($name)) 
        then $name 
        else if (qc:database-exists($name || "-content"))
            then $name || "-content"
            else xdmp:database-name(xdmp:database())
 };

(:~ 
 : Return log URI prefix to use.
 : If not defined in queueLogPrefix then the normal prefix with 'log' appended
 : is used
 :)
 declare function qc:log-prefix() as xs:string {
     qc:token('%%queueLogPrefix%%', qc:uri-prefix() || 'log/' )
 };

(:~ 
 : Return log collection  to use.
 : If not defined in queueLogCollection then the base queue collection with 'log' appended
 : is used
 :)
 declare function qc:log-collection() as xs:string {
     qc:token('%%queueLogCollection%%', qc:collection() || '/log/' )
 };

(:~ 
 : REturn the name of the metadata item used to store status
:)
declare function qc:status-metadata-name() as xs:string {
    qc:token("%%queueStatusMetadata", 'queue-status')
};

(:~
 : Return the name of the metadata item used to store the timestamp
:)
declare function qc:timestamp-metadata-name() as xs:string {
    qc:token("%%queueTimestampMetadata", 'queue-timestamp')
};


(:~
 : Return the collection URI for a new event. This is normally only set
 : when an event is inserted into the queue. Recovery may lead to a pending
 : entry being returned to new status
 :)
declare function qc:status-new() {
    qc:collection-prefix() || 'new'
};

(:~
 : Return the collection URI for pending event. 
 :)
 declare function qc:status-pending() {
     qc:collection-prefix() || 'pending'
 };

 
(:~
 : Return the collection URI for execution event. 
 :)
 declare function qc:status-executing() {
     qc:collection-prefix() || 'executing'
 };


(:~
 : Return the collection URI for failed event. 
 :)
 declare function qc:status-failed() {
     qc:collection-prefix() || 'failed'
 };

(:~
 : Return the collection URI for finished events. 
 :)
 declare function qc:status-finished() {
     qc:collection-prefix() || 'finished'
};

(:~ 
 : Return the source type for internal events
:)
declare function qc:internal-source() {
    qc:collection-prefix() || "/source/internal"
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
 : Get the prefix for status collections. Defined as the queue colleciton
 : with trailing / if not already present
 :)
 declare private function qc:collection-prefix() as xs:string {
     let $collection := qc:collection()
     return if (fn:ends-with($collection, '/')) then $collection else $collection || '/'
 };

(:~ 
 : Check if a database exists 
 :)
declare private function qc:database-exists($dbname as xs:string) as xs:boolean {
    try {
        fn:exists(xdmp:database($dbname))
    } catch ($exception) {
        fn:false()
    }
};


(:~
 : Given a value, check if it's an unset gradle token (starts with '%%'), returning that 
 : value if it isn't and the supplied default if it is
 : @param $test - strings that may or may not have an unset token in it
 : @param $default - string to return if $test is an unset token
 : @param $allow-empty - set to true if empty tokens are valid
 : @return the first set token or the default
:)
declare private function qc:token($test as xs:string*, $default as xs:string, $allow-empty as xs:boolean) as xs:string {
    ($test[fn:not(fn:starts-with(., '%%'))][$allow-empty or fn:not(. = '')], $default)[1]
};

(:~
 : Given a value, check if it's an unset gradle token (starts with '%%'), returning that 
 : value if it isn't and the supplied default if it is. Empty tokens are also
 : ignored.
 : @param $test - strings that may or may not have an unset token in it
 : @param $default - string to return if $test is an unset token : @return the first set token or the default
:)
declare private function qc:token($test as xs:string*, $default as xs:string) as xs:string {
    qc:token($test, $default, fn:false())
};
