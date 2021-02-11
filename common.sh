#!/bin/bash
#
# Common functions used by the other scripts.

#######################################
# Suppresses Perl warnings that might occur when invoking jq.
# Arguments:
#   None
#######################################
init() {
  export LANGUAGE=en_US.UTF-8
  export LANG=en_US.UTF-8
  export LC_ALL=C
}

#######################################
# Prints an error message.
# Arguments:
#   $1 Error message to be printed.
#######################################
print_error() {
  echo
  echo "$1"
  echo
  exit 1
}

#######################################
# Downloads a file.
# Arguments:
#   $1 File URI.
# Outputs:
#   File contents.
#######################################
download_file() {
  local uri=$1
  curl -s "${uri}"
}

#######################################
# Generates a random string with ~256 bits of entropy.
# Outputs:
#   Random string.
#######################################
generate_random_string() {
  < /dev/urandom tr -dc 'a-zA-Z0-9' | fold -w 43 | head -n 1
}

#######################################
# base64url encodes (percent encodes) the input stream.
# Arguments:
#   None
# Outputs:
#   base64url encoded version of the input stream.
#######################################
encode_base64url() {
  openssl enc -base64 -A | tr '+/' '-_' | tr -d '=';
}

#######################################
# base64url encodes (percent encodes) an argument.
# Arguments:
#   $1 String to base64url encode.
# Outputs:
#   base64url encoded version of the argument.
#######################################
encode_base64url_arg() {
  jq -n -r --arg v "$1" '$v|@uri'
}

#######################################
# Compacts the JSON document in the input stream into a single line.
# Arguments:
#   None
# Outputs:
#   Compacted JSON document.
#######################################
compact_json() {
  jq -c . | LC_CTYPE=C tr -d '\n';
}

#######################################
# Digitally signs the input stream with RS256.
# Arguments:
#   $1 Name of PEM file containing an RSA public-private key-pair.
# Outputs:
#   RS256 signature.
#######################################
sign_rs256() {
  local pem=$1
  openssl dgst -binary -sha256 -sign "${pem}"
}

#######################################
# Creates a JSON Web Signature (JWS).
# Arguments:
#   $1 Client ID
#   $2 Signing Key ID
#   $3 Discovery Document contents
#   $4 Name of PEM file containing an RSA public-private key-pair
#######################################
create_jws() {
  local client_id=$1
  local kid=$2
  local discovery_doc=$3
  local pem=$4

  local aud=$(echo "${discovery_doc}" | jq -r '.issuer')

  local header='{
    "kid": "'"${kid}"'",
    "alg": "RS256"
  }'

  local payload='{
    "sub": "'"${client_id}"'",
    "iss": "'"${client_id}"'",
    "aud": ["'"${aud}"'"]
  }'

  payload=$(echo "${payload}" | jq --arg exp_str "$(($(date +%s) + 300))" \
                                   --arg nbf_str "$(($(date +%s) - 5))" \
                                   --arg iat_str "$(($(date +%s)))" \
                                   --arg jti "$(generate_random_string)" \
            '($exp_str | tonumber) as $exp
            |($nbf_str | tonumber) as $nbf
            |($iat_str | tonumber) as $iat
            |.exp=$exp
            |.nbf=$nbf
            |.iat=$iat
            |.jti=$jti')

  local signed_content="$(compact_json <<<"${header}" | encode_base64url).$(compact_json <<<"${payload}" \
      | encode_base64url)"

  printf '%s.%s\n' "${signed_content}" "$(printf %s "${signed_content}" | sign_rs256 "${pem}" | encode_base64url)"
}

#######################################
# Extracts the Token Endpoint URI from the Discovery Document.
# Arguments:
#   $1 Discovery Document contents
#######################################
extract_token_endpoint() {
  local discovery_doc=$1

  local token_endpoint=$(echo "${discovery_doc}" | jq -r '.token_endpoint')

  if [ -z "${token_endpoint}" ]; then
    print_error "Failed to retrieve Discovery Document."
  fi

  echo "${token_endpoint}"
}

#######################################
# Sends an HTTP POST request to the Token Endpoint.
# Arguments:
#   $1 Request body query parameters.
#   $2 Token Endpoint URI.
# Outputs:
#   Pretty-printed version of the resultant JSON document.
#######################################
post_token_endpoint() {
  local params=$1
  local token_endpoint=$2

  echo
  curl -s -d "${params}" -X POST "${token_endpoint}" | jq -r 'to_entries[] | "[\(.key)]\n\(.value)\n"'
}