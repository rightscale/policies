name 'Instance Runtime Policy'
rs_ca_ver 20160622
short_description "![RS Policy](https://goo.gl/RAcMcU =64x64)\n
This automated policy CAT will find instances that have been running longer than a specified time, send alerts, and optionally delete them."
long_description "Version: 1.1"
import "mailer"
import "sys_log"

#Copyright 2017, 2018 RightScale
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
# Finds long running instances and reports on them
#


##################
# User inputs    #
##################

parameter "param_days_old" do
  category "Instance"
  label "Include instances with minimum days running of"
  type "number"
end

parameter "param_action" do
  category "Instance"
  label "Instance Action"
  type "string"
  allowed_values "Alert Only","Alert and Terminate"
  default "Alert Only"
end

parameter "param_email" do
  category "Contact"
  label "Email addresses (separate with commas)"
  type "string"
end

parameter "param_run_once" do
  category "Run Once"
  label "If set to true the cloud app will terminate itself after completion.  Do not use for scheduling."
  type "string"
  default "false"
  allowed_values "true","false"
end

operation "launch" do
  description "Find long running instances"
  definition "launch"
end


##################
# Definitions    #
##################

define launch($param_email,$param_action,$param_days_old,$param_run_once) return $param_email,$param_action,$param_days_old,$param_run_once do
        call find_long_running_instances($param_days_old) retrieve $send_email
        sleep(20)
#        if $send_email == "true"
#          call send_email_mailgun($param_email)
	if $param_run_once == "true"

          $time = now() + 30
          rs_ss.scheduled_actions.create(
           execution_id: @@execution.id,
           action: "terminate",
           first_occurrence: $time
         )
        end

end

define find_long_running_instances($param_days_old) return $send_email do
  #`pending`, `booting`, `operational`, `stranded`, `stranded in booting`, `running`
  @all_instances = rs_cm.instances.index(filter:["state==operational"])
  @all_instances = @all_instances + rs_cm.instances.index(filter:["state==booting"])
  @all_instances = @all_instances + rs_cm.instances.index(filter:["state==pending"])
  @all_instances = @all_instances + rs_cm.instances.index(filter:["state==stranded"])
  @all_instances = @all_instances + rs_cm.instances.index(filter:["state==running"])

  #todo - add drop down to select if stopped instances should be included.
  @all_instances = @all_instances + rs_cm.instances.index(filter:["state==provisioned"])
  $list_of_instances=""
  $table_start="<td align='left' valign='top'>"
  $table_end="</td>"
  call find_account_name() retrieve $account_name

  $endpoint = "http://policies.services.rightscale.com"
  $from = "policy-cat@services.rightscale.com"
  $subject = "["+ to_s(gsub($account_name, "&","-")) +"] Long Running Instances Report for > " + $param_days_old + " Day(s)"
  $to = $param_email
  $columns = ["Instance Name","Type","State","Cloud","Days Old","Link"]
  call mailer.create_csv_with_columns($endpoint,$columns) retrieve $filename

  #/60/60/24
  $curr_time = now()
  call find_shard() retrieve $shard_number
  call find_account_number() retrieve $account_id

  #counter to included total number of instances found that trigger the policy
  $number_of_instance_found=0

  foreach @instance in @all_instances do
    $instance_name = ""
    $instance_type = ""
    $instance_state = ""
    $cloud_name = ""
    $display_days_old = ""
    $server_access_link_root = ""

    # do another get request to make sure the instance is still available
    $resource = to_object(@instance)  
    @resource = rs_cm.servers.empty()

    sub on_error: skip do
      @instance = rs_cm.get(href: $resource['href'])
    end

    #convert string to datetime to compare datetime
    $instance_created_at = to_d(@instance.created_at)

    #the difference between dates
    $difference = $curr_time - $instance_created_at

    #convert the difference to days
    $how_old = $difference /60/60/24

    if $param_days_old < $how_old
      $number_of_instance_found=$number_of_instance_found + 1
      $send_email = "true"

      sub task_label: "retrieving access link", on_error: error_server_link() do
        call get_server_access_link(@instance.href, $shard_number, $account_id) retrieve $server_access_link_root
      end

      sub task_label: "retrieving instance name", on_error: error_instance_name() do
        if @instance.state == 'provisioned'
         $instance_name = @instance.resource_uid
        else
         $instance_name = @instance.name
        end
      end
      #if we're unable to get the instance type, it will be listed as unknown in the email report.
      sub task_label: "retrieving instance type", on_error: error_instance_type() do
        $instance_type = @instance.instance_type().name
      end

      sub task_label: "retrieving instance state", on_error: error_instance_state() do
      $instance_state = @instance.state
      end

      sub task_label: "retrieving cloud name for the instance", on_error: error_cloud_name() do
      $cloud_name = @instance.cloud().name
      end

      sub task_label: "retrieving display days old", on_error: error_display_days() do
      $display_days_old = first(split(to_s($how_old),"."))
      end

      #here we decide if we should delete the volume
      if $param_action == "Alert and Terminate"
        sub task_name: "Terminate instance" do
          task_label("Terminate instance")
          sub on_error: handle_error() do
            @instance.terminate()
          end
        end
      end

      $instance_table = "<tr>" + $table_start + to_s($instance_name) + $table_end + $table_start + to_s($instance_type) + $table_end + $table_start + to_s($instance_state) + $table_end + $table_start + to_s($cloud_name) + $table_end + $table_start + to_s($display_days_old) + $table_end + $table_start + to_s($server_access_link_root) + $table_end + "</tr>"
      insert($list_of_instances, -1, $instance_table)

	  call mailer.update_csv_with_rows($endpoint,$filename,[to_s($instance_name), to_s($instance_type),to_s($instance_state), to_s($cloud_name),to_s($display_days_old),to_s($server_access_link_root)]) retrieve $filename
    end
  end

  #form email
  call find_account_name() retrieve $account_name
  if $param_action == "Alert and Terminate"
    $email_msg = "RightScale discovered <b>" + $number_of_instance_found + "</b> instances in <b>"+ to_s(gsub($account_name, "&","-")) +".</b> Per the policy set by your organization, these instances have been terminated and are no longer accessible"
  else
    $email_msg = "RightScale discovered <b>" + $number_of_instance_found + "</b> instances in <b>"+ to_s(gsub($account_name, "&","-")) +"</b> that exceed your instance runtime policy of " + $param_days_old +" days."
  end
  call sys_log.detail("rs_email_msg:" + $email_msg)

  $header='\<\!DOCTYPE html PUBLIC \"-\/\/W3C\/\/DTD XHTML 1.0 Transitional\/\/EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\"\>
    <html xmlns=\"http:\/\/www.w3.org\/1999\/xhtml\">
        <head>
            <meta http-equiv="Content-Type" content=:text/html; charset=UTF-8" />
            <a href="//www.rightscale.com">
<img src="https://assets.rightscale.com/6d1cee0ec0ca7140cd8701ef7e7dceb18a91ba20/web/images/logo.png" alt="RightScale Logo" width=%22200px" />
</a>
            <style></style>
        </head>
        <body>
          <table border="0" cellpadding="0" cellspacing=%220" height="100%" width="100%" id="bodyTable">
              <tr>
                  <td align="left" valign="top">
                      <table border="0" cellpadding="20" cellspacing="0" width="100%" id="emailContainer">
                          <tr>
                              <td align="left" valign="top">
                                  <table border="0"cellpadding="20" cellspacing="0" width="100%" id="emailHeader">
                                      <tr>
                                          <td align="left" valign="top">
                                             ' + $email_msg + '
                                          </td>

                                      </tr>
                                  </table>
                              </td>
                          </tr>
                          <tr>
                              <td align="left" valign="top">
                                  <table border="0" cellpadding="10" cellspacing="0" width="100%" id="emailBody">
                                      <tr>
                                          <td align="left" valign="top">
                                              Instance Name
                                          </td>
                                          <td align="left" valign="top">
                                              Type
                                          </td>
                                          <td align="left" valign="top">
                                              State
                                          </td>
                                          <td align"left" valign="top">
                                              Cloud
                                          </td>
                                          <td align="left" valign="top">
                                              Days Old
                                          </td>
                                          <td align="left" valign="top">
                                              Link
                                          </td>
                                      </tr>
                                      '



  $footer='</tr></table></td></tr><tr><td align="left" valign="top"><table border="0" cellpadding="20" cellspacing="0" width="100%" id="emailFooter"><tr><td align="left" valign="top">
          This report was automatically generated by a policy template Instance Runtime Policy your organization has defined in RightScale.
      </td></tr></table></td></tr></table></td></tr></table></body></html>'

  $email_body = $header + $list_of_instances + $footer
  call mailer.send_html_email($endpoint, $to, $from, $subject, $email_body, $filename, "html") retrieve $response
end

define handle_error() do
  #error_msg has the response from the api , use that as the error in the email.
  #$$error_msg = $_error["message"]
  $$error_msg = " failed to terminate"
  $_error_behavior = "skip"
end

define get_server_access_link($instance_href, $shard, $account_number) return $server_access_link_root do
  $rs_endpoint = "https://us-"+$shard+".rightscale.com"
  $instance_id = last(split($instance_href, "/"))
  $response = http_get(
    url: $rs_endpoint+"/api/instances?ids="+$instance_id,
    headers: {
    "X-Api-Version": "1.6",
    "X-Account": $account_number
    }
   )

   $instances = $response["body"]
   $instance_of_interest = select($instances, { "href" : $instance_href })[0]
   $legacy_id = $instance_of_interest["legacy_id"]
   $data = split($instance_href, "/")
   $cloud_id = $data[3]
   $server_access_link_root = "https://my.rightscale.com/acct/" + $account_number + "/clouds/" + $cloud_id + "/instances/" + $legacy_id
 end

define error_server_link() return $server_access_link_root do
  $server_access_link_root = "unknown"
   $_error_behavior = "skip"
end

define error_cloud_name() return $cloud_name do
  $cloud_name = "unknown"
  $_error_behavior = "skip"
end

define error_display_days() return $display_days_old do
  $display_days_old = "unknown"
  $_error_behavior = "skip"
end

define error_instance_type() return $instance_type do
  $instance_type = "unknown"
  $_error_behavior = "skip"
end

define error_instance_name()  return $instance_name do
  $instance_name = "unknown"
  $_error_behavior = "skip"
end

define error_instance_state() return $instance_state do
  $instance_state = "unknown"
  $_error_behavior = "skip"
end

# Returns the RightScale account number in which the CAT was launched.
define find_account_number() return $account_id do
  $session = rs_cm.sessions.index(view: "whoami")
  $account_id = last(split(select($session[0]["links"], {"rel":"account"})[0]["href"],"/"))
end

# Returns the RightScale shard for the account the given CAT is launched in.
define find_shard() return $shard_number do
  call find_account_number() retrieve $account_number
  $account = rs_cm.get(href: "/api/accounts/" + $account_number)
  $shard_number = last(split(select($account[0]["links"], {"rel":"cluster"})[0]["href"],"/"))
end

define find_account_name() return $account_name do
  $session_info = rs_cm.sessions.get(view: "whoami")
  $acct_link = select($session_info[0]["links"], {rel: "account"})
  $acct_href = $acct_link[0]["href"]
  $account_name = rs_cm.get(href: $acct_href).name
end

define start_debugging() do
  if $$debugging == false || logic_and($$debugging != false, $$debugging != true)
    initiate_debug_report()
    $$debugging = true
  end
end

define stop_debugging() do
  if $$debugging == true
    $debug_report = complete_debug_report()
    call sys_log.detail($debug_report)
    $$debugging = false
  end
end
