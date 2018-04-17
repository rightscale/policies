#!/bin/bash

# Some scripting that automates pushing policy CATs to an account.
# If the publish option is set, the CATs will be PUBLISHED with the name as given in the CAT file but with "POLICY -" prepended to the name.
# 
# PREREQUISITE:
# - rsc is installed. See https://github.com/rightscale/rsc


OPTIND=1
ACCOUNT_ID=""
OAUTH_REFRESH_TOKEN=""
POLICY_LIST_FILE=""
SHARD_HOSTNAME=""
PUBLISH_POLICIES="NO"
SCHEDULE_NAME=""

RSC_CMD="rsc"

while getopts "ha:r:e:f:s:p" opt;
do
case "$opt" in
    h)
	echo ""
    	echo "USAGE: $0 -a ACCOUNT_NUM -e SHARD -f POLICY_LIST [-r REFRESH_TOKEN] [-p] [-s SCHEDULE_NAME]"
	echo ""
	echo "ACCOUNT_NUM is the RightScale account number."
	echo "SHARD is 3 or 4 for us-3 or us-4."
	echo "POLICY_LIST_FILE is a file containing the cats to upload. See master_policy.list in this directory."
	echo "REFRESH_TOKEN is a RightScale refresh token. If not set, script will use settings from \"rsc setup\"."
	echo "-p is an optional parameter to indicate whether or not to publish the CATs."
	echo "SCHEDULE_NAME is the Self-Service schedule name to use when publishing the CATs. If not specified, only the ALWAYS ON schedule is available."
	echo ""
	exit 1
    ;;
    a)
    	ACCOUNT_ID=$OPTARG
	   RSC_CMD="$RSC_CMD -a $ACCOUNT_ID"
    ;;
    r)
    	OAUTH_REFRESH_TOKEN=$OPTARG
	   RSC_CMD="$RSC_CMD -r $OAUTH_REFRESH_TOKEN"
    ;;
    f)
    	POLICY_LIST_FILE=$OPTARG
    ;;
    e)
    	shard=$OPTARG
	   SHARD_HOSTNAME="us-${shard}.rightscale.com"
	   RSC_CMD="$RSC_CMD -h $SHARD_HOSTNAME"

    ;;
    p)
        PUBLISH_POLICIES="YES"
    ;;
    s)
        SCHEDULE_NAME=$OPTARG
    ;;
    *)
	echo "Unknown parameter. Run \"$0 -h\" for help."
	exit 1
    ;;
esac
done

if [ -z $ACCOUNT_ID ]
then
	echo ""
	echo "Missing ACCOUNT_NUM"
	echo ""
	$0 -h
	exit 1
fi

# create a clean version of the list file
tmpfile=$(mktemp)
sed '/^#/d' $POLICY_LIST_FILE | sed '/^$/d' > $tmpfile

# Upload the files
echo "#### UPLOADING POLICY FILES #####"
echo ""
  for cat_filename in `cat $tmpfile`
  do
    cat_name=$(sed -n -e "s/^name[[:space:]]['\"]*\(.*\)['\"]/\1/p" $cat_filename)
    echo "Checking to see if ($cat_name - $cat_filename) has already been uploaded..."
    cat_href=$($RSC_CMD ss index collections/$ACCOUNT_ID/templates "filter[]=name==$cat_name" | jq -r '.[0].href')
    if [[ -z "$cat_href" ]]
    then
      echo "($cat_name - $cat_filename) not already uploaded, creating it now..."
      $RSC_CMD ss create collections/$ACCOUNT_ID/templates source=$cat_filename
    else
      echo "($cat_name - $cat_filename) already uploaded, updating it now..."
      $RSC_CMD ss update $cat_href source=$cat_filename
    fi
  done

rm $tmpfile

# Publish the CAT files if told to
if [ $PUBLISH_POLICIES == "YES" ]
then
    
    SCHED_ADDON=""

    if [ ! -z "${SCHEDULE_NAME}" ]
    then
        # Get schedule information if applicable
        schedule_id=$($RSC_CMD --xm ":has(.name:val(\"${SCHEDULE_NAME}\"))>.id" ss index /designer/collections/$ACCOUNT_ID/schedules | sed 's/"//g')
        if [[ -z "$schedule_id" ]]
        then
            echo "Cannot find schedule named \"${SCHEDULE_NAME}\""
            exit 1
        fi
        
        SCHED_ADDON="schedules[]=${schedule_id}"
    fi
    
    # create a clean version of the list file with the package files removed 
    tmpfile=$(mktemp)
    sed '/^### package files/,/^### package files/{//!d;}' $POLICY_LIST_FILE |
    sed '/^#/d' | sed '/^$/d' > $tmpfile
    
    echo ""
    echo "#### PUBLISHING POLICIES ####"
    echo ""

      for cat_filename in `cat $tmpfile`
      do
            cat_name=$(sed -n -e "s/^name[[:space:]]['\"]*\(.*\)['\"]/\1/p" $cat_filename)
            
            echo "Checking to see if ($cat_name - $cat_filename) has already been uploaded..."
            cat_href=$($RSC_CMD ss index collections/$ACCOUNT_ID/templates "filter[]=name==$cat_name" | jq -r '.[0].href')
            if [[ -z "$cat_href" ]]
            then
              echo "Need to upload the CATs first. Run \"$0 cats\""
              exit 1
            fi
    
            # Toss POLICY in front of name so it can be easily searched and sorted in the catalog.
            # May mean you'll see something like "POLICY - goo policy" but c'est la vie.
            cat_name="POLICY - $cat_name"
    
            echo "Checking to see if ($cat_name - $cat_filename) has already been published ..."
            catalog_href=$($RSC_CMD --pp ss index /api/catalog/catalogs/$ACCOUNT_ID/applications | jq ".[] | select(.name==\"$cat_name\") | .href" | sed 's/"//g')
    
            if [[ -z "$catalog_href" ]]
            then
              echo "($cat_name - $cat_filename) not already published, publishing it now..."
              # Publish the CAT
              $RSC_CMD ss publish /designer/collections/${ACCOUNT_ID}/templates id="${cat_href}" name="${cat_name}" ${SCHED_ADDON}
            else
              echo "($cat_name - $cat_filename) already published, updating it now..."
              $RSC_CMD ss publish /designer/collections/${ACCOUNT_ID}/templates id="${cat_href}" ${SCHED_ADDON} overridden_application_href="${catalog_href}"
            fi
      done
    
    rm $tmpfile
 fi
