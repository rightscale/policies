name 'Fastly Security Group Rules'
rs_ca_ver 20160622
short_description "Fastly Security Group Rules"
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
# Manages Security Group Rules using Fastly public feed
#


##################
# User inputs    #
##################
parameter "parameter_check_frequency" do
  category "User Inputs"
  label "Minutes between each check."
  type "number"
  default 2
  min_value 1
end

parameter "parameter_start_port" do
  category "User Inputs"
  label "Start port for Security Group ALLOW rule [if only one port, same as end port]"
  type "number"
  default 443
  min_value 1
  max_value 65535
end

parameter "parameter_end_port" do
  category "User Inputs"
  label "End port for Security Group ALLOW rule [if only one port, same as start port]"
  type "number"
  default 443
  min_value 1
  max_value 65535  
end

parameter "parameter_sg_href" do
  category "User Inputs"
  label "Security Group HREF for Fastly IPs"
  type "string"
end


parameter "parameter_last_check_date" do
  category "Advanced"
  label "Fastly lastCheckDate"
  description "Ignore this parameter if you are unsure with how it is used."
  type "string"
  default " "
end

parameter "parameter_last_check_probes" do
  category "Advanced"
  label "Fastly lastCheckProbes"
  description "Ignore this parameter if you are unsure with how it is used."
  type "string"
  default " "
end




####################
# OPERATIONS       #
####################
operation "launch" do
  description "Sync Fastly IPs with Security Group Rules"
  definition "launch_syncSecurityGroupRules"
end

operation "syncFastlySecurityGroupRules" do
  description "Sync Fastly Probes with Security Group Rules"
  definition "syncSecurityGroupRules"
end

define launch_syncSecurityGroupRules($parameter_check_frequency, $parameter_sg_href,$parameter_start_port,$parameter_end_port) do
    # Setup empty values because this is the first time launch and there is no last_check metadata
    $last_check_date = ''
    $last_check_probes = to_json([])
    call syncSecurityGroupRules($parameter_check_frequency,$last_check_date,$last_check_probes,$parameter_sg_href,$parameter_start_port,$parameter_end_port)
end

##################
# Definitions    #
##################
define getProbes() return $fastlyProbes,$fastly_last_check_date do  
  $response = http_get( url: "https://api.fastly.com/public-ip-list" )

  $fastlyProbes = $response["body"]["addresses"]
  $fastly_last_check_date = now()
end

define retry_syncSecurityGroupRules($attempts) do
  if $attempts <= 3
    $_error_behavior = "retry"
  end
end

define syncSecurityGroupRules($parameter_check_frequency,$parameter_last_check_date,$parameter_last_check_probes,$parameter_sg_href,$parameter_start_port,$parameter_end_port) do
  $attempts = 0
  $parameter_last_check_probes = from_json($parameter_last_check_probes)
  sub on_error: retry_syncSecurityGroupRules($attempts) do
    $attempts = $attempts + 1

    #Setup Fastly IPs Array
    call getProbes() retrieve $probes, $last_check_date

    $probes = sort($probes)
    $parameter_last_check_probes = sort($parameter_last_check_probes)
   
    task_label('Comparing Fastly IP Results')
    # Check the array returned from Fastly HTTP request with the array saved from the previous check
    if $parameter_last_check_probes != $probes
        task_label('Fastly IP Feed has been updated, checking security group rules')
        
        #removeOldSecurityGroupRules
        $existing_probes=[]
        @sg_rules = rs_cm.get(href: $parameter_sg_href+"/security_group_rules")
        foreach @sg_rule in @sg_rules do
            $sg_rule = to_object(@sg_rule)
            if to_s($sg_rule["details"][0]["description"]) =~ "Fastly IP - Created by CloudApp" 
            task_label('Checking if ' + to_s($sg_rule["details"][0]["cidr_ips"])+' is still currently active')
            if any?($probes, to_s($sg_rule["details"][0]["cidr_ips"]))
                task_label('Leaving ' + $sg_rule["details"][0]["cidr_ips"] + ' because it is still currently active')
                $existing_probes << $sg_rule["details"][0]["cidr_ips"]
            else
                task_label('Removing ' + $sg_rule["details"][0]["cidr_ips"] + ' because it is NOT currently active')
                @sg_rule.destroy()
            end
        
            end
        end   
        #end removeOldSecurityGroupRules   

        #addSecurityGroupRules
        foreach $probe in $probes do
            if any?($existing_probes,$probe)
                task_label('Rule already exists for ' + $probe + ' - skipping')
            else
                task_label('Creating rule for ' + $probe + ' in security group')
                $rule = {
                    "security_group_href":$parameter_sg_href,
                    "cidr_ips":$probe,
                    "protocol":"tcp",
                    "source_type":"cidr_ips",
                    "direction":"ingress",
                    "protocol_details": {
                        "start_port":$parameter_start_port,
                        "end_port":$parameter_end_port
                        },
                    "description": "Fastly IP - Created by CloudApp"
                    }
                @new_rule = rs_cm.security_group_rules.create(security_group_rule: $rule)
                @new_rule.update(security_group_rule: { "description": "Fastly IP - Created by CloudApp" })
            end  
        end #end addSecurityGroupRules

    end #end if $parameter_last_check_probes != $probes

    task_label('Scheduling next check')
    call schedule_next_check($parameter_check_frequency,$last_check_date,$probes,$parameter_sg_href,$parameter_start_port,$parameter_end_port)

  end #end sub on_error
end


##############
## INCLUDES ##
##############


define schedule_next_check($check_frequency,$last_check_date,$last_check_probes,$parameter_sg_href,$parameter_start_port,$parameter_end_port) do
#Creates a scheduled action to do another check in user-specified minutes

#  call logger(@@deployment, "Scheduling next action in "+$check_frequency+" minutes", "")

  $action_name = "check_" + last(split(@@deployment.href,"/"))

  call find_shard(@@deployment) retrieve $shard
  call sys_get_execution_id() retrieve $execution_id
  call sys_get_account_id() retrieve $account_id

  # delete the old action that ran to get us here.
  call delete_scheduled_action($shard, $execution_id, $account_id, $action_name)

  call login_to_self_service($account_id, $shard)

  $parms = {execution_id: $execution_id, action: "run", first_occurrence: now() + ($check_frequency*60), name: $action_name,
    operation: {"name":"syncFastlySecurityGroupRules",
      "configuration_options":[
        {
          "name":"parameter_check_frequency",
          "type":"number",
          "value": $check_frequency
        },
        {
          "name":"parameter_start_port",
          "type":"string",
          "value": $parameter_start_port
        },
        {
          "name":"parameter_end_port",
          "type":"string",
          "value": $parameter_end_port
        },
        {
          "name":"parameter_last_check_date",
          "type":"string",
          "value": $last_check_date
        },
        {
          "name":"parameter_sg_href",
          "type":"string",
          "value": $parameter_sg_href
        },
        {
          "name":"parameter_last_check_probes",
          "type":"string",
          "value": to_json($last_check_probes)
        }        
    ]
     }
    }  

  $response = http_post(
    url: "https://selfservice-"+$shard+".rightscale.com/api/manager/projects/" + $account_id + "/scheduled_actions",
    headers: { "X-Api-Version": "1.0", "accept": "application/json" },
    body: $parms
  )

#  call logger(@@deployment, "Next schedule post response", to_s($response))

end


# Delete's scheduled action.
define delete_scheduled_action($shard, $execution_id, $account_id, $action_name)  do

  call login_to_self_service($account_id, $shard)

  $response = http_get(
    url: "https://selfservice-" + $shard + ".rightscale.com/api/manager/projects/" + $account_id + "/scheduled_actions?filter[]=execution_id==" + $execution_id + "&filter[]=execution.created_by==me",
    headers: { "X-Api-Version": "1.0", "accept": "application/json" }
  )

  $jbody = from_json($response["body"])

  foreach $action in $jbody do
    if $action["name"] == $action_name
      $response = http_delete(
        url: "https://selfservice-" + $shard + ".rightscale.com" + $action["href"],
        headers: { "X-Api-Version": "1.0", "accept": "application/json" }
      )
    end
  end
end


define sys_get_execution_id() return $execution_id do
# Fetches the execution id of "this" cloud app using the default tags set on a
# deployment created by SS.
# selfservice:href=/api/manager/projects/12345/executions/54354bd284adb8871600200e
#
# @return [String] The execution ID of the current cloud app
  call get_tags_for_resource(@@deployment) retrieve $tags_on_deployment
  $href_tag = map $current_tag in $tags_on_deployment return $tag do
    if $current_tag =~ "(selfservice:href)"
      $tag = $current_tag
    end
  end

  if type($href_tag) == "array" && size($href_tag) > 0
    $tag_split_by_value_delimiter = split(first($href_tag), "=")
    $tag_value = last($tag_split_by_value_delimiter)
    $value_split_by_slashes = split($tag_value, "/")
    $execution_id = last($value_split_by_slashes)
  else
    $execution_id = "N/A"
  end

end

define sys_get_account_id() return $account_id do
# Fetches the account id of "this" cloud app using the default tags set on a
# deployment created by SS.
# selfservice:href=/api/manager/projects/12345/executions/54354bd284adb8871600200e
#
# @return [String] The account ID of the current cloud app
  call get_tags_for_resource(@@deployment) retrieve $tags_on_deployment
  $href_tag = map $current_tag in $tags_on_deployment return $tag do
    if $current_tag =~ "(selfservice:href)"
      $tag = $current_tag
    end
  end

  if type($href_tag) == "array" && size($href_tag) > 0
    $tag_split_by_value_delimiter = split(first($href_tag), "=")
    $tag_value = last($tag_split_by_value_delimiter)
    $value_split_by_slashes = split($tag_value, "/")
    $account_id = $value_split_by_slashes[4]
  else
    $account_id = "N/A"
  end

end

define login_to_self_service($account_id, $shard) do
  $response = http_get(
    url: "https://selfservice-"+$shard+".rightscale.com/api/catalog/new_session?account_id=" + $account_id
  )

#  call logger(@@deployment, "login to self service response", to_s($response))

end

# Returns the RightScale shard for the account the given CAT is launched in.
# It relies on the fact that when a CAT is launched, the resultant deployment description includes a link
# back to Self-Service.
# This link is exploited to identify the shard.
# Of course, this is somewhat dangerous because if the deployment description is changed to remove that link,
# this code will not work.
# Similarly, since the deployment description is also based on the CAT description, if the CAT author or publisher
# puts something like "selfservice-8" in it for some reason, this code will likely get confused.
# However, for the time being it's fine.
define find_shard(@deployment) return $shard_number do

  $deployment_description = @deployment.description
  #rs_cm.audit_entries.create(notify: "None", audit_entry: { auditee_href: @deployment, summary: "deployment description" , detail: $deployment_description})

  # initialize a value
  $shard_number = "UNKNOWN"
  foreach $word in split($deployment_description, "/") do
    if $word =~ "selfservice-"
    #rs_cm.audit_entries.create(notify: "None", audit_entry: { auditee_href: @deployment, summary: join(["found word:",$word]) , detail: ""})
      foreach $character in split($word, "") do
        if $character =~ /[0-9]/
          $shard_number = $character
          #rs_cm.audit_entries.create(notify: "None", audit_entry: { auditee_href: @deployment, summary: join(["found shard:",$character]) , detail: ""})
        end
      end
    end
  end
end


define get_tags_for_resource(@resource) return $tags do
# Returns all tags for a specified resource. Assumes that only one resource
# is passed in, and will return tags for only the first resource in the collection.
#
# @param @resource [ResourceCollection] a ResourceCollection containing only a
#   single resource for which to return tags
#
# @return $tags [Array<String>] an array of tags assigned to @resource
  $tags = []
  $tags_response = rs_cm.tags.by_resource(resource_hrefs: [@resource.href])
  $inner_tags_ary = first(first($tags_response))["tags"]
  $tags = map $current_tag in $inner_tags_ary return $tag do
    $tag = $current_tag["name"]
  end
  $tags = $tags
end

define logger(@deployment, $summary, $details) do
  rs_cm.audit_entries.create(
    notify: "None",
    audit_entry: {
      auditee_href: @deployment,
      summary: $summary,
      detail: $details
      }
    )
end

