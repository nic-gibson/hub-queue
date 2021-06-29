"use strict";

const log = require("/components/hub-queue/queue-log.xqy");

function main(source, type, paysload, uris, config) {
    log.logUris("PING EVENT", uris, source, type);
    for (const uri of uris) {
        xdmp.documentAddProperties(uri, "PINGED");
    }
}
