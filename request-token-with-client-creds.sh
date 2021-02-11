#!/bin/bash
#
# Obtains an Access Token via Client Credentials flow.

# Import common functions.
. ./common.sh --source-only

# Suppress Perl warnings that might occur when invoking jq.
init

# Outputs expected usage.
print_usage() {
  echo
  echo "Usage: ./request-token-with-client-creds.sh -option1 arg1 -option2 arg2 ..."
  echo
  echo "Required options:"
  echo
  echo "-c Client ID"
  echo "-d Discovery Document URI (a.k.a. Well-known URI)"
  echo "-p PEM file containing an RSA public-private key-pair"
  echo "-k Signing Key ID"
  echo
  echo "Optional options:"
  echo
  echo "-s Scopes (a space-delimited list surrounded by quotes)"
  echo
  exit 1
}

# Parse the command-line options.
while getopts 'c:d:p:k:s:' flag; do
  case "${flag}" in
    c) client_id="${OPTARG}" ;;
    d) discovery_doc_uri="${OPTARG}" ;;
    p) pem="${OPTARG}" ;;
    k) kid="${OPTARG}" ;;
    s) scopes="${OPTARG}" ;;
    *) print_usage ;;
  esac
done

# Test for required arguments.
if [ -z "${client_id}" ] || [ -z "${discovery_doc_uri}" ] || [ -z "${pem}" ] || [ -z "${kid}" ]; then
  print_usage
fi

# Download the Discovery Document and extract the Token Endpoint URI.
discovery_doc=$(download_file "${discovery_doc_uri}")
token_endpoint=$(extract_token_endpoint "${discovery_doc}")

# Assemble the POST body request query parameters.
params="grant_type=client_credentials"
params+="&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
params+="&client_assertion=$(create_jws "${client_id}" "${kid}" "${discovery_doc}" "${pem}")"

if [ -n "${scopes}" ]; then
  # Scopes provided
  params+="&scope="$(encode_base64url_arg "${scopes}")
fi

# POST the request to the Token Endpoint.
post_token_endpoint "${params}" "${token_endpoint}"