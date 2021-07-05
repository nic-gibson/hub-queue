xquery version "1.0-ml";

import module namespace qh = "http://noslogan.org/components/hub-queue/queue-handler" at "/components/hub-queue/queue-handler.xqy";


declare option xdmp:mapping "false";


qh:status-cleanup();

