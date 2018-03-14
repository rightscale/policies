
name 'AWS Volume Tag Sync'
rs_ca_ver 20160622
short_description "![RS Policy](https://goo.gl/RAcMcU =64x64)\n
This automated policy CAT will find AWS volumes and synchronize the AWS tags to RightScale tags."
long_description "Version: 1.0"

#Copyright 2017 RightScale
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.

#RightScale Cloud Application Template (CAT)

# DESCRIPTION
# Find EC2 volumes and synchronize the AWS tags to RightScale tags. Synchronization
# is unidirectional from EC2 to RightScale, and is non destructive. If a tag is
# removed from the EC2 volume, it will persist in RightScale
#

##################
# Operations     #
##################

operation "launch" do
  description "Sync volume tags"
  definition "launch"
end


##################
# Definitions    #
##################

define launch() do
  call sync_volume_tags()
end


define sync_volume_tags() do
  @clouds = rs_cm.clouds.get(filter: ["cloud_type==amazon"])

  $region_map = {
    "EC2 us-east-1": "ec2.us-east-1.amazonaws.com",
    "EC2 us-west-1": "ec2.us-west-1.amazonaws.com",
    "EC2 us-west-2": "ec2.us-west-2.amazonaws.com",
    "EC2 eu-west-1": "ec2.eu-west-1.amazonaws.com",
    "EC2 sa-east-1": "ec2.sa-east-1.amazonaws.com",
    "AWS ap-northeast-1": "ec2.ap-northeast-1.amazonaws.com",
    "AWS ap-southeast-1": "ec2.ap-southeast-1.amazonaws.com",
    "EC2 ap-southeast-2": "ec2.ap-southeast-2.amazonaws.com",
    "AWS US-Ohio": "ec2.us-east-2.amazonaws.com",
    "AWS AP-Seoul": "ec2.ap-northeast-2.amazonaws.com",
    "AWS EU-London": "ec2.eu-west-2.amazonaws.com",
    "AWS CA-Central": "ec2.ca-central-1.amazonaws.com",
    "EC2 eu-centra-1": "ec2.eu-central-1.amazonaws.com",
  	"AWS ap-south-1": "ec2.ap-south-1.amazonaws.com"
  }

  concurrent foreach @cloud in @clouds do
    $endpoint = $region_map[@cloud.name]

    if $endpoint
      $response = http_request(
        verb: "post",
        https: true,
        host: $endpoint,
        signature: { "type": "aws" },
        query_strings: { "Action": "DescribeVolumes", "Version": "2016-11-15" }
      )

      if $response['code'] == 200 &&
        contains?(keys($response), ['body']) &&
        $response['body'] != null &&
        contains?(keys($response['body']), ['DescribeVolumesResponse']) &&
        $response['body']['DescribeVolumesResponse'] != null &&
        contains?(keys($response['body']['DescribeVolumesResponse']), ['volumeSet']) &&
        $response['body']['DescribeVolumesResponse']['volumeSet'] != null &&
        contains?(keys($response['body']['DescribeVolumesResponse']['volumeSet']), ['item']) &&
        $response['body']['DescribeVolumesResponse']['volumeSet']['item'] != null
        $item = {}
        call cast_ec2_api_set_to_array($response['body']['DescribeVolumesResponse']['volumeSet']['item']) retrieve $volAry
        concurrent foreach $volume in $volAry do
          $item = $volume
          if contains?(keys($volume), ['tagSet'])
            call cast_ec2_api_set_to_array($volume['tagSet']['item']) retrieve $tagAry
            @volume = @cloud.volumes(filter: ['resource_uid=='+$volume['volumeId']])
            $tags = []
            foreach $tag in $tagAry do
              $tags << 'ec2:'+$tag['key']+'='+$tag['value']
            end
            # It's probably fine to be idempotent here.
            sub on_error: handle_error() do
              rs_cm.tags.multi_add(resource_hrefs: @volume.href[], tags: $tags)
            end
          else
            # Native EC2 Volume had no tags
          end
        end
      else
        # Couldn't get a list of volumes from the EC2 API
      end
    else
      # Couldn't get an endpoint for @cloud.name[]
    end
  end
end

define handle_error() do
  $$error_msg = " failed to delete"
  $_error_behavior = "skip"
end

# Native EC2 APIs return "sets" with one or more items in them. RCL will convert
# sets with 1 item into an "object", or a set with multiple items into an "array".
# This ensures that a set is always an array.
#
# @param $set [Array|Hash] the "set" returned by the API, and interpreted by RCL
#
# @return [Array] always an array of the objects passed in as $set
define cast_ec2_api_set_to_array($set) return $array do
  $setType = type($set)
  if $setType == 'array'
    $array = $set
  else
    $array = [$set]
  end
end
