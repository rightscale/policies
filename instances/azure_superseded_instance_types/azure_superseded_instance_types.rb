name 'Policy - Azure Resize Superseded Instance Types'
rs_ca_ver 20161221
short_description "![RS Policy](https://goo.gl/RAcMcU =64x64)\n
Policy - Azure Resize Superseded Instance Types"
long_description "Version: 1.0"
import "sys_log"
import "mailer"
import "plugins/rs_azure_compute"

parameter "subscription_id" do
  category "User Inputs"
  like $rs_azure_compute.subscription_id
end

parameter "instance_type_mapping" do
  category "User Inputs"
  label "Instance Type Mapping"
  type "string"
  description "A JSON string or publc HTTP URL to json file. Format: {\"Disallowed\": \"Replacement\"} .  Example: {\"Standard_D3\": \"Standard_D3_v2\", \"Standard_D2\": \"Standard_D2_v2\"} "
  #allow http, {*} or nothing.
  allowed_pattern '^(http|\{.*\}|)'
end

parameter "schedule_tag_namespace" do
  category "User Inputs"
  label "Schedule Tag Namespace"
  type "string"
  description "Namespace of Azure-native instance tag that will identify the start of the maintenance window to perform the automated resize action. If unset, this policy will not take automated remediation actions."
  default "resize_schedule"
end

parameter "exclusion_tag" do
  category "User Inputs"
  label "Exclusion Tag"
  description "Azure-native instance tag key:value to override instances that match a disallowed instance type. Example: {\"exclude_resize\": \"true\"} "
  type "string"
  default "{\"exclude_resize\": \"true\"}"
end

parameter "param_email" do
  category "Contact"
  label "Email addresses (separate with commas)"
  type "string"
  # allow list of comma seperated email addresses or nothing
  allowed_pattern '^([a-zA-Z0-9-_.]+[@]+[a-zA-Z0-9-_.]+[.]+[a-zA-Z0-9-_]+,*|)+$'
end

parameter "vmname" do
  label "VM Name"
  type "string"
end

parameter "resource_group" do
  label "Resource Group"
  type "string"
end

parameter "new_size" do
  label "New Instance Type"
  type "string"
end

operation "launch" do
  definition "launch"
end

operation "resize_vm" do
  definition "resize_vm"
end

operation "check_instances" do
  definition "check_instances"
end

operation "clear_scheduled_actions" do
  definition "clear_scheduled_actions"
end

define launch($instance_type_mapping, $schedule_tag_namespace, $exclusion_tag, $param_email) do
  # First Scan 10min from now
  $time = now() + 60*10
  $configuration_options = [
    {
      "name": "instance_type_mapping",
      "type": "string",
      "value": $instance_type_mapping
    },
    {
      "name": "exclusion_tag",
      "type": "string",
      "value": $exclusion_tag
    },
    {
      "name": "schedule_tag_namespace",
      "type": "string",
      "value": $schedule_tag_namespace
    },
    {
      "name": "param_email",
      "type": "string",
      "value": $param_email
    }
  ]
  call create_recurring_sa("Scan Instances", "check_instances", $configuration_options, "UTC", $time, "FREQ=DAILY") retrieve @scheduled_action

end

define check_instances($instance_type_mapping, $exclusion_tag, $schedule_tag_namespace, $param_email) return $target_instances do
  # Define disallowed types
  $disallowed_types = keys(from_json($instance_type_mapping))
  $exclusion_tag_key = keys(from_json($exclusion_tag))
  $exclusion_tag_value = values(from_json($exclusion_tag))
  call sys_log.summary("Superseded Instance Types Scan - " + strftime(now(), "%Y/%m/%d %H:%M"))
  call sys_log.detail("Disallowed Types: " + to_s($disallowed_types))
  call sys_log.detail("Exclusion Key: " + to_s($exclusion_tag_key))
  call sys_log.detail("Exclusion Value: " + to_s($exclusion_tag_value))

  # List all instances in subscription
  $all_instances = []
  $instances = rs_azure_compute.virtualmachine.list_all()
  foreach $instance in $instances[0]["value"] do
    $all_instances << $instance
  end
  call sys_log.detail("First Pass Instances: " + to_s($all_instances))

  # While nextLink exists, execute nextLink GET
  if $instances[0]["nextLink"] != null
    $continue_search = 1
  else
    $continue_search = 0
  end

  while $continue_search == 1 do
    $url = $instances[0]["nextLink"]
    call get_access_token() retrieve $access_token
    $response = http_get(
      url: $url,
      headers : {
        "cache-control":"no-cache",
        "content-type":"application/json",
        "authorization": "Bearer " + $access_token
      }
    )

    $instances = $response["body"]
    foreach $instance in $instances["value"] do
      $all_instances << $instance
    end
    call sys_log.detail("Next Pass Instances: " + to_s($all_instances))

    if $instances["nextLink"] != null
      $continue_search = 1
    else
      $continue_search = 0
    end

  end

  call sys_log.detail("All Instances: " + to_s($all_instances))

  # Check vmSize on each instance against the disallowed instance types list
  $target_instances = []
  foreach $instance in $all_instances do
    call sys_log.detail("Instance Type Analysis")
    call sys_log.detail("Instance: " + to_s($instance))
    if any?($disallowed_types, $instance["properties"]["hardwareProfile"]["vmSize"])
      call sys_log.detail($instance["name"] + " has a disallowed Instance Type!")
      # Exclude instances
      if $instance["tags"] != null
        if any?($exclusion_tag_value, $instance["tags"][$exclusion_tag_key[0]])
          # Do nothing
          call sys_log.detail($instance["name"] + " has the exclusion tag.  Skipping..")
        else
          $target_instances << $instance
          call sys_log.detail($instance["name"] + " does NOT have the exclusion tag.  Adding to targets..")
        end
      else
        # No tags on instance
        $target_instances << $instance
        call sys_log.detail($instance["name"] + " does NOT have the exclusion tag.  Adding to targets..")
      end
    end
  end

  $mailer_endpoint = "http://policies.services.rightscale.com"
  $columns = ["VM Name","Region","Instance Type","Resource UID","Resize Status"]
  call mailer.create_csv_with_columns($mailer_endpoint,$columns) retrieve $filename
  $table_start="<td align=%22left%22 valign=%22top%22>"
  $table_end="</td>"
  $list_of_instances=""

  # Check for Schedule tag
  foreach $instance in $target_instances do
    if $instance["tags"] != null
      if $instance["tags"][$schedule_tag_namespace] != null
        # Validate Schedule tag value
        if $instance["tags"][$schedule_tag_namespace] =~ /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/

          call sys_log.detail($instance["name"] + " has a valid schedule tag")
          # Call schedule_resize()
          call schedule_resize($instance, $instance_type_mapping, $schedule_tag_namespace) retrieve @scheduled_action
          if size(@scheduled_action) == 1
            $scheduled = "scheduled"
            call sys_log.detail($instance["name"] + " scheduled for resize")
          else
            $scheduled = "failed to schedule"
            call sys_log.detail($instance["name"] + " FAILED to schedule for resize")
          end

          call mailer.update_csv_with_rows($mailer_endpoint, $filename, [$instance["name"],$instance["location"],$instance["properties"]["hardwareProfile"]["vmSize"],$instance["id"],$scheduled]) retrieve $filename

          $instance_table = "<tr>" + $table_start + $instance["name"] + $table_end + $table_start + $instance["location"] + $table_end + $table_start + $instance["properties"]["hardwareProfile"]["vmSize"] + $table_end + $table_start + $instance["id"] + $table_end + $table_start + $scheduled + $table_end + "</tr>"
          insert($list_of_instances, -1, $instance_table)

        else
          # Invalid Schedule Tag
          $scheduled = "invalid schedule tag"
          call sys_log.detail($instance["name"] + " has an INVALID schedule tag")

          call mailer.update_csv_with_rows($mailer_endpoint, $filename, [$instance["name"],$instance["location"],$instance["properties"]["hardwareProfile"]["vmSize"],$instance["id"],$scheduled]) retrieve $filename

          $instance_table = "<tr>" + $table_start + $instance["name"] + $table_end + $table_start + $instance["location"] + $table_end + $table_start + $instance["properties"]["hardwareProfile"]["vmSize"] + $table_end + $table_start + $instance["id"] + $table_end + $table_start + $scheduled + $table_end + "</tr>"
          insert($list_of_instances, -1, $instance_table)

        end
      else
        # No Schedule Tag
        $scheduled = "no schedule tag set"

        call sys_log.detail($instance["name"] + " does NOT have a schedule tag")

        call mailer.update_csv_with_rows($mailer_endpoint, $filename, [$instance["name"],$instance["location"],$instance["properties"]["hardwareProfile"]["vmSize"],$instance["id"],$scheduled]) retrieve $filename

        $instance_table = "<tr>" + $table_start + $instance["name"] + $table_end + $table_start + $instance["location"] + $table_end + $table_start + $instance["properties"]["hardwareProfile"]["vmSize"] + $table_end + $table_start + $instance["id"] + $table_end + $table_start + $scheduled + $table_end + "</tr>"
          insert($list_of_instances, -1, $instance_table)

      end
    else
      # No instance tags

      $scheduled = "no schedule tag set"

      call sys_log.detail($instance["name"] + " does NOT have a schedule tag")

      call mailer.update_csv_with_rows($mailer_endpoint, $filename, [$instance["name"],$instance["location"],$instance["properties"]["hardwareProfile"]["vmSize"],$instance["id"],$scheduled]) retrieve $filename

      $instance_table = "<tr>" + $table_start + $instance["name"] + $table_end + $table_start + $instance["location"] + $table_end + $table_start + $instance["properties"]["hardwareProfile"]["vmSize"] + $table_end + $table_start + $instance["id"] + $table_end + $table_start + $scheduled + $table_end + "</tr>"
      insert($list_of_instances, -1, $instance_table)
    end
  end

  if $list_of_instances != ""
    $user_email = tag_value(@@deployment, 'selfservice:launched_by')
    $param_email = $user_email +','+$param_email
    $from = "policy-cat@services.rightscale.com"
    $subject = "Azure Superseded Instance Types Policy "
    call find_account_name() retrieve $account_name

    $email_msg = "RightScale discovered that the following instances are using disallowed instance types in <b>"+ $account_name +".</b> Per the policy set by your organization, these resources are not compliant.  View the attached CSV file for more details."

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
                        <b>VM Name</b>
                      </td>
                      <td align=\"left\" valign=\"top\">
                        <b>Region</b>
                      </td>
                      <td align=\"left\" valign=\"top\">
                        <b>Instance Type</b>
                      </td>
                      <td align=\"left\" valign=\"top\">
                        <b>Resource UID</b>
                      </td>
                      <td align=\"left\" valign=\"top\">
                        <b>Resize Status</b>
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

    $email_body = $header + $list_of_instances + $footer

    # Send email report
    call mailer.send_html_email($mailer_endpoint, $param_email, $from, $subject, $email_body, $filename, "html") retrieve $response

    if $response['code'] != 200
      raise 'Failed to send email report: ' + to_s($response)
    end
  end
end

define schedule_resize($instance, $instance_type_mapping, $schedule_tag_namespace) return @scheduled_action do
  @scheduled_actions = rs_ss.scheduled_actions.get(filter: ["execution_id=="+@@execution.id])
  if any?(@scheduled_actions.name[], $instance["name"])
    # Do nothing
    @scheduled_action = select(@scheduled_actions, {"name": $instance["name"]} )
  else
    $name = $instance["name"]
    $current_size = $instance["properties"]["hardwareProfile"]["vmSize"]
    $new_size = from_json($instance_type_mapping)[$current_size]
    $uid = $instance["id"]
    $resource_group = split($uid, "/")[4]
    $timezone = "UTC"
    $datetime = to_d($instance["tags"][$schedule_tag_namespace])
    call create_resize_sa($name, $timezone, $datetime, $new_size, $resource_group) retrieve @scheduled_action
  end
end

define create_resize_sa($name, $timezone, $datetime, $new_size, $resource_group ) return @scheduled_action do
  @scheduled_action = rs_ss.scheduled_actions.create(
    execution_id:     @@execution.id,
    name:             $name,
    action:           "run",
    operation:        {
                        "name": "resize_vm",
                        "configuration_options": [
                          {
                            "name": "vmname",
                            "type": "string",
                            "value": $name
                          },
                          {
                            "name": "resource_group",
                            "type": "string",
                            "value": $resource_group
                          },
                          {
                            "name": "new_size",
                            "type": "string",
                            "value": $new_size
                          }
                        ]
                      },
    timezone:         $timezone,
    first_occurrence: $datetime
  )
end

define create_recurring_sa($name, $operation_name, $configuration_options, $timezone, $datetime, $recurrence) return @scheduled_action do
  @scheduled_action = rs_ss.scheduled_actions.create(
    execution_id:     @@execution.id,
    name:             $name,
    action:           "run",
    operation:        {
                        "name": $operation_name,
                        "configuration_options": $configuration_options
                      },
    recurrence:       $recurrence,
    timezone:         $timezone,
    first_occurrence: $datetime
  )
end

define resize_vm($vmname, $resource_group, $new_size) do
  call sys_log.summary("Resize VM: " + $vmname )
  @instance = rs_azure_compute.virtualmachine.show(resource_group: $resource_group, virtualMachineName: $vmname)

  $status = @instance.instance_view()
  foreach $state in $status[0]["statuses"] do
    if $state["code"] =~ "PowerState"
      $powerstate = $state["displayStatus"]
    end
  end

  if $powerstate == "VM running"
    call sys_log.detail("Stopping VM..")
    @instance.stop()
  end

  while $powerstate != "VM deallocated" do
    sleep(30)
    $status = @instance.instance_view()
    foreach $state in $status[0]["statuses"] do
      if $state["code"] =~ "PowerState"
        $powerstate = $state["displayStatus"]
      end
    end
  end

  call sys_log.detail("VM deallocated")

  $instance_object = to_object(@instance)
  $new_object = $instance_object["details"][0]
  $new_object["properties"]["hardwareProfile"]["vmSize"] = $new_size
  call sys_log.detail("Updating Instance Type to: " + $new_size)
  @instance.update($new_object)

  sleep(60)
  call sys_log.detail("Starting VM..")
  @instance.start()

end

define clear_scheduled_actions() do
  @scheduled_actions = rs_ss.scheduled_actions.get(filter: ["execution_id=="+@@execution.id])
  concurrent foreach @sa in @scheduled_actions do
    @sa.delete()
  end
end

define find_account_name() return $account_name do
  $session_info = rs_cm.sessions.get(view: "whoami")
  $acct_link = select($session_info[0]["links"], {rel: "account"})
  $acct_href = $acct_link[0]["href"]
  $account_name = rs_cm.get(href: $acct_href).name
end

define get_access_token() return $access_token do

  $tenant_id = cred("AZURE_TENANT_ID")
  $application_id = cred("AZURE_APPLICATION_ID")
  call url_encode(cred("AZURE_APPLICATION_KEY")) retrieve $secret

  $body_string = "grant_type=client_credentials&resource=https://management.core.windows.net/&client_id="+$application_id+"&client_secret="+$secret

  $auth_response = http_post(
    url: "https://login.microsoftonline.com/" + $tenant_id + "/oauth2/token?api-version=1.0",
    headers : {
      "cache-control":"no-cache",
      "content-type":"application/x-www-form-urlencoded"
     # "Content-Type":"application/json"

    },
    body:$body_string
  )

  $auth_response_body = $auth_response["body"]
  $access_token = $auth_response_body["access_token"]

end

define url_encode($string) return $encoded_string do
  $encoded_string = $string
  $encoded_string = gsub($encoded_string, " ", "%20")
  $encoded_string = gsub($encoded_string, "!", "%21")
  $encoded_string = gsub($encoded_string, "#", "%23")
  $encoded_string = gsub($encoded_string, "$", "%24")
  $encoded_string = gsub($encoded_string, "&", "%26")
  $encoded_string = gsub($encoded_string, "'", "%27")
  $encoded_string = gsub($encoded_string, "(", "%28")
  $encoded_string = gsub($encoded_string, ")", "%29")
  $encoded_string = gsub($encoded_string, "*", "%2A")
  $encoded_string = gsub($encoded_string, "+", "%2B")
  $encoded_string = gsub($encoded_string, ",", "%2C")
  $encoded_string = gsub($encoded_string, "/", "%2F")
  $encoded_string = gsub($encoded_string, ":", "%3A")
  $encoded_string = gsub($encoded_string, ";", "%3B")
  $encoded_string = gsub($encoded_string, "=", "%3D")
  $encoded_string = gsub($encoded_string, "?", "%3F")
  $encoded_string = gsub($encoded_string, "@", "%40")
  $encoded_string = gsub($encoded_string, "[", "%5B")
  $encoded_string = gsub($encoded_string, "]", "%5D")
end