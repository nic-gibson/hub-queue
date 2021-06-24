# Common Simple Queue

This component implements a simple queue persisted into the database. The queue manages events.

An event consists of some metadata, a task specific payload and a list of URIs. The metadata includes a name used to identify a process that can handle the payload.


## Permissions

Queue documents are restricted such that only users with the `queue-writer` role may access them. The name of this role can be redefined using
the `queueWriterRole` gradle property. If not defined permission is assigned to the first defined role of
    * `mlFlowOperatorRole`
    * `rest-writer`

Functions which directly access the queue documents are amped to ensure they can access the documents.

## Queue Executor definition

A _queue executor_ is a Javascript or XQuery module that is run to process a queue event. In Javascript an executor is a module which exports a `main` function which takes five parameters. In XQuery it is a main module. The parameters are passed to `main` (in this order) in Javascript and external variables in XQuery (the variables must be in the namespace `http://noslogan.org/hub-queue/`)

* source - _the source field from the event (a string)_
* type - _the type field from the event (a string)_
* payload - _the payload from the event (an item())_
* uris - _the sequence of URIs assigned to the event (a sequence of strings in XQuery, an array of them in Javascript)_
* config - _the config element from the queue configuration document (if present)_

The queue function is executed in an isolated transaction with update set to true. declareUpdate is set on the javascript module

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

declare namespace q="http://noslogan.org/hub-queue/";

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

Queue configuration is done using an XML documents. These document can be stored anywhere in the modules database as search is used to identify queue configurations. A configuration document contains the following:

* source - _matching source name or names (the source is intended as a way to group types)_
* type - _matching type or types (intended as a way to be more specific - subsetting the source)_
* async - _if set to __true__ then the script is executed via xdmp:spawn-function, if not (the default) it will be executed synchronously_
* module - _the path to the module to be executed_
* language - _set to __javascript__ or __xquery__ (if not set the suffix will be used to work this out)_
* config - _an element with no defined content that is simply passed to the module on execution_

__Note that the `q:executor` element is root of searches so a document may contain many configurations__

### Example

<q:executor xmlns:q="http://noslogan.org/hub-queue/">
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
<q:heartbeat-config xmlns:q="http://noslogan.org/hub-queue/">
   <q:description>Generate an event every minute</q:description>
   <q:hearbeat-id>OneMinute</q:hearbeat-id>
   <q:source>mysource</q:source>
   <q:type>test-type</q:type>
</q:heartbeat-config>
```

```
<q:heartbeat-config xmlns:q="http://noslogan.org/hub-queue/>
    <q:description>Kick of a reset every five minutes</q:description>
    <q:hearbeat-id>FiveMinute</q:hearbeat-id>
    <q:source>http://noslogan.org/hub-queue/status/internal</q:source>
    <q:type>http://noslogan.org/hub-queue/event/reset</q:type>
</q:heartbeat-config>
```




### Internal Heartbeats

The following events are generated for internal use using the hearbeat

#### Reset

Generates an event which, when handled, sets the status of all the events in the URI list to new.

### Clear

Generates an event which, when handled, deletes the event URIs in the event list. 

### Fail

Generates an event which, when handled, sets the status of the event URIs in the event list to failed.

### Pending Timeout

Generates an event which, when handled, identifies events that have not been handled but are marked as pending and adds them to a URI list for the reset event.

### Execution Timeout

Generates an event which, when handled, identifies events that are marked as executing but have run for longer than the configured maximum request timeout and 
adds them to list for the Fail event.

#### Identify Deletions

Generates an event which, when handled, generates a list of event URIs which should be deleted.

### Status

Generates a summary of the state of the queue at the time it was run and stores it as a log entry.

