# Common Simple Queue

This component implements a simple queue persisted into the database. The queue manages events.

An event consists of some metadata, a task specific payload and a list of URIs. The metadata includes a name used to identify a process that can handle the payload.

The executor configuration will contain the following:

1)  the name of the event handled by the processor
2)  the module containing the execution code
3)  the name of the function to execute
4)  a flag indicating if execution should be asynchronous or not
6)  a flag indicating if URIs should be cleared or marked as in error when errors occur (NB - timeout *always* clears URIs)


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