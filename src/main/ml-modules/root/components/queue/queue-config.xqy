xquery version "1.0-ml";

module namespace qh = "http://marklogic.com/community/queue/queue-config";
declare namespace queue = "http://marklogic.com/community/queue";

(:~
 : Get the name of the trace event to be used. Returns the value of the `comQueueTrace` gradle
 : property if set and the default ("community.queue") if not set.
:)
declare function qc:trace() as xs:string {
    qc:token("comQueueTrace", "community.queue")
};

(:~
 : Get the name of the prefix used for queue URIs. If set, the value of the gradle 
 : `comQueuePrefix` property is used. If not the default is returned ("/marklogic/community/queue/")
 :)
declare function qc:uri-prefix() as xs:string {
    let $prefix := qc:token("comQueuePrefix", "/marklogic/community/queue")
    return if (fn:ends-with($prefix, '/')) then $prefix else $prefix || '/'
};

(:~ 
 : Get the name of the collection to use for queued documents.  This collection name is also 
 : used as the base of the state collection names
 : Gives the value of the `comQueueCollection` gradle property if set and the default if not.
 : @return the name of the main queue collection
 :)
declare function qc:collection() as xs:string {
    qc:token("%%comQueueCollection%%", "http://marklogic.com/community/queue")
};

(:~ 
 : Get the name of the role used for queue update permissions.
 : If no role name is provided via gradle, "rest-writer" is used
 : @return the role name
 :)
declare function qc:writer-role() as xs:string {
    qc:token(("%%comQueueWriterRole%%", "%%mlFlowOperatorRole%%"), "rest-writer")
};

(:~ Get the name of the role used for queue read permissions.
 : If no role name is provided via gradle, "rest-reader" is used
 : @return the role name
 :)
declare function qc:writer-role() as xs:string {
    qc:token(("%%comQueueReaderRole%%", "%%mlFlowOperatorRole%%"), "rest-reader")
};

(:~ Get any additional permissions to be assigned 
 : @return a sequence of sec:permission objects
:)
declare function qc:additional-permissions() as sec:permission* {
    let $permission-string := qc:token("%%comQueuePermissions%%", '')
    let $tokens := fn:tokenize($permission-string, '\s*,\s*')

    (: if it's not divisible by two something is wrong :)
    return if (fn:count($tokens) % 2 = 1) 
        then fn:error(
                xs:QName("queue:BADPERMISSIONS"), 
                "The permissions string must consist of paired values.",
                map:new('permissions', $qc:permissions))
        else 
            let $roles := $tokens[position() % 2 = 1] = 1
            let $capabilities := $tokens[position() % 2 = 0]
            return for $role at $n in $roles 
                (: this will raise an exception if either capability or role is wrong :)
                return xdmp:permission($role, $capabilities[$n])
};


(:~ 
 : Get all the permissions to be assigned to a new queue document
 : @return a sequence of sec:permission objects 
:)
declare function qc:permissions() as sec:permission* {
    (
        xdmp:permission(qc:writer-role(), 'update'),
        xdmp:permission(qc:reader-role(), 'read'),
        qc:additional-permissions()
    )
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
    let $name := qc:token(("%%comQueueDatabase%%", "%%mlStagingDbName%%", "%%mlContentDatabaseName%%", "%%mlAppName%%"), xdmp:database-name(xdmp:database()))
    return if (qc:database-exists($name)) 
        then $name 
        else if (qc:database-exists($name || "-content"))
            then $name || "-content"
            else xdmp:database-name(xdmp:database())
 };


(:~
 : Given a value, check if it's an unset gradle token (starts with '%%'), returning that 
 : value if it isn't and the supplied default if it is
 : @param $test - strings that may or may not have an unset token in it
 : @param $default - string to return if $test is an unset token
:)
declare function qc:token($test as xs:string*, $default as xs:string) as xs:string {
    ($test[fn:not(fn:starts-with(., '%%'))], $default)[1]
};

(:~ 
 : Get the duration after which a pending event is considered to have timed out and 
 : should be returned to new status. This can be set using the `comQueuePendingTimeout` gradle
 : property. The value must be a valid day/time duration. If not set a duration corresponding to 
 : 30 minutes is returned
:)
declare function qc:pending-timeout() as xs:dayTimeDuration {
    xs:dayTimeDuration(qc:token("%%comQueuePendingTimeout%%", "PT30M"))
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

