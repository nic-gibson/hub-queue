# Common Simple Queue

This component implements a simple queue persisted into the database. The queue manages events.

An event consists of some metadata, a task specific payload and a list of URIs. The metadata includes a name used to identify a process that can handle the payload.

Both synchronous and asynchronous execution follow the same path
    1) Mark the event as in progress
    2) Create an anonymous function to wrap the function that does the following
       1) In a separate transaction mark the event as in progress including a timestamp
       2) Find the function to execute and get a reference to it
       3) Execute the function wrapped in a try/catch
       4) Mark as failed if an error occurs, write an audit




## Permissions

Queue documents are assigned permissions. The update permission is assigned to the first defined role of
    * `comQueueWriterRole`
    * `mlFlowOperatorRole`
    * `rest-writer`

The read permission is assigned to the first defined role of
    * `comQueueReaderRole`
    * `mlFlowOperatorRole`
    * `rest-reader`

Additional permissions can be assigned using the `comQueuePermissions` gradle property. This must consist of comma separated role name, capability pairs (e.g. "rest-writer,update,rest-reader,read")


## Queue Executor definition

A _queue executor_ is a Javascript or XQuery module that is run to process a queue event. In Javascript an executor is a module which exports a `main` function which takes five parameters. In XQuery it is a main module. The parameters are passed to `main` (in this order) in Javascript and external variables in XQuery (the variables must be in the namespace `http://marklogic.com/community/queue`)

* source - _the source field from the event (a string)_
* type - _the type field from the event (a string)_
* payload - _the payload from the event (an item())_
* uris - _the sequence of URIs assigned to the event (a sequence of strings in XQuery, an array of them in Javascript)_
* config - _the config element from the queue configuration document (if present)_
  

### Javascript example

```
"use strict";

function main(source, type, payload, uris, config) {

    xdmp.log(`In event of type ${type} created by ${source}
        payload is ${xdmp:quote(payload)}
        and uris are ${uris}
    `)
}

module.exports = { main }
```

### XQuery example

```
xquery version "1.0-ml";

declare namespace q="http://marklogic.com/community/queue";

declare variable $q:source as xs:string external;
declare variable $q:type as xs:string external;
declare variable $q:payload as item() external;
declare variable $q:config as element(q:config)? external;
declare variable $q:uris as xs:string* external;

xdmp:log("In event of type " || $type ||  " created by " || $source
        || "&#x0A;payload is " || xdmp:quote(payload) 
        || " and uris are || fn:string-join($uris, ', ') )
```


The result of the call is used as the new status for the queue entry. If nothing is returned, the status is set to `finished`. If an error occurs the status is set to `failed`.  Status is logged only when an error occurs under normal status. Enabling the queue trace (the name defaults to `community.queue`) will lead to all events being logged.

## Configuration

Queue configuration is done using an XML documents. These document can be stored anywhere in the same database as the queue itself as search is used to identify queue configurations. A configuration document contains the following:

* source - _matching source name or names (the source is intended as a way to group types)_
* type - _matching type or types (intended as a way to be more specific - subsetting the source)_
* async - _if set to __true__ then the script is executed via xdmp:spawn-function, if not (the default) it will be executed synchronously_
* module - _the path to the module to be executed_
* language - _set to __javascript__ or __xquery__ (if not set the suffix will be used to work this out)_
* config - _an element with no defined content that is simply passed to the module on execution_

__Note that the `q:executor` element is root of searches so a document may contain many configurations__

### Example

<q:executor xmlns:q="http://marklogic.com/community/queue">
    <q:source>mysource</q:source>
    <q:type>test-type</q:source>
    <q:module>/queue-modules/test-type-exec.xqy</q:module>
    <q:language>xquery</q:language>
    <q:config>
        <one>1</one>
        <fred>ginger</fred>
    </q:config>
</q:executor>

__Note that both `q:source` and `q:type` may be repeated__

### Duplication

__It is unwise to set more than `q:config` to match the same `source` and `type` as the first one that results from the query will be used and others silently ignored.__ 


## Queue Heartbeat

Queue management is handled by a regular  task. The test configuration includes a simple set of scheduled tasks to generate this hearbeat. In a production environment, this should be handle by an external task calling the REST interface (see REST interface). Note - the REST interface does not configure a REST Server - that is the responsibility of the application user it.

The hearbeat task reads a configuration file and uses it to create events. These are stub events which don't have associated URIs - they are used to trigger event processing. They can have a payload if required

The hearbeat request takes a single parameter - `id`. The hearbeat id is used to identify events to be created. This is driven by a configuration file similar to that defined for the executors above. It contains the following fields:

* heartbeat-id - _if the id matches the current hearbeat id, the event is created_
* source - _the source parameter for the newly created event (set to `heartbeat` if not defined)
* type - _the type parameter for new created event - must be set_
* payload - _the payload to pass to the executor via the event. See below_

### Payloads

The `q:payload` element can contain anything that can be expressed in XML. JSON converted to XML may be used as may the XML serialization of a map. Both of these will be converted back to the 

### Examples

```
<q:hearbeat-config xmlns:q="http://marklogic.com/community/queue">
   <q:description>Generate an event every minute</q:description>
   <q:hearbeat-id>OneMinute</q:hearbeat-id>
   <q:source>mysource</q:source>
   <q:type>test-type</q:source>
</q:hearbeat-config>
```

```
<q:hearbeat-config xmlns:q="http://marklogic.com/community/queue>
    <q:description>Kick of a reset every five minutes</q:description>
    <q:hearbeat-id>FiveMinute</q:hearbeat-id>
    <q:source>http://marklogic.com/community/queue/status/internal</q:source>
    <q:type>http://marklogic.com/community/queue/event/reset</q:type>
</q:hearbeat-config>
```
