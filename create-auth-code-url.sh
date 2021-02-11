#!/bin/bash
#
# Outputs an Authorization Code request URL that can be used to initiate an Authorization Code flow.

# Import common functions.
. ./common.sh --source-only

# Suppress Perl warnings that might occur when invoking jq.
init

# Outputs expected usage.
print_usage() {
  echo
  echo "Usage: ./create-auth-code-url.sh -option1 arg1 -option2 arg2 ..."
  echo
  echo "Required options:"
  echo
  echo "-c Client ID"
  echo "-r Redirect URI"
  echo "-d Discovery Document URI (a.k.a. Well-known URI)"
  echo
  echo "Optional options:"
  echo
  echo "-s Scopes (a space-delimited list surrounded by quotes)"
  echo
  exit 1
}

# Parse the command-line options.
while getopts 'c:r:d:s:' flag; do
  case "${flag}" in
    c) client_id="${OPTARG}" ;;
    r) redirect_uri="${OPTARG}" ;;
    d) discovery_doc_uri="${OPTARG}" ;;
    s) scopes="${OPTARG}" ;;
    *) print_usage ;;
  esac
done

# Test for required arguments.
if [ -z "${client_id}" ] || [ -z "${redirect_uri}" ] || [ -z "${discovery_doc_uri}" ]; then
  print_usage
fi

# Download the Discovery Document and extract the Token Endpoint URI.
discovery_doc=$(download_file "${discovery_doc_uri}")
authorization_endpoint=$(echo "${discovery_doc}" | jq -r '.authorization_endpoint')

if [ -z "${authorization_endpoint}" ]; then
  print_error "Failed to retrieve Discovery Document."
fi

# Generate a random state.
state=$(generate_random_string)

# Generate a random PKCE Code Verifier.
code_verifier=$(generate_random_string)

# Apply an S256 one-way hash to the PKCE Code Verifier to create the PKCE Code Challenge.
code_challenge=$(echo -n "${code_verifier}" | shasum -a 256 | cut -d " " -f 1 | xxd -r -p | base64 | tr '+/' '-_' \
  | tr -d '=')

# Assemble the Authorization Code Request URL.
auth_code_url="${authorization_endpoint}"
auth_code_url+="?response_type=code"
auth_code_url+="&redirect_uri="$(encode_base64url_arg "${redirect_uri}")
auth_code_url+="&state=${state}"
auth_code_url+="&code_challenge_method=S256"
auth_code_url+="&client_id=${client_id}"
auth_code_url+="&code_challenge=${code_challenge}"

if [ -n "${scopes}" ]; then
  # Scopes provided
  auth_code_url+="&scope="$(encode_base64url_arg "${scopes}")
fi

# Print the PKCE Code Verifier and the Authorization Code Request URL.
echo
echo "[PKCE Code Verifier]"
echo "${code_verifier}"
echo
echo "[Authorization Code Request URL]"
echo "${auth_code_url}"
echo