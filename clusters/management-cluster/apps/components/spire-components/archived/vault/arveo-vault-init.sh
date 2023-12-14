#!/bin/sh

if [ "$VAULT_DEV_ROOT_TOKEN_ID" = "root" ]
then
  DEV_MODE=true
else
  DEV_MODE=false
fi

# for debugging - this path is accessable via k8s host
#LOGPATH=/home/vault/.cache/snowflake
LOGPATH=/tmp

# enable & configure transit engine
#vault secrets enable transit
#vault write -f transit/keys/vault-autounseal-test
#
#vault policy write autounseal -<<EOF
#path "transit/encrypt/vault-autounseal-test" {
#    capabilities = ["update"]
#}
#
#path "transit/decrypt/vault-autounseal-test" {
#    capabilities = ["update"]
#}
#EOF

common_init_conf () {
  vault auth enable jwt
  vault write auth/jwt/config oidc_discovery_url=https://oidc-discovery.projekte.eitco.de default_role="dev" oidc_discovery_ca_pem=@/tmp/ca.crt

  vault kv put secret/my-super-secret \
    test=12345

  vault policy write my-dev-policy -<<EOF
  path "secret/data/my-super-secret" {capabilities = ["read"] }

  path "transit/encrypt/vault-autounseal-test" {
    capabilities = ["update"]
  }

  path "transit/decrypt/vault-autounseal-test" {
      capabilities = ["update"]
  }
EOF
  
  vault write auth/jwt/role/dev \
    role_type=jwt \
    user_claim=sub \
    bound_audiences=TESTING \
    bound_subject=spiffe://example.org/ns/default/sa/default \
    token_ttl=24h \
    token_policies="my-dev-policy"
}

if [ "$(hostname)" = "vault-0" ]
then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Pod is vault-0, proceeding with setup..." >> $LOGPATH/arveo-vault-init.stdout.log

  if $DEV_MODE
  then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Waiting for vault to become ready..." >> $LOGPATH/arveo-vault-init.stdout.log
    until vault status ; do
      printf "." >> $LOGPATH/arveo-vault-init.stdout.log
      sleep 1;
    done;
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Vault OK ✓" >> $LOGPATH/arveo-vault-init.stdout.log
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Setting initial secrets..." >> $LOGPATH/arveo-vault-init.stdout.log
    common_init_conf
  else
    until nc -z 127.0.0.1 8200
    do
      printf "." >> $LOGPATH/arveo-vault-init.stdout.log
      sleep 1
    done

    echo "$(date '+%Y-%m-%d %H:%M:%S') - Checking if vault needs to be initialized..." >> $LOGPATH/arveo-vault-init.stdout.log
    INITIALIZED=$(vault status | grep Initialized | awk '{ print $2 }')

    if [ "$INITIALIZED" == "false" ]
    then
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Initializing vault..." >> $LOGPATH/arveo-vault-init.stdout.log
      vault operator init 2>&1 | tee /tmp/vault.init > /dev/null
	    echo "$(date '+%Y-%m-%d %H:%M:%S') - Vault initialized ✓" >> $LOGPATH/arveo-vault-init.stdout.log

      export VAULT_TOKEN=$(cat /tmp/vault.init | grep '^Initial' | awk '{print $4}')
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Setting initial secrets..." >> $LOGPATH/arveo-vault-init.stdout.log
      vault secrets enable -version=2 -path=secret/ kv
      common_init_conf
      unset VAULT_TOKEN
      echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: Make sure you copied the content from /tmp/vault.init & deleted the file afterwards!" >> $LOGPATH/arveo-vault-init.stdout.log
    else
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Vault is already initialized. Nothing to do!" >> $LOGPATH/arveo-vault-init.stdout.log
	fi
  fi

  vault status >> $LOGPATH/arveo-vault-init.stdout.log 2>&1
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Exit status $?" >> $LOGPATH/arveo-vault-init.stdout.log
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Vault Initialization completed ✓" >> $LOGPATH/arveo-vault-init.stdout.log
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Pod is not vault-0, skipping setup!" >> $LOGPATH/arveo-vault-init.stdout.log
fi