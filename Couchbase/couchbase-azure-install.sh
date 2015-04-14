log()
{
    curl -X POST -H "content-type:text/plain" --data-binary "${HOSTNAME} - $1" https://logs-01.loggly.com/inputs/1ade465e-527c-40ab-a8b0-7c6f477af19a/tag/cb-extension,${HOSTNAME}
}

log "Begin execution of couchbase script extension on ${HOSTNAME}"
