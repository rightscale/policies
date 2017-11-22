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
Check for a tag and report which instances are missing it."
long_description "Version: 1.3"

##################
# User inputs    #
##################
parameter "param_tag_key" do
  category "User Inputs"
  label "Tags' Namespace:Keys List"
  type "string"
  description "Comma-separated list of Tags' Namespace:Keys to audit. For example: \"ec2:project_code\" or \"bu:id\""
  min_length 3
  allowed_pattern '^([a-zA-Z0-9-_]+:[a-zA-Z0-9-_]+,*)+$'
end

parameter "param_email" do
  category "Contact"
  label "Email addresses (separate with commas)"
  type "string"
  allowed_pattern '^([a-zA-Z0-9-_.]+[@]+[a-zA-Z0-9-_.]+[.]+[a-zA-Z0-9-_]+,*)+$'
  min_length 6
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
  label "Instances Missing Specified Tag(s)"
  category "Output"
  description "Instances missing the specified tag(s)."
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
define launch_tag_checker($param_tag_key,$param_email,$param_run_once) return $bad_instances do
  #call sys_log.set_task_target(@@deployment)
  #call sys_log.summary("Launch")

  # add deployment tags for the parameters and then tell tag_checker to go
  rs_cm.tags.multi_add(resource_hrefs: [@@deployment.href], tags: [join(["tagchecker:tag_key=",$param_tag_key])])
  rs_cm.tags.multi_add(resource_hrefs: [@@deployment.href], tags: [join(["tagchecker:check_frequency=",$parameter_check_frequency])])
  rs_cm.tags.multi_add(resource_hrefs: [@@deployment.href], tags: [join(["tagchecker:cloud_scope=",$parameter_cloud])])

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
  $check_frequency = 5
  $cloud_scope = ""

  # retrieve tags on current deployment
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

  concurrent return $operational_instances_hrefs, $provisioned_instances_hrefs, $running_instances_hrefs do  
    sub do
      @instances_operational = rs_cm.instances.get(filter: ["state==operational"])
      $operational_instances_hrefs = to_object(@instances_operational)["hrefs"]
    end
    sub do
      @instances_provisioned = rs_cm.instances.get(filter: ["state==provisioned"])
      $provisioned_instances_hrefs = to_object(@instances_provisioned)["hrefs"]
    end
    sub do
      @instances_running = rs_cm.instances.get(filter: ["state==running"])
      $running_instances_hrefs = to_object(@instances_running)["hrefs"]
    end
  end

  $instances_hrefs = $operational_instances_hrefs + $provisioned_instances_hrefs + $running_instances_hrefs

  $$bad_instances_array=[]
  foreach $hrefs in $instances_hrefs do
    $instances_tags = rs_cm.tags.by_resource(resource_hrefs: [$hrefs])
    $tag_info_array = $instances_tags[0]
    # Loop through the tag info array and find any entries which DO NOT reference the tag(s) in question.
    $param_tag_keys_array = split($tag_key, ",")  # make the parameter list an array so I can search stuff
    foreach $tag_info_hash in $tag_info_array do
      # Create an array of the tags' namespace:key parts
      $tag_entry_ns_key_array=[]
      foreach $tag_entry in $tag_info_hash["tags"] do
        $tag_entry_ns_key_array << split($tag_entry["name"],"=")[0]
      end

      # See if the desired keys are in the found tags and if not take note of the improperly tagged instances
      if logic_not(contains?($tag_entry_ns_key_array, $param_tag_keys_array))
        foreach $resource in $tag_info_hash["links"] do
          $$bad_instances_array << $resource["href"]
        end
      end
    end
  end

  $bad_instances = to_s($$bad_instances_array)

  # Send an alert email if there is at least one improperly tagged instance
  if logic_not(empty?($$bad_instances_array))
    call send_tags_alert_email($tag_key,$param_email)
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

  # Build email
  $subject = "Tag Checker Policy: "
  $from = "policy-cat@services.rightscale.com"
  $email_msg = "RightScale discovered that the following instance are missing tags <b>" + $tags + "</b> in <b>"+ $account_name +".</b> Per the policy set by your organization, these instances are not compliant"

  $table_start="<td align=%22left%22 valign=%22top%22>"
  $table_end="</td>"
  $header="
    \<\!DOCTYPE html PUBLIC \"-\/\/W3C\/\/DTD XHTML 1.0 Transitional\/\/EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\"\>
    <html xmlns=\"http:\/\/www.w3.org\/1999\/xhtml\">
    <head>
      <meta http-equiv=%22Content-Type%22 content=%22text/html; charset=UTF-8%22 />
      <a href=%22//www.rightscale.com%22>
      <img src=%22https://assets.rightscale.com/6d1cee0ec0ca7140cd8701ef7e7dceb18a91ba20/web/images/logo.png%22 alt=%22RightScale Logo%22 width=%22200px%22 /></a>
    <style></style>
    </head>
    <body>
      <table border=%220%22 cellpadding=%220%22 cellspacing=%220%22 height=%22100%%22 width=%22100%%22 id=%22bodyTable%22>
        <tr>
          <td align=%22left%22 valign=%22top%22>
            <table border=%220%22 cellpadding=%2220%22 cellspacing=%220%22 width=%22100%%22 id=%22emailContainer%22>
              <tr>
                <td align=%22left%22 valign=%22top%22>
                  <table border=%220%22 cellpadding=%2220%22 cellspacing=%220%22 width=%22100%%22 id=%22emailHeader%22>
                    <tr>
                      <td align=%22left%22 valign=%22top%22>
                        " + $email_msg + "
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
            <tr>
              <td align=%22left%22 valign=%22top%22>
                <table border=%220%22 cellpadding=%2210%22 cellspacing=%220%22 width=%22100%%22 id=%22emailBody%22>
                  <tr>
                    <td align=%22left%22 valign=%22top%22>
                      Instance Name
                    </td>
                    <td align=%22left%22 valign=%22top%22>
                      State
                    </td>
                    <td align=%22left%22 valign=%22top%22>
                      Link
                    </td>
                  </tr>"
  $footer="
                    </tr>
                  </table>
                </td>
              </tr>
              <tr>
                <td align=%22left%22 valign=%22top%22>
                  <table border=%220%22 cellpadding=%2220%22 cellspacing=%220%22 width=%22100%%22 id=%22emailFooter%22>
                    <tr>
                      <td align=%22left%22 valign=%22top%22>
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

  $$list_of_instances=""
  foreach $instance in $$bad_instances_array do
    $$instance_error = 'false'
    @server = rs_cm.servers.empty()

    sub on_error: set_instance_error() do
      @server = rs_cm.get(href: $instance)
    end

    $server_object = to_object(@server)

    if $$instance_error == 'true'
      #issue with the instance, may no longer exists
    else
      # Get instance name
      if $server_object["details"][0]["state"] == 'provisioned'
        $instance_name = $server_object["details"][0]["resource_uid"]
      else
        $instance_name = $server_object["details"][0]["name"]
      end
      if $instance_name == null
        $instance_name = 'unknown'
      end

      # Get server state
      if $server_object["details"][0]["state"] == null
        $instance_state = 'unknown'
      else
        $instance_state = $server_object["details"][0]["state"]
      end

      # Get server access link
      $server_access_link_root = 'unknown'
      sub on_error: skip do
        call get_server_access_link($instance) retrieve $server_access_link_root
      end
      if $server_access_link_root == null
        $server_access_link_root = 'unknown'
      end

      # Create the instance table
      $instance_table = "<tr>" + $table_start + $instance_name + $table_end + $table_start + $instance_state + $table_end + $table_start + $server_access_link_root + $table_end + "</tr>"
      insert($$list_of_instances, -1, $instance_table)
    end
  end

  $email_body = $header + $$list_of_instances + $footer

  call send_html_email($to, $from, $subject, $email_body) retrieve $response

  if $response['code'] != 200
    raise 'Failed to send email report: ' + to_s($response)
  end
end

define send_html_email($to, $from, $subject, $html) return $response do
  $mailgun_endpoint = 'http://smtp.services.rightscale.com/v3/services.rightscale.com/messages'

  $to = gsub($to, "@", "%40")
  $from = gsub($from, "@", "%40")

  # escape ampersands used in html encoding
  $html = gsub($html, "&", "%26")

  $post_body = 'from=' + $from + '&to=' + $to + '&subject=' + $subject + '&html=' + $html

  $response = http_post(
    url: $mailgun_endpoint,
    headers: {"content-type": "application/x-www-form-urlencoded"},
    body: $post_body
  )
end

define set_instance_error() do
  $$instance_error = 'true'
  $_error_behavior = "skip"
end

# Returns the RightScale account number in which the CAT was launched.
define find_account_number() return $account_id do
  $session = rs_cm.sessions.index(view: "whoami")
  $account_id = last(split(select($session[0]["links"], {"rel":"account"})[0]["href"],"/"))
end

define get_server_access_link($instance_href) return $server_access_link_root do
  $rs_endpoint = "https://us-"+$$shard+".rightscale.com"

  $instance_id = last(split($instance_href, "/"))
  $response = http_get(
    url: $rs_endpoint+"/api/instances?ids="+$instance_id,
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
  $server_access_link_root = "https://my.rightscale.com/acct/" + $$account_number + "/clouds/" + $cloud_id + "/instances/" + $legacy_id
end
