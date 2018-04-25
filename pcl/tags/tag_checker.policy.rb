# Required prolog
name 'Tag Checker'
rs_pt_ver 20180301
type "policy"
short_description "![Tag](https://s3.amazonaws.com/rs-pft/cat-logos/tag.png)\n
Check for a tag and report which instances and volumes are missing it."
long_description "Version: 2.3"
category "Operational"
severity "low"

permission "permissions" do
  actions   "rs_cm.index","rs_cm.show"
  resources "rs_cm.instances","rs_cm.volumes"
end

##################
# User inputs    #
##################
parameter "param_tag_key" do
  category "User Inputs"
  label "Tags' Namespace:Keys List"
  type "string"
  description "Comma-separated list of Tags' Namespace:Keys to audit. For example: \"ec2:project_code\" or \"bu:id\"."
  # allow namespace:key or nothing
  allowed_pattern /^([a-zA-Z0-9-_]+:[a-zA-Z0-9-_]+,*|)+$/
end

parameter "param_advanced_tag_key" do
  category "User Inputs"
  label "Tags' Namespace:Keys Advanced List."
  type "string"
  description "A JSON string or publc HTTP URL to json file."
  #allow http, {*} or nothing.
  allowed_pattern /^(http|\{.*\}|)/
end

parameter "param_email" do
  category "Contact"
  label "Email addresses (separate with commas)"
  type "string"
  # allow list of comma seperated email addresses or nothing
  allowed_pattern /^([a-zA-Z0-9-_.]+[@]+[a-zA-Z0-9-_.]+[.]+[a-zA-Z0-9-_]+,*|)+$/
end

# Retrieve all clouds
resources "all_clouds", type: "rs_cm.clouds"

# Retrieve all operational instances across all clouds
resources "instances_operational", type: "rs_cm.instances" do
  cloud_href href(@all_clouds) # Use the href of clouds retrieved by @all_clouds resources.
  filter do
    state "operational"
  end
end
# Retrieve all provisioned instances across all clouds
resources "instances_provisioned", type: "rs_cm.instances" do
  cloud_href href(@all_clouds) # Use the href of clouds retrieved by @all_clouds resources.
  filter do
    state "provisioned"
  end
end

# Retrieve all running instances across all clouds
resources "instances_running", type: "rs_cm.instances" do
  cloud_href href(@all_clouds) # Use the href of clouds retrieved by @all_clouds resources.
  filter do
    state "running"
  end
end

# Retrieve all volumes across all clouds
resources "volumes", type: "rs_cm.volumes" do
  cloud_href href(@all_clouds) # Use the href of clouds retrieved by @all_clouds resources.
end

datasource "instances_operational" do
     field "href",   val(@instances_operational,'href')
     field "id",     val(@instances_operational,'resource_uid')
     field "name",   val(@instances_operational,'name')
     field "state",  val(@instances_operational,'state')
     field "cloud",  val(@instances_operational,'cloud')
     field "type",   "Instance"
end
datasource "instances_running" do
     field "href",   val(@instances_running,'href')
     field "id",     val(@instances_running,'resource_uid')
     field "name",   val(@instances_running,'name')
     field "state",  val(@instances_running,'state')
     field "cloud",  val(@instances_running,'cloud')
     field "type",   "Instance"
end
datasource "instances_provisioned" do
     field "href",   val(@instances_provisioned,'href')
     field "id",     val(@instances_provisioned,'resource_uid')
     field "name",   val(@instances_provisioned,'name')
     field "state",  val(@instances_provisioned,'state')
     field "cloud",  val(@instances_provisioned,'cloud')
     field "type",   "Instance"
end

datasource "volumes" do
     field "href",   val(@volumes,'href')
     field "id",     val(@volumes,'resource_uid')
     field "name",   val(@volumes,'name')
     field "state",  val(@volumes,'state')
     field "cloud",  val(@volumes,'cloud')
     field "type",   "Volume"
end


datasource "resources" do
  run_script $merge_resources, $instances_operational,$instances_provisioned,$instances_running,$volumes
end

script "merge_resources", type: "javascript" do
  parameters "instances_operational","instances_provisioned","instances_running", "volumes"
  result "resources"
  code <<-EOS
  var resources = []
  for (i = 0; i < instances_operational.length; i++) {
    resources.push(instances_operational[i])
  }
  for (i = 0; i < instances_provisioned.length; i++) {
    resources.push(instances_provisioned[i])
  }
  for (i = 0; i < instances_running.length; i++) {
    resources.push(instances_running[i])
  }
  for (i = 0; i < volumes.length; i++) {
    resources.push(volumes[i])
  }
  EOS
end

escalation "escalate_resources" do
  email $param_email do
    subject_template "Escalated Untagged Resources" # There will be a default template we use.
    body_template     <<-EOS
    The following resources are unattached:
    { range data }
    * Region: { $.cloud }
    * Type: { $.type }
    * Name: { $.name }
    * State: { $.state }
    * HREF: { $.href }
    { end }
    EOS
  end
  run "tag_checker", data, $param_tag_key, $param_advanced_tag_key
end


resolution "resolve_resources" do
  email $param_email do
  subject_template "Resolved Untagged Resources"
  body_template <<-EOS
The resources have been tagged by the tag policy
EOS
end

end

policy "untagged_resources_policy" do
  validate $resources do
    summary_template "Untagged Resources Summary"
    detail_template <<-EOS
    Instances
    The following instances are missing tags:
    { range data }
    * Region: { $.cloud }
    * Type: { $.type }
    * Name: { $.name }
    * State: { $.state }
    * HREF: { $.href }
    { end }
    EOS
    escalate $escalate_resources
    check ""
    resolve $resolve_resources
  end
end

# Do the actual work of looking at the tags and identifying bad instances.
define tag_checker($data, $param_tag_key, $param_advanced_tag_key)  do
  # Get the stored parameters from the deployment tags
  $tag_key = ""
  $advanced_tag_keys = {}
  $advanced_tags = {}
  $delete_days = 0
  # retrieve tags on current deployment
  # don't think this deployment has any tags we need, as it's the cloudapp  - EG
  #call get_tags_for_resource(@@deployment) retrieve $tags_on_deployment

  # sub on_error: skip do
  # call sys_log(@@execution.name, 'Tag Checker Status: Started')
  # end

  $tag_key = $param_tag_key
  $advanced_tag_key_value =  $param_advanced_tag_key
  if $advanced_tag_key_value =~ /^http/
    $json = http_get({ url: $advanced_tag_key_value})
    $advanced_tags = from_json($json['body'])
  else
    $advanced_tags = from_json($advanced_tag_key_value)
  end

  # Loop through the tag info array and find any entries which DO NOT reference the tag(s) in question.
  $param_tag_keys_array = split($tag_key, ",")  # make the parameter list an array so I can search stuff
  # add advanced_tag_keys to param_tag_keys_array array
  foreach $key in keys($advanced_tag_keys) do
    $param_tag_keys_array << $key
  end

  # sub on_error: skip do
  # call sys_log(@@execution.name, join(["Tag Checker Tag Key Array:", $param_tag_keys_array]) )
  # end
  # for testing.  change the deployment_href to one that includes a few servers
  # to test with.  uncomment code and comment the concurrent block below it.
  #  $deployment_href =  '/api/deployments/378563001' # replace with your deployment here
  #  @instances = rs_cm.instances.get(filter: ["state==operational","deployment_href=="+$deployment_href])
  #  $operational_instances_hrefs = to_object(@instances)["hrefs"]
  #  @volumes = rs_cm.volumes.get(filter: ["deployment_href=="+$deployment_href])
  #  $volume_hrefs = to_object(@volumes)["hrefs"]
  #  $instances_hrefs = $operational_instances_hrefs + $volume_hrefs

  # concurrent return $operational_instances_hrefs, $provisioned_instances_hrefs, $running_instances_hrefs, $volume_hrefs do
  #   sub do
  #     @instances_operational = rs_cm.instances.get(filter: ["state==operational"])
  #     $operational_instances_hrefs = to_object(@instances_operational)["hrefs"]
  #     call sys_log("Operational Instances:", join(["Operational Instances:", $operational_instances_hrefs]) )
  #   end
  #   sub do
  #     @instances_provisioned = rs_cm.instances.get(filter: ["state==provisioned"])
  #     $provisioned_instances_hrefs = to_object(@instances_provisioned)["hrefs"]
  #     call sys_log("Provisioned Instances:", join(["Provisioned Instances:", $provisioned_instances_hrefs]) )
  #   end
  #   sub do
  #     @instances_running = rs_cm.instances.get(filter: ["state==running"])
  #     $running_instances_hrefs = to_object(@instances_running)["hrefs"]
  #     call sys_log("Running Instances:", join(["Running Instances:", $running_instances_hrefs]) )
  #   end
  #   sub do
  #     @volumes = rs_cm.volumes.get()
  #     $volume_hrefs = to_object(@volumes)["hrefs"]
  #     call sys_log("Volumes: ",join(["Volumes: ", $volume_hrefs]) )
  #   end
  # end


  # $instances_hrefs = $operational_instances_hrefs + $provisioned_instances_hrefs + $running_instances_hrefs + $volume_hrefs



  $$bad_instances_array={}
  $$add_tags_hash = {}
  $$add_prefix_value = {}
  concurrent foreach $item in $data do
    $instances_tags = rs_cm.tags.by_resource(resource_hrefs: [$item['href']])
    $tag_info_array = $instances_tags[0]

    @resource = rs_cm.get(href: $item['href'])
    $resource = to_object(@resource)

    # resource must be an instance
    # resource must be a volume not AzureRM
    # resource must be a volume in AzureRM without volume_type
    # if the volume is in azureRM and not a Managed Disk then skip
    if $resource['type'] == 'instances' || ($resource['type'] == 'volumes' && @resource.cloud().name !~ /^AzureRM/) || ($resource['type'] == 'volumes' && @resource.cloud().name =~ /^AzureRM/ && any?(select($resource['details'][0]['links'],{rel: 'volume_type'})))
      # check for missing tags
      call check_tag_key($tag_info_array,$param_tag_keys_array,$advanced_tags)
      # check for incorrect tag values
      call check_tag_value($tag_info_array, $advanced_tags)
    end
  end
  # add missing tag with default value from $advanced_tags
  if any?(keys($advanced_tags))
   call add_tag_to_resources($advanced_tags)
   call update_tag_prefix_value($advanced_tags)
  end


  $bad_instances = to_s(unique(keys($$bad_instances_array)))
end

# Returns the RightScale shard for the account the given CAT is launched in.
define find_shard() return $shard_number do
  $account = rs_cm.get(href: "/api/accounts/" + $$account_number)
  $shard_number = last(split(select($account[0]["links"], {"rel":"cluster"})[0]["href"],"/"))
end

define find_account_name() return $account_name do
  $session_info = rs_cm.sessions.get(view: "whoami")
  $acct_link = select($session_info[0]["links"], {rel: "account"})
  $acct_href = $acct_link[0]["href"]
  $account_name = rs_cm.get(href: $acct_href).name
end

define get_tags_for_resource(@resource) return $tags do
  # Returns all tags for a specified resource. Assumes that only one resource
  # is passed in, and will return tags for only the first resource in the collection.

  # @param @resource [ResourceCollection] a ResourceCollection containing only a
  #   single resource for which to return tags

  # @return $tags [Array<String>] an array of tags assigned to @resource
  $tags = []
  $tags_response = rs_cm.tags.by_resource(resource_hrefs: [@resource.href])
  $inner_tags_ary = first(first($tags_response))["tags"]
  $tags = map $current_tag in $inner_tags_ary return $tag do
    $tag = $current_tag["name"]
  end
  $tags = $tags
end


define set_instance_error() do
  $$resource_error = 'true'
  $_error_behavior = "skip"
end

# check the list of tags from instances if the key match
#
define check_tag_key($tag_info_array,$param_tag_keys_array,$advanced_tags) do
  $resource_array=[]
  $advanced_tags_keys = keys($advanced_tags)
  $default_value_keys = []
  $missing_tag_array = []
  foreach $key in $advanced_tags_keys do
    if $advanced_tags[$key]['default-value']
      $default_value_keys << $key
    end
  end
  foreach $tag_info_hash in $tag_info_array do
    # Create an array of the tags' namespace:key parts
    $tag_entry_ns_key_array=[]
    foreach $tag_entry in $tag_info_hash["tags"] do
      $tag_entry_ns_key_array << split($tag_entry["name"],"=")[0]
    end

    foreach $key in $default_value_keys do
      if !contains?($tag_entry_ns_key_array, [$key])

        # get previous items in array, so we can include them all in
        # $$add_tags_hash[$tag_key] later
        if $$add_tags_hash[$key]
          $$add_tags_hash[$key]  = unique($$add_tags_hash[$key])
        end
        foreach $item in $$add_tags_hash[$key] do
          $resource_array << $item
        end
        $resource_array << $tag_info_hash['links'][0]['href']
        $$add_tags_hash[$key] = $resource_array
      end
    end

    # See if the desired keys are in the found tags and if not take note of the improperly tagged instances
    if logic_not(contains?($tag_entry_ns_key_array, $param_tag_keys_array))
       foreach $required_tag in $param_tag_keys_array do
         if !contains?($tag_entry_ns_key_array,[$required_tag])
           $missing_tag_array << $required_tag
         end
       end
        foreach $resource in $tag_info_hash["links"] do
          $$bad_instances_array[$resource["href"]]={missing: $missing_tag_array}
      end
    end
  end
end

# check list of resource tags with advanced validation
define check_tag_value($tag_info_array,$advanced_tags) do
  foreach $tag_info_hash in $tag_info_array do
    # Create an array of the tags' namespace:key parts
    $tag_entry_ns_key_array=[]
    $missing=[]
    foreach $tag_entry in $tag_info_hash["tags"] do
      $tag_entry_ns_key_array << split($tag_entry["name"],"=")[0]
      $tag_value = split($tag_entry["name"],"=")[1]
      foreach $tag_key in $tag_entry_ns_key_array do
        # find instance without values in validation array
        if $advanced_tags[$tag_key] && $advanced_tags[$tag_key]['validation-type']=='array'
          if !contains?($advanced_tags[$tag_key]['validation'],[$tag_value])
              foreach $resource in $tag_info_hash["links"] do
                call add_tag_prefix_value($advanced_tags,$tag_key,$tag_entry,$resource)
                if $$bad_instances_array[$resource["href"]] && $$bad_instances_array[$resource["href"]]['missing']
                  $missing = $$bad_instances_array[$resource["href"]]['missing']
                end
                $missing << $tag_key
                $$bad_instances_array[$resource["href"]]={
                  missing: $missing,
                  invalid: []
                }
              end
          end
        end
        # find instance without value in validation string
        if $advanced_tags[$tag_key] && $advanced_tags[$tag_key]['validation-type']=='string'
          if $tag_value != $advanced_tags[$tag_key]['validation']
              foreach $resource in $tag_info_hash["links"] do
                call add_tag_prefix_value($advanced_tags,$tag_key,$tag_entry,$resource)
                if $$bad_instances_array[$resource["href"]] && $$bad_instances_array[$resource["href"]]['missing']
                  $missing = $$bad_instances_array[$resource["href"]]['missing']
                end
                $missing << $tag_key
                $$bad_instances_array[$resource["href"]]={
                  missing: $missing,
                  invalid: []
                }
              end
          end
        end
        # find instance without values in validation regex
        if $advanced_tags[$tag_key] && $advanced_tags[$tag_key]['validation-type']=='regex'
          if $tag_value !~ $advanced_tags[$tag_key]['validation']
              foreach $resource in $tag_info_hash["links"] do
                call add_tag_prefix_value($advanced_tags,$tag_key,$tag_entry,$resource)
                if $$bad_instances_array[$resource["href"]] && $$bad_instances_array[$resource["href"]]['missing']
                  $missing = $$bad_instances_array[$resource["href"]]['missing']
                end
                $missing << $tag_key
                $$bad_instances_array[$resource["href"]]={
                  missing: $missing,
                  invalid: []
                }
              end
          end
        end
      end
    end
  end
end

# adds tag with default-value from $advanced_tags json
define add_tag_to_resources($advanced_tags) do
  $clouds = {}
  # get list of resource and and missing tags.
  foreach $key in keys($$add_tags_hash) do
    if $advanced_tags[$key] && $advanced_tags[$key]['default-value']
      foreach $resource in $$add_tags_hash[$key] do
        # make a map of recourses by cloud to add tags
        if $resource
          $cloud_id = split($resource,'/')[3]
          $resource_array=[]
          foreach $item in $clouds[$cloud_id] do
            $resource_array << $item
          end
          $resource_array << $resource
          $clouds[$cloud_id] = $resource_array
        end
      end
      # tag each resource by cloud
      foreach $cloud in keys($clouds) do
        if any?($clouds[$cloud])
          rs_cm.tags.multi_add(resource_hrefs: $clouds[$cloud], tags: [join([$key,"=",$advanced_tags[$key]['default-value']])])
        end
      end
    end
  end
end

# update hash to store tag key, resource and tag value
# to update the tag later with prefix-value
define add_tag_prefix_value($advanced_tags,$tag_key,$tag_entry,$resource) do
  if $advanced_tags[$tag_key]['prefix-value']  && $tag_key == split($tag_entry["name"],"=")[0]
    $array = []
    foreach $item in $$add_prefix_value[$tag_key] do
      $array << $item
    end
    $array << { resource_href: $resource['href'], tag_value: $tag_value }
    $$add_prefix_value[$tag_key]=$array
  end
end

# add prefix value to tags with incorrect value
define update_tag_prefix_value($advanced_tags) do
  # get list of resource and and missing tags.
  $invalid=[]
  foreach $key in keys($$add_prefix_value) do
    foreach $item in $$add_prefix_value[$key] do
      $new_value = $advanced_tags[$key]['prefix-value'] + $item['tag_value']
      $resource = $item['resource_href']
      $tag = join([$key,"=",$new_value])
      # get existing invalid value to attend other values later.
      if $$bad_instances_array[$resource] && $$bad_instances_array[$resource]['invalid']
        $invalid = $$bad_instances_array[$resource]['invalid']
      end
      #avoid prepending invalid-value to invalid column in csv file
      if !include?($item['tag_value'],$advanced_tags[$key]['prefix-value'])
        $invalid << $tag
      else
        $invalid << join([$key,"=",$item['tag_value']])
      end

      $$bad_instances_array[$resource]={
        invalid: $invalid,
        missing: $$bad_instances_array[$resource]["missing"]
      }

      # no need to add the tag if it's already been set.
      if !include?($item['tag_value'],$advanced_tags[$key]['prefix-value'])
        rs_cm.tags.multi_add(resource_hrefs: [$resource], tags: [$tag])
      end
    end
  end
end

define sys_log($subject, $detail) do
  rs_cm.audit_entries.create(
    notify: "None",
    audit_entry: {
      auditee_href: @@account,
      summary: $subject,
      detail: $detail
    }
  )
end
