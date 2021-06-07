xquery version "1.0-ml";


(:
 : Simple entity utilities for use in custom steps.
 : Copyright MarkLogic 2020-2021
 : Author: Nic Gibson (nic.gibson@marklogic.com)
:)

declare namespace eu="http://marklogic.com/community/entities/entity-utils.xqy";

import module namespace sem = "http://marklogic.com/semantics" at "/MarkLogic/semantics.xqy";

declare variable $eu:model-collection := "http://marklogic.com/entity-services/models";

declare option xdmp:mapping "false";

(:~
 : Given an entity type name try to get the document for it.
 : @param $entity-type the name of the type (the URI)
 : @return the document found if found. 
 :)
declare function eu:get-entity-from-type($entity-type as xs:string) as document-node()? {
    cts:search(fn:doc(),
        cts:and-query(
            (
                cts:collection-query($eu:model-collection),
                cts:triple-range-query(
                    sem:iri($entity-type),
                    sem:curie-expand("rdf:type"),
                    sem:curie-expand("es:EntityType", 
                        map:new()
                        => map:with('es',  'http://marklogic.com/entity-services#')
                    )
                )
            )
        )
    )[1]
};


(:~
 : Given an entity type, get the name of the entity by parsing the string
 : @param $entity-type  the entity URI
 : @return the entity name itself
 :)
declare function eu:get-entity-name($entity-type as xs:string) as xs:string? {
    fn:tokenize($entity-type, "/")[last()]
};

(:~
 : Given an entity type, get the version from the entity document.
 : @param $entity-type the entity URI
 : @return the version if found
:)
declare function eu:get-entity-version($entity-type as xs:string) as xs:string? {
    eu:get-entity-from-type($entity-type)/info/version
};