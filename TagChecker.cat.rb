#Copyright 2015 RightScale
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
# Uses RightScale Cloud Language (RCL) to check all instances in an account for a given tag key and reports back which
# servers or instances are missing the tag.
#
# Future Plans
#   Run continuously checking periodically and using alert infrastructure to send emails.

# Required prolog
name 'Tag Checker'
rs_ca_ver 20131202
short_description "![Tag](https://s3.amazonaws.com/rs-pft/cat-logos/tag.png)\n
Check for a tag and report which instances are missing it."
long_description "Uses RCL to check for a tag and report which instances are missing it."

##################
# User inputs    #
##################
parameter "param_tag_key" do
  category "User Inputs"
  label "Tags' Namespace:Keys List"
  type "string"
  description "Comma-separated list of Tags' Namespace:Keys to audit. For example: \"ec2:project_code\" or \"bu:id\""
  default "costcenter:id"
  allowed_pattern '^([a-zA-Z0-9-_]+:[a-zA-Z0-9-_]+,*)+$'
end

parameter "parameter_check_frequency" do
  category "User Inputs"
  label "Minutes between each check."
  type "number"
  default 5
  min_value 5
end

parameter "parameter_cloud" do
  category "User Inputs"
  label "Cloud to look in (enter cloud href to limit scope)"
  type "string"
  default "All"
end

################################
# Outputs returned to the user #
################################
output "output_bad_instances" do
  label "Instances Missing Specified Tag(s)"
  category "Output"
  description "Instances missing the specified tag(s)."
end



##############
# MAPPINGS   #
##############


############################
# RESOURCE DEFINITIONS     #
############################


##################
# PERMISSIONS    #
##################
# the RCL below reads a credential to use SendGrid and so needs admin to be able to read the cred.
permission "get_cred" do
  actions   "rs.*"
  resources "rs.credentials"
end

####################
# OPERATIONS       #
####################
operation "launch" do
  description "Check for tags!"
  definition "launch_tag_checker"
  output_mappings do {
    $output_bad_instances => $bad_instances,
  } end
end

operation "CheckTags" do
  description "Check for tags!"
  definition "tag_checker"
  output_mappings do {
    $output_bad_instances => $bad_instances,
  } end
end

##########################
# DEFINITIONS (i.e. RCL) #
##########################

define tester() do
  @@deployment = rs.deployments.get(href:"/api/deployments/713187003")
  call tag_checker("mitch:testtag") retrieve $bad_instances
end

# Go through and find improperly tagged instances
define launch_tag_checker($param_tag_key, $parameter_check_frequency, $parameter_cloud) return $bad_instances do
  # add deployment tags for the parameters and then tell tag_checker to go
  rs.tags.multi_add(resource_hrefs: [@@deployment.href], tags: [join(["tagchecker:tag_key=",$param_tag_key])])
  rs.tags.multi_add(resource_hrefs: [@@deployment.href], tags: [join(["tagchecker:check_frequency=",$parameter_check_frequency])])
  rs.tags.multi_add(resource_hrefs: [@@deployment.href], tags: [join(["tagchecker:cloud_scope=",$parameter_cloud])])

  call tag_checker() retrieve $bad_instances
end

# Do the actual work of looking at the tags and identifying bad instances.
define tag_checker() return $bad_instances do

  # Get the stored parameters from the deployment tags
  $tag_key = ""
  $check_frequency = 5
  $cloud_scope = ""
  call get_tags_for_resource(@@deployment) retrieve $tags_on_deployment
  $href_tag = map $current_tag in $tags_on_deployment return $tag do
    if $current_tag =~ "(tagchecker:tag_key)"
      $tag_key = last(split($current_tag,"="))
    elsif $current_tag =~ "(tagchecker:check_frequency)"
      $check_frequency = to_n(last(split($current_tag,"=")))
    elsif $current_tag =~ "(tagchecker:cloud_scope)"
      $cloud_scope = last(split($current_tag,"="))
    end
  end

#  call logger(@@deployment, "tag_key: " + $tag_key, "")


  if $cloud_scope == "All"
    @instances_operational = rs.instances.get(filter: ["state==operational"])
    @instances_provisioned = rs.instances.get(filter: ["state==provisioned"])
    @instances_running = rs.instances.get(filter: ["state==running"])
  else
    @instances_operational = rs.clouds.get(href: $cloud_scope).instances(filter: ["state==operational"])
    @instances_provisioned = rs.clouds.get(href: $cloud_scope).instances(filter: ["state==provisioned"])
    @instances_running = rs.clouds.get(href: $cloud_scope).instances(filter: ["state==running"])
  end

  @instances = @instances_operational + @instances_provisioned + @instances_running

  $instances_hrefs = to_object(@instances)["hrefs"]

#  call logger(@@deployment, "All instance hrefs:", to_s($instances_hrefs))

  $instances_tags = rs.tags.by_resource(resource_hrefs: [$instances_hrefs])

#  call logger(@@deployment, "All instance tags for given hrefs:", to_s($instances_tags))


  # The return from rs.tags is an array of one element which is in turn an array of hashes of this form:
  # {
  #   tags: [
  #     {
  #       name: "TAG_STRING"
  #     },
  #     {
  #       name: "OTHER_TAG_STRING"
  #     }, etc
  #   ],
  #   links: [
  #     {
  #       rel: "resource",
  #       href: "/api/clouds/XXXX/instances/YYYYYY"
  #     }, etc
  #   ],
  #   actions: [
  #   ]
  # }
  #
  #
  $tag_info_array = $instances_tags[0]


  # Loop through the tag info array and find any entries which DO NOT reference the tag(s) in question.
  $param_tag_keys_array = split($tag_key, ",")  # make the parameter list an array so I can search stuff

#  call logger(@@deployment, "param_tag_keys_array:", to_s($param_tag_keys_array))

  $bad_instances_array=[]
  foreach $tag_info_hash in $tag_info_array do
#    call logger(@@deployment, "tag_info_hash:", to_s($tag_info_hash))

    # Create an array of the tags' namespace:key parts
    $tag_entry_ns_key_array=[]
    foreach $tag_entry in $tag_info_hash["tags"] do
      $tag_entry_ns_key_array << split($tag_entry["name"],"=")[0]
    end
#    call logger(@@deployment, "tag_entry_ns_key_array:", to_s($tag_entry_ns_key_array))

    # See if the desired keys are in the found tags and if not take note of the improperly tagged instances
    if logic_not(contains?($tag_entry_ns_key_array, $param_tag_keys_array))
      foreach $resource in $tag_info_hash["links"] do
        $bad_instances_array << $resource["href"]
      end
    end
  end

  $bad_instances = to_s($bad_instances_array)
  call logger(@@deployment, "bad_instances:", $bad_instances)

  # Send an alert email if there is at least one improperly tagged instance
  if logic_not(empty?($bad_instances_array))
    call send_tags_alert_email($tag_key, $cloud_scope, $bad_instances)
  end

  call schedule_next_check($tag_key, $check_frequency)

end

define schedule_next_check($tag_key_list,$check_frequency) do
#Creates a scheduled action to do another check in user-specified minutes

#  call logger(@@deployment, "Scheduling next action in "+$check_frequency+" minutes", "")

  $action_name = "checktags_" + last(split(@@deployment.href,"/"))

  call find_shard(@@deployment) retrieve $shard
  call sys_get_execution_id() retrieve $execution_id
  call sys_get_account_id() retrieve $account_id
  $time = now() + ($check_frequency*60)

  # delete the old action that ran to get us here.
  call delete_scheduled_action($shard, $execution_id, $account_id, $action_name)

  $parms = {execution_id: $execution_id, action: "run", first_occurrence: $time, name: $action_name,
    operation: {"name":"CheckTags" #,
#      "configuration_options":[
#        {
#          "name":"param_tag_key",
#          "type":"string",
#          "value":$tag_key_list
#        },
#        {
#          "name":"parameter_check_frequency",
#          "type":"number",
#          "value":$check_frequency
#        }]
     }
    }

  call login_to_self_service($account_id, $shard)

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
  #rs.audit_entries.create(notify: "None", audit_entry: { auditee_href: @deployment, summary: "deployment description" , detail: $deployment_description})

  # initialize a value
  $shard_number = "UNKNOWN"
  foreach $word in split($deployment_description, "/") do
    if $word =~ "selfservice-"
    #rs.audit_entries.create(notify: "None", audit_entry: { auditee_href: @deployment, summary: join(["found word:",$word]) , detail: ""})
      foreach $character in split($word, "") do
        if $character =~ /[0-9]/
          $shard_number = $character
          #rs.audit_entries.create(notify: "None", audit_entry: { auditee_href: @deployment, summary: join(["found shard:",$character]) , detail: ""})
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
  $tags_response = rs.tags.by_resource(resource_hrefs: [@resource.href])
  $inner_tags_ary = first(first($tags_response))["tags"]
  $tags = map $current_tag in $inner_tags_ary return $tag do
    $tag = $current_tag["name"]
  end
  $tags = $tags
end

# Sends an email using SendGrid service
# REQUIRES that the API key be stored in a credential called SENDGRID_API_KEY
define send_tags_alert_email($tags, $cloud_scope, $bad_instances) do

  # Get API key credential
  @cred = rs.credentials.get(filter: "name==SENDGRID_API_KEY", view: "sensitive")
  $cred_hash = to_object(@cred)
  $cred_value = $cred_hash["details"][0]["value"]
  $api_key = $cred_value

  # Get account ID
  call sys_get_account_id() retrieve $account_id

  # Build email
  $deployment_description_array = lines(@@deployment.description)
  $userid="tbd"
  foreach $entry in $deployment_description_array do
    if include?($entry, "Author")
      $userid = split(split(lstrip(split(split($entry, ":")[1], "(")[0]), '[`')[1],'`]')[0]
    end
  end

  $message = "The following instances are missing tags, " + $tags + ":\n " + $bad_instances

  $body = {
    "personalizations": [{"to": [{"email": $userid}]}],
    "from": {"email": "self-service@rightscale.com"},
    "subject": "Missing Tags Alert - Account: " + $account_id + "- Cloud(s): " + $cloud_scope,
    "content": [{"type": "text/plain", "value": $message}]
  }

  $response = http_post(
    url: "https://api.sendgrid.com/v3/mail/send/beta",
    headers: {
      "authorization": "Bearer " + $api_key,
      "Content-Type": "application/json"
      },
    body: $body
    )

#  call logger(@@deployment, "Email Send Response", to_s($response))
end

define logger(@deployment, $summary, $details) do
  rs.audit_entries.create(
    notify: "None",
    audit_entry: {
      auditee_href: @deployment,
      summary: $summary,
      detail: $details
      }
    )
end
