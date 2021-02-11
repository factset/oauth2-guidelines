#!/bin/bash
#
# Exchanges an Authorization Code along with a PKCE Code Verifier for an Access Token and possibly a Refresh Token.

# Import common functions.
. ./common.sh --source-only

# Suppress Perl warnings that might occur when invoking jq.
init

# Outputs expected usage.
print_usage() {
  echo
  echo "Usage: ./request-tokens-with-auth-code.sh -option1 arg1 -option2 arg2 ..."
  echo
  echo "Required options:"
  echo
  echo "-c Client ID"
  echo "-r Redirect URI"
  echo "-d Discovery Document URI (a.k.a. Well-known URI)"
  echo "-o Authorization Code"
  echo "-v PKCE Code Verifier"
  echo
  echo "For Confidential Clients:"
  echo
  echo "-p PEM file containing an RSA public-private key-pair"
  echo "-k Signing Key ID"
  echo
  exit 1
}

# Parse the command-line options.
while getopts 'c:r:d:o:v:p:k:' flag; do
  case "${flag}" in
    c) client_id="${OPTARG}" ;;
    r) redirect_uri="${OPTARG}" ;;
    d) discovery_doc_uri="${OPTARG}" ;;
    o) code="${OPTARG}" ;;
    v) code_verifier="${OPTARG}" ;;
    p) pem="${OPTARG}" ;;
    k) kid="${OPTARG}" ;;
    *) print_usage ;;
  esac
done

# Test for required arguments.
pemProvided=1
if [ -z "${pem}" ]; then
  pemProvided=0
fi
kidProvided=1
if [ -z "${kid}" ]; then
  kidProvided=0
fi
if [ -z "${client_id}" ] || [ -z "${redirect_uri}" ] || [ -z "${discovery_doc_uri}" ] || [ -z "${code}" ] \
    || [ -z "${code_verifier}" ] || [ "${pemProvided}" != "${kidProvided}" ]; then
  print_usage
fi

# Download the Discovery Document and extract the Token Endpoint URI.
discovery_doc=$(download_file "${discovery_doc_uri}")
token_endpoint=$(extract_token_endpoint "${discovery_doc}")

# Assemble the POST body request query parameters.
params="grant_type=authorization_code"
params+="&redirect_uri="$(encode_base64url_arg "${redirect_uri}")
params+="&code=${code}"
params+="&code_verifier=${code_verifier}"

if [ -z "${pem}" ]; then
  # Public Client
  params+="&client_id=${client_id}"
else
  # Confidential Client
  params+="&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
  params+="&client_assertion=$(create_jws "${client_id}" "${kid}" "$discovery_doc" "${pem}")"
fi

# POST the request to the Token Endpoint.
post_token_endpoint "${params}" "${token_endpoint}"