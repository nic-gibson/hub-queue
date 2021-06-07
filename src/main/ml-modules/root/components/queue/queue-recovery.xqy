xquery version "1.0-ml";

module namespace qh = "http://marklogic.com/community/queue/queue-config";
declare namespace queue = "http://marklogic.com/community/queue";

(:~ 
 : This module contains the functions used to recover queue status after failures.
:)


(:~
 : Reset expired pending events to new status 
 :)