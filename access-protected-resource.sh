#!/bin/bash
#
# Calls a FactSet API endpoint with an Access Token in the authorization header.

# Import common functions.
. ./common.sh --source-only

# Suppress Perl warnings that might occur when invoking jq.
init

# Outputs expected usage.
print_usage() {
  echo
  echo "Usage: ./access-protected-resource.sh -option1 arg1 -option2 arg2 ..."
  echo
  echo "Required options:"
  echo
  echo "-a Access Token"
  echo "-u Protected Resource URL"
  echo
  exit 1
}

# Parse the command-line options.
while getopts 'a:u:' flag; do
  case "${flag}" in
    a) access_token="${OPTARG}" ;;
    u) resource_url="${OPTARG}" ;;
    *) print_usage ;;
  esac
done

# Test for required arguments.
if [ -z "${access_token}" ] || [ -z "${resource_url}" ]; then
  print_usage
fi

# Send the Access Token in the Authorization header of a GET request.
echo
curl -sk -H "Authorization: Bearer $access_token" "${resource_url}" | jq .
echo