#!/usr/bin/env bash

# Define the namespace names
ns_names=(
    "standalone"
    $(eval echo "service1-{test,stag,prod}")
    $(eval echo "service2-{test,stag,prod}")
    $(eval echo "team3-{test,stag,prod}")
)

# Sort the namespace names
IFS=$'\n' sorted_ns=($(sort <<<"${ns_names[*]}"))
unset IFS

# Generate the YAML output
{
    echo "apiVersion: v1"
    echo "kind: List"
    echo "items:"
    for ns in "${sorted_ns[@]}"; do
        echo "- apiVersion: v1"
        echo "  kind: Namespace"
        echo "  metadata:"
        echo "    name: $ns"
    done
} >"$(dirname "$0")/namespaces.yaml"
