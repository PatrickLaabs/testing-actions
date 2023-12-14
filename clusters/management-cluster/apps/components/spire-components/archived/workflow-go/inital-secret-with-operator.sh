#!/bin/bash

HISTCONTROL=ignorespace

cleanup() {
    [[ -f secret-data.env ]] && shred -u secret-data.env
    [[ -f payload.json ]] && shred -u payload.json
    unset TOKEN RESPONSE CLIENT_TOKEN SECRET_RESPONSE
}

trap cleanup EXIT

(
    fetch_token() {
        /opt/spire/bin/spire-agent api fetch jwt -audience $1 -socketPath $2 \
        | awk '/token\(spiffe:\/\//{getline; gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print}'
    }

    create_k8s_secret() {
        kubectl create secret generic $2 --from-env-file=$1 
    }

    TOKEN=$( fetch_token "TESTING" "/run/spire/sockets/agent.sock" )
    [ -z "$TOKEN" ] && { echo "Failed to fetch token"; exit 1; }

    echo "{\"role\": \"dev\",\"jwt\": \"$TOKEN\"}" > payload.json

    RESPONSE=$( curl -s --request POST --data @payload.json http://vault.vault.svc.cluster.local:8200/v1/auth/jwt/login )
    echo "token=$(echo "$RESPONSE" | jq -r '.auth.client_token')" > secret-data.env

    create_k8s_secret "secret-data.env" "vault-test"
)