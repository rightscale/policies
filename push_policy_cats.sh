#!/bin/bash

# Some scripting that automates pushing policy CATs to an account.
# 
# PREREQUISITE:
# - rsc is installed. See https://github.com/rightscale/rsc
# - "rsc setup" has been run and is configured with the credentials that have access to the account to which the CATs are being uploaded.


OPTIND=1
ACCOUNT_NUM=""
REFRESH_TOKEN=""
POLICY_LIST=""
GET_LIST="NO"

while getopts "ha:r:p:l" opt;
do
case "$opt" in
    h)
    	echo "USAGE: $0 -a ACCOUNT_NUM -p POLICY_LIST [-r REFRESH_TOKEN] [-l]"
	echo "If no -r option is used, settings set via \"rsc setup\" will be used by default"
	echo "POLICY_LIST is a comma-separated list of CAT names to upload."
	echo "-l provides a list of available CATs"
	exit 1
    ;;
    a)
    	ACCOUNT_NUM=$OPTARG
    ;;
    r)
    	REFRESH_TOKEN=$OPTARG
    ;;
    p)
    	POLICY_LIST=$OPTARG
    ;;
    l)
    	GET_LIST=YES
    ;;
esac
done

echo "acctnum: $ACCOUNT_NUM; token: $REFRESH_TOKEN; policies: $POLICY_LIST; get_list: $GET_LIST"

if [ $GET_LIST == "YES" ]
then
	# Look for and list the CATs

