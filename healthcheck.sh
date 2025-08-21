#!/usr/bin/env bash

METADATA_HEADER=$(echo -n "{\"accessToken\": \"SRV.${SERVICE_ACCESS_TOKEN}\"}" | base64 -w 0)

IS_HEALTHY=$(curl --silent -H "Content-Type: application/json" -H "X-Message-Metadata: ${METADATA_HEADER}" --request POST --data "{}" http://localhost:"${SERVICE_PORT}"/rpc/sumstats.healthcheck."${SERVICE_NAME}")

if [[ "${IS_HEALTHY}" != "true" ]]; then
  exit 1
fi
