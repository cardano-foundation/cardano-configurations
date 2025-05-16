#!/bin/bash

# Download configuration files from a nominated URL for a nominated network

CARDANO_CONFIG_URL=$1
CARDANO_NETWORK=$2

CARDANO_CONFIG_OVERRIDE='.ByronGenesisFile = "../genesis/byron.json" | .ShelleyGenesisFile = "../genesis/shelley.json" | .AlonzoGenesisFile = "../genesis/alonzo.json" | .ConwayGenesisFile = "../genesis/conway.json"'
DB_SYNC_CONFIG_OVERRIDE='.NodeConfigFile = "../cardano-node/config.json"'

function get_if_new() {
  FILE=$1
  OUT=$2

  ETAG_FILE=etags/$CARDANO_NETWORK/${FILE%.*}.etag
  TMP=$(mktemp)
  ETAG=$([[ -f $ETAG_FILE ]] && cat $ETAG_FILE)

  curl -s -i -H "If-None-Match: $ETAG" $CARDANO_CONFIG_URL/$CARDANO_NETWORK/$FILE -o $TMP
  ETAG=$(cat $TMP | grep etag | sed "s/.*etag[^:]*: \(.*\)$/\1/")
  CODE=$(cat $TMP | grep "^HTTP" | sed "s/.*HTTP\/2 \([0-9]\{3\}\).*/\1/")

  if [[ $CODE == "304" ]]; then
    echo "ETAG matched for $FILE; nothing to do."

  elif [[ $CODE == "200" ]]; then
    echo "ETAG did not match; processing $FILE."
    mkdir -p $(dirname $ETAG_FILE) && echo $ETAG > $ETAG_FILE
    mkdir -p $(dirname $OUT)
    if [[ $FILE == "config.json" ]]; then
      cat $TMP | sed -E '1,/^\r?$/d' | jq "$CARDANO_CONFIG_OVERRIDE" > $OUT
    elif [[ $FILE == "db-sync-config.json" ]]; then
      cat $TMP | sed -E '1,/^\r?$/d' | jq "$DB_SYNC_CONFIG_OVERRIDE" > $OUT
    else
      cat $TMP | sed -E '1,/^\r?$/d' > $OUT
    fi

  elif [[ $CODE == "404" ]]; then
    echo "NOT FOUND: $FILE; ignoring"

  else
    echo "Failed to fetch $FILE."
    cat $TMP
    exit 1
  fi
}

get_if_new "topology.json" network/$CARDANO_NETWORK/cardano-node/topology.json
get_if_new "checkpoints.json" network/$CARDANO_NETWORK/cardano-node/checkpoints.json
get_if_new "config.json" network/$CARDANO_NETWORK/cardano-node/config.json
get_if_new "db-sync-config.json" network/$CARDANO_NETWORK/cardano-db-sync/config.json
get_if_new "submit-api-config.json" network/$CARDANO_NETWORK/cardano-submit-api/config.json

get_if_new "byron-genesis.json" network/$CARDANO_NETWORK/genesis/byron.json
get_if_new "shelley-genesis.json" network/$CARDANO_NETWORK/genesis/shelley.json
get_if_new "alonzo-genesis.json" network/$CARDANO_NETWORK/genesis/alonzo.json
get_if_new "conway-genesis.json" network/$CARDANO_NETWORK/genesis/conway.json
