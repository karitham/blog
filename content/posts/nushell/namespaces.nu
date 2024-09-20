#!/usr/bin/env nu

let ns_names: list<string> = [
    "standalone",
    ("service1-{test,stag,prod}" | str expand),
    ("service2-{test,stag,prod}" | str expand),
    ("team3-{test,stag,prod}" | str expand),
] | flatten | sort

let namespaces = $ns_names | each {{
    apiVersion: "v1",
    kind: "Namespace",
    metadata: { name: $in },
}}

{
    apiVersion: "v1",
    kind: "List",
    items: $namespaces
} | to yaml | save -f $"($env.PROCESS_PATH | path dirname)/namespaces.yaml"