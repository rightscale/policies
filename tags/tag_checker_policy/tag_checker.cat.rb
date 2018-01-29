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
# Uses RightScale Cloud Language (RCL) to check all instances in an account for a given tag key and reports back which
# servers or instances are missing the tag.
#
# Future Plans
#   Run continuously checking periodically

# Required prolog
name 'Tag Checker'
rs_ca_ver 20161221
short_description "![Tag](https://s3.amazonaws.com/rs-pft/cat-logos/tag.png)\n
Check for a tag and report which instances and volumes are missing it."
long_description "Version: 2.0"
import "mailer"

##################
# User inputs    #
##################
parameter "param_tag_key" do
  category "User Inputs"
  label "Tags' Namespace:Keys List"
  type "string"
  description "Comma-separated list of Tags' Namespace:Keys to audit. For example: \"ec2:project_code\" or \"bu:id\"."
  # allow namespace:key or nothing
  allowed_pattern '^([a-zA-Z0-9-_]+:[a-zA-Z0-9-_]+,*|)+$'
end

parameter "param_advanced_tag_key" do
  category "User Inputs"
  label "Tags' Namespace:Keys Advanced List."
  type "string"
  description "A JSON string or publc HTTP URL to json file."
  #allow http, {*} or nothing.
  allowed_pattern '^(http|\{.*\}|)'
end

parameter "param_delete_days" do
  category "User Inputs"
  label "# of days from now for delete_date tag value"
  type "string"
  #allows any number between 1-99 or blank
  allowed_pattern '(^[1-9][0-9]*$|)'
end

parameter "param_email" do
  category "Contact"
  label "Email addresses (separate with commas)"
  type "string"
  # allow list of comma seperated email addresses or nothing
  allowed_pattern '^([a-zA-Z0-9-_.]+[@]+[a-zA-Z0-9-_.]+[.]+[a-zA-Z0-9-_]+,*|)+$'
end

parameter "param_run_once" do
  category "Run Once"
  label "If set to true the cloud app will terminate itself after completion."
  type "string"
  default "true"
  allowed_values "true","false"
end

################################
# Outputs returned to the user #
################################
output "output_bad_instances" do
  label "Resources Missing Specified Tag(s)"
  category "Output"
  description "Resources missing the specified tag(s)."
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

operation "checktags" do
  description "Check for tags!"
  definition "tag_checker"
  output_mappings do {
    $output_bad_instances => $bad_instances,
  } end
end

##########################
# DEFINITIONS (i.e. RCL) #
##########################
# Go through and find improperly tagged instances
define launch_tag_checker($param_tag_key,$param_advanced_tag_key,$param_email,$param_run_once,$param_delete_days) return $bad_instances do
  # add deployment tags for the parameters and then tell tag_checker to go
  if $param_tag_key != ""
    rs_cm.tags.multi_add(resource_hrefs: [@@deployment.href], tags: [join(["tagchecker:tag_key=",$param_tag_key])])
  end
  if $param_advanced_tag_key != ""
    rs_cm.tags.multi_add(resource_hrefs: [@@deployment.href], tags: [join(["tagchecker:advanced_tag_key=",$param_advanced_tag_key])])
  end
  if $param_delete_days != ""
    rs_cm.tags.multi_add(resource_hrefs: [@@deployment.href], tags: [join(["tagchecker:delete_days=",$param_delete_days])])
  end

  call tag_checker() retrieve $bad_instances

  if $param_run_once == "true"
    $time = now() + 30
    rs_ss.scheduled_actions.create(
      execution_id: @@execution.id,
      action: "terminate",
      first_occurrence: $time
    )
  end
end

# Do the actual work of looking at the tags and identifying bad instances.
define tag_checker() return $bad_instances do
  # Get the stored parameters from the deployment tags
  $tag_key = ""
  $advanced_tag_keys = {}
  $advanced_tags = {}
  $delete_days = 0
  # retrieve tags on current deployment
  call get_tags_for_resource(@@deployment) retrieve $tags_on_deployment

  $href_tag = map $current_tag in $tags_on_deployment return $tag do
    if $current_tag =~ "(tagchecker:tag_key)"
      $tag_key = last(split($current_tag,"="))
    elsif $current_tag =~ "(tagchecker:advanced_tag_key)"
      $advanced_tag_key_value =  last(split($current_tag,"="))
      if $advanced_tag_key_value =~ /^http/
        $json = http_get({ url: $advanced_tag_key_value})
        $advanced_tags = from_json($json['body'])
      else
        $advanced_tags = from_json($advanced_tag_key_value)
      end
    elsif $current_tag =~ "(tagchecker:delete_days)"
      $delete_days =  to_n(last(split($current_tag,"=")))
    end
  end

  # Loop through the tag info array and find any entries which DO NOT reference the tag(s) in question.
  $param_tag_keys_array = split($tag_key, ",")  # make the parameter list an array so I can search stuff
  # add advanced_tag_keys to param_tag_keys_array array
  foreach $key in keys($advanced_tag_keys) do
    $param_tag_keys_array << $key
  end

  # for testing.  change the deployment_href to one that includes a few servers
  # to test with.  uncomment code and comment the concurrent block below it.
   $deployment_href =  '/api/deployments/378563001' # replace with your deployment here
   @instances = rs_cm.instances.get(filter: ["state==operational","deployment_href=="+$deployment_href])
   $operational_instances_hrefs = to_object(@instances)["hrefs"]
   @volumes = rs_cm.volumes.get(filter: ["deployment_href=="+$deployment_href])
   $volume_hrefs = to_object(@volumes)["hrefs"]
   $instances_hrefs = $operational_instances_hrefs + $volume_hrefs

  # concurrent return $operational_instances_hrefs, $provisioned_instances_hrefs, $running_instances_hrefs, $volume_hrefs do
  #   sub do
  #     @instances_operational = rs_cm.instances.get(filter: ["state==operational"])
  #     $operational_instances_hrefs = to_object(@instances_operational)["hrefs"]
  #   end
  #   sub do
  #     @instances_provisioned = rs_cm.instances.get(filter: ["state==provisioned"])
  #     $provisioned_instances_hrefs = to_object(@instances_provisioned)["hrefs"]
  #   end
  #   sub do
  #     @instances_running = rs_cm.instances.get(filter: ["state==running"])
  #     $running_instances_hrefs = to_object(@instances_running)["hrefs"]
  #   end
  #   sub do
  #     @volumes = rs_cm.volumes.get()
  #     $volume_hrefs = to_object(@volumes)["hrefs"]
  #   end
  # end
  #
  # $instances_hrefs = $operational_instances_hrefs + $provisioned_instances_hrefs + $running_instances_hrefs + $volume_hrefs

  $$bad_instances_array={}
  $$add_tags_hash = {}
  $$add_prefix_value = {}
  foreach $hrefs in $instances_hrefs do
    $instances_tags = rs_cm.tags.by_resource(resource_hrefs: [$hrefs])
    $tag_info_array = $instances_tags[0]

    @resource = rs_cm.get(href: $hrefs)
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

  if $delete_days > 0
    call add_delete_date_tag($delete_days)
  end


  $bad_instances = to_s(unique(keys($$bad_instances_array)))

  # get the users email and add to param_email
  $user_email = tag_value(@@deployment, 'selfservice:launched_by')
  $param_email = $user_email +','+$param_email

  # Send an alert email if there is at least one improperly tagged instance
  if logic_not(empty?(keys($$bad_instances_array)))
    call send_tags_alert_email(join($param_tag_keys_array,','),$param_email)
  end
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

define send_tags_alert_email($tags,$to) do
  # Get account ID
  call find_account_name() retrieve $account_name
  call find_account_number() retrieve $$account_number
  call find_shard() retrieve $$shard
  $endpoint = "http://policies.services.rightscale.com"
  # Build email
  $subject = "Tag Checker Policy: "
  $from = "policy-cat@services.rightscale.com"
  $email_msg = "RightScale discovered that the following resources are missing tags <b>" + $tags + "</b> in <b>"+ $account_name +".</b> Per the policy set by your organization, these resources are not compliant.  View the attached CSV file for more details."

  $table_start="<td align=%22left%22 valign=%22top%22>"
  $table_end="</td>"
  $header="
    \<\!DOCTYPE html PUBLIC \"-\/\/W3C\/\/DTD XHTML 1.0 Transitional\/\/EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\"\>
    <html xmlns=\"http:\/\/www.w3.org\/1999\/xhtml\">
    <head>
      <meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\" />
      <a href=\"http://www.rightscale.com\">
      <img src=\"https://assets.rightscale.com/6d1cee0ec0ca7140cd8701ef7e7dceb18a91ba20/web/images/logo.png\" alt=\"RightScale Logo\" width=\"200px\" /></a>
    <style></style>
    </head>
    <body>
      <table border=\"0\" cellpadding=\"0\" cellspacing=\"0\" height=\"100%\" width=\"100%\" id=\"bodyTable\">
        <tr>
          <td align=\"left\" valign=\"top\">
            <table border=\"0\" cellpadding=\"20\" cellspacing=\"0\" width=\"100%\" id=\"emailContainer\">
              <tr>
                <td align=\"left\" valign=\"top\">
                  <table border=\"0\" cellpadding=\"20\" cellspacing=\"0\" width=\"100%\" id=\"emailHeader\">
                    <tr>
                      <td align=\"left\" valign=\"top\">
                        " + $email_msg + "
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
            <tr>
              <td align=\"left\" valign=\"top\">
                <table border=\"0\" cellpadding=\"10\" cellspacing=\"0\" width=\"100%\" id=\"emailBody\">
                  <tr>
                    <td align=\"left\" valign=\"top\">
                      Resource Name
                    </td>
                    <td align=\"left\" valign=\"top\">
                      State
                    </td>
                    <td align=\"left\" valign=\"top\">
                      Link
                    </td>
                  </tr>"
  $footer="
                    </tr>
                  </table>
                </td>
              </tr>
              <tr>
                <td align=\"left\" valign=\"top\">
                  <table border=\"0\" cellpadding=\"20\" cellspacing=\"0\" width=\"100%\" id=\"emailFooter\">
                    <tr>
                      <td align=\"left\" valign=\"top\">
                        This report was automatically generated by a policy template tag checker your organization has defined in RightScale.
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
          </table>
        </td>
      </tr>
      </table>
    </body>
  </html>"

  $columns = ["Cloud Type","Cloud","Resource Type","Resource UID","Resource Name","Created","Missing Tags","Invalid values","Delete Date", "State", "Link"]
  call mailer.create_csv_with_columns($endpoint,$columns) retrieve $filename
  $$csv_filename = $filename

  $$list_of_instances=""
  foreach $resource in unique(keys($$bad_instances_array)) do
    $$resource_error = 'false'
    @resource = rs_cm.servers.empty()

    sub on_error: set_instance_error() do
      @resource = rs_cm.get(href: $resource)
    end

    $resource_object = to_object(@resource)

    if $$resource_error == 'true'
      #issue with the instance, may no longer exists
    else
      # Get resource name
        # try for the instance name first, then get resource_uid
      $resource_name = $resource_object["details"][0]["name"]
      if !$resource_name
        $resource_name = $resource_object["details"][0]["resource_uid"]
      end

      if $resource_name == null
        $resource_name = 'unknown'
      end

      # Get resource state/status
      if $resource_object['type'] == 'instances'
        if $resource_object["details"][0]["state"] == null
          $resource_state = 'unknown'
        else
          $resource_state = $resource_object["details"][0]["state"]
        end
      elsif $resource_object['type'] == 'volumes'
        if $resource_object["details"][0]["status"] == null
          $resource_state = 'unknown'
        else
          $resource_state = $resource_object["details"][0]["status"]
        end
      end


      # Get server access link
      $server_access_link_root = 'unknown'
      sub on_error: skip do
        call get_server_access_link($resource, $resource_object['type']) retrieve $server_access_link_root
      end
      if $server_access_link_root == null
        $server_access_link_root = 'unknown'
      end

      $resource_date = strftime(to_d(@resource.created_at),"%Y-%m-%d")
      $missing = ""
      $invalid = ""
      $delete_date = tag_value(@resource,'rs_policy:delete_date')
      if $$bad_instances_array[@resource.href]['missing']
        $missing = join(unique($$bad_instances_array[@resource.href]['missing']),',')
      end
      if $$bad_instances_array[@resource.href]['invalid']
        $invalid = join(unique($$bad_instances_array[@resource.href]['invalid']),',')
      end

      # Create the instance table
      #["Cloud","Resource UID","Resource Name","Created","Missing Tags","Invalid values","Delete Date", "State", "Link"]
      call mailer.update_csv_with_rows($endpoint, $filename, [@resource.cloud().cloud_type, @resource.cloud().name,$resource_object['type'], @resource.resource_uid,$resource_name,$resource_date,$missing,$invalid,$delete_date, $resource_state, $server_access_link_root]) retrieve $filename
      $instance_table = "<tr>" + $table_start + $resource_name + $table_end + $table_start + $resource_state + $table_end + $table_start + $server_access_link_root + $table_end + "</tr>"
      insert($$list_of_instances, -1, $instance_table)
    end
  end

  $email_body = $header + $$list_of_instances + $footer
  call mailer.send_html_email($endpoint, $to, $from, $subject, $email_body, $filename, "html") retrieve $response

  if $response['code'] != 200
    raise 'Failed to send email report: ' + to_s($response)
  end
end

define set_instance_error() do
  $$resource_error = 'true'
  $_error_behavior = "skip"
end

# Returns the RightScale account number in which the CAT was launched.
define find_account_number() return $account_id do
  $session = rs_cm.sessions.index(view: "whoami")
  $account_id = last(split(select($session[0]["links"], {"rel":"account"})[0]["href"],"/"))
end

define get_server_access_link($instance_href, $resource_type) return $server_access_link_root do
  $rs_endpoint = "https://us-"+$$shard+".rightscale.com"

  $instance_id = last(split($instance_href, "/"))

  if $resource_type == 'instances'
    $response = http_get(
      url: $rs_endpoint+"/api/" + $resource_type + "?ids=" + $instance_id,
      headers: {
        "X-Api-Version": "1.6",
        "X-Account": $$account_number
      }
    )
    $instances = $response["body"]
    $instance_of_interest = select($instances, { "href" : $instance_href })[0]

    if $instance_of_interest["legacy_id"] == null
      $legacy_id = "unknown"
    else
      $legacy_id = $instance_of_interest["legacy_id"]
    end

    $data = split($instance_href, "/")
    $cloud_id = $data[3]
    $server_access_link_root = "https://my.rightscale.com/acct/" + $$account_number + "/clouds/" + $cloud_id + "/"+ $resource_type +"/" + $legacy_id
  elsif $resource_type == 'volumes'
    $server_access_link_root = "https://my.rightscale.com" + $instance_href
  end
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
                  call sys_log('missing1',to_s($$bad_instances_array[$resource["href"]]))
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
                call sys_log('missing2',to_s($$bad_instances_array[$resource["href"]]))
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
                call sys_log('missing3',to_s($$bad_instances_array[$resource["href"]]))
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

# add a rs_policy:delete_date tag to invalid instances
# only add the tag if it doesn't exist.
define add_delete_date_tag($delete_days) do
  $clouds = {}
  $delete_date = to_d(to_n(strftime(now(),'%s')) + (86400 * to_n($delete_days)))
  $formated_delete_date = strftime($delete_date,'%F')
  # get list of resource and and missing tags.
  foreach $resource in unique(keys($$bad_instances_array)) do
    # make a map of resources by cloud to add tags
    # skip if rs_policy:delete_date tag exists.  we don't want to update the tag
    sub on_error: skip do
      @resource = rs_cm.get(href: $resource)
      if !tag_value(@resource,'rs_policy:delete_date')
        $cloud_id = split($resource,'/')[3]
        $resource_array=[]
        foreach $item in $clouds[$cloud_id] do
          $resource_array << $item
        end
        $resource_array << $resource
        $clouds[$cloud_id] = $resource_array
      end
    end
  end
  # add rs_policy:delete_date tag to each resource by cloud
  foreach $cloud in keys($clouds) do
    if any?($clouds[$cloud])
      rs_cm.tags.multi_add(resource_hrefs: $clouds[$cloud], tags: [join(["rs_policy:delete_date=",$formated_delete_date])])
    end
  end
end

# remove rs_policy:delete_date tag from valid resources
# this definition should be called last after the $$bad_instances_array
# is  complete
define remove_delete_date_tag() do
  $resources = rs_cm.tags.by_tag(tags: ["rs_policy:delete_date=*"],
    resource_type: 'instances')
  $resources = first(first($resources))["links"]
  foreach $resource in $resources do
    if !contains?(unique(keys($$bad_instances_array)),[$resource['href']])
      	@resource = rs_cm.instances.get(href: $resource['href'])
        rs_cm.tags.multi_delete(resource_hrefs: [@resource.href],
        tags: ["rs_policy:delete_date="+tag_value(@resource,'rs_policy:delete_date')])
    end
  end
end

define sys_log($subject, $detail) do
  rs_cm.audit_entries.create(
    notify: "None",
    audit_entry: {
      auditee_href: @@deployment,
      summary: $subject,
      detail: $detail
    }
  )
end
