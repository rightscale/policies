name 'Unattached Volume Policy with csv file attachment'
rs_ca_ver 20160622
short_description "![RS Policy](https://goo.gl/RAcMcU =64x64)\n
This automated policy CAT will find unattached volumes, send alerts, and optionally delete them."
long_description "Version: 1.2"
import "mailer"
import "sys_log"

#Copyright 2017-2018 RightScale
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
# Find unattached volumes and takes an action (alert, alert + delete)
#
# FEATURES
# Users can automatically have unattached volumes deleted.
# 02/26/2018
# Added CSV file export with email
#03/02/2018
# adding auto terminate once completed.




##################
# User inputs    #
##################
parameter "param_action" do
  category "Volume"
  label "Volume Action"
  type "string"
  allowed_values "Alert Only", "Alert and Delete"
  default "Alert Only"
end

parameter "param_email" do
  category "Contact"
  label "Email addresses (separate with commas)"
  type "string"
end

parameter "param_days_old" do
  category "Unattached Volumes"
  label "Include volumes with minimum days unattached of"
  type "number"
  default "30"
end

parameter "param_run_once" do
  category "Run Once"
  label "If set to true the cloud app will terminate itself after completion.  Do NOT use for scheduling this job."
  type "string"
  default "false"
  allowed_values "true","false"
end

##################
# Operations     #
##################

operation "launch" do
  description "Find unattached volumes"
  definition "launch"
end


##################
# Definitions    #
##################

define launch($param_email,$param_action,$param_days_old,$param_run_once) return $param_email,$param_action,$param_days_old do
        call find_unattached_volumes($param_action,$param_email) retrieve $send_email
        sleep(20)
        
		if $param_run_once == "true"
          $time = now() + 30
          rs_ss.scheduled_actions.create(
           execution_id: @@execution.id,
           action: "terminate",
           first_occurrence: $time
         )
        end
end


define find_unattached_volumes($param_action,$param_email) return $send_email do

    #get all volumes
    @all_volumes = rs_cm.volumes.index(view: "default")

    #search the collection for only volumes with status = available
    @volumes_not_in_use = select(@all_volumes, { "status": "available" })

    #get account id to include in the email.
    call find_account_name() retrieve $account_name
    $endpoint = "http://policies.services.rightscale.com"
    $from = "policy-cat@services.rightscale.com"
    $subject = $account_name + " - Unattached Volumes Report - Unattached for Over " + $param_days_old + " Day(s)"
    $to = $param_email
    $columns = ["Volume Name","Volume Size (GB)","Days Old","Volume Href","Cloud","Volume ID"]
    call mailer.create_csv_with_columns($endpoint,$columns) retrieve $filename
    if $param_action == "Alert and Delete"
      $email_msg = "RightScale discovered the following unattached volumes in "+ $account_name +". Per the policy set by your organization, these volumes have been deleted and are no longer accessible"
    else
      $email_msg = "RightScale discovered the following unattached volumes in "+ $account_name +". These volumes are incurring cloud charges and should be deleted if they are no longer being used."
    end


    $header='\<\!DOCTYPE html PUBLIC \"-\/\/W3C\/\/DTD XHTML 1.0 Transitional\/\/EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\"\>
    <html xmlns=\"http:\/\/www.w3.org\/1999\/xhtml\">
        <head>
            <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
            <a href="//www.rightscale.com">
<img src="https://assets.rightscale.com/6d1cee0ec0ca7140cd8701ef7e7dceb18a91ba20/web/images/logo.png" alt="RightScale Logo" width="200px" />
</a>
            <style></style>
        </head>
        <body>
          <table border="0" cellpadding="0" cellspacing="0" height="100%" width="100%" id="bodyTable">
              <tr>
                  <td align="left" valign="top">
                      <table border="0" cellpadding="20" cellspacing="0" width="100%" id="emailContainer">
                          <tr>
                              <td align="left" valign="top">
                                  <table border="0" cellpadding="20" cellspacing="0" width="100%" id="emailHeader">
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
                                              Volume Name
                                          </td>
                                          <td align="left" valign="top">
                                              Volume Size (GB)
                                          </td>
                                          <td align="left" valign="top">
                                              Days Old
                                          </td>
                                          <td align="left" valign="top">
                                              Volume Href
                                          </td>
                                          <td align="left" valign="top">
                                              Cloud
                                          </td>
                                          <td align="left" valign="top">
                                              Volume ID
                                          </td>
                                      </tr>
                                      '
      $list_of_volumes=""
      $table_start='<td align="left" valign="top">'
      $table_end="</td>"

      #/60/60/24
      $curr_time = now()
      #$$day_old = now() - (60*60*24)

      foreach @volume in @volumes_not_in_use do
        $$error_msg=""
        #convert string to datetime to compare datetime
        $volume_created_at = to_d(@volume.updated_at)

        #the difference between dates
        $difference = $curr_time - $volume_created_at

        #convert the difference to days
        $how_old = $difference /60/60/24


        #check for Azure specific images that report as "available" but should not
        #be reported on or deleted.
        if @volume.resource_uid =~ "@system@Microsoft.Compute/Images/vhds"
          #do nothing.

        #check the age of the volume
        elsif $param_days_old < $how_old
          $send_email = 'true'
          $volume_name = @volume.name
          $volume_size = @volume.size
          $volume_href = @volume.href
          $display_days_old = first(split(to_s($how_old),"."))
          #get cloud name
          $cloud_name = @volume.cloud().name

          $volume_id  = @volume.resource_uid
            #here we decide if we should delete the volume
            if $param_action == "Alert and Delete"
              sub task_name: "Delete Volume" do
                task_label("Delete Volume")
                sub on_error: handle_error() do
                  @volume.destroy()
                end
              end
            end

        $volume_table = "<tr>" + $table_start + $volume_name + $table_end + $table_start + $volume_size + $table_end + $table_start + $display_days_old + $table_end + $table_start + $volume_href + $table_end + $table_start + $cloud_name + $table_end + $table_start + $volume_id + $table_end +"</tr>"
        insert($list_of_volumes, -1, $volume_table)
        
        call sys_log.detail("volume_name: " + $volume_name)
        call sys_log.detail("volume_id: " + $volume_id) 		
		call mailer.update_csv_with_rows($endpoint,$filename,[$volume_name, $volume_size,$display_days_old, $volume_href,$cloud_name,$volume_id]) retrieve $filename
		end
      end

          $footer='</tr>
      </table>
  </td>
</tr>
<tr>
  <td align="left" valign="top">
      <table border="0" cellpadding="20" cellspacing="0" width="100%" id="emailFooter">
          <tr>
              <td align="left" valign="top">
                  This report was automatically generated by a policy template Unattached Volume Policy your organization has defined in RightScale.
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
</html>'

  $email_body = $header + $list_of_volumes + $footer
  call mailer.send_html_email($endpoint, $to, $from, $subject, $email_body, $filename, "html") retrieve $response

  if $response['code'] != 200
    raise 'Failed to send email report: ' + to_s($response)
  end
end

define handle_error() do
  #error_msg has the response from the api , use that as the error in the email.
  #$$error_msg = $_error["message"]
  $$error_msg = " failed to delete"
  $_error_behavior = "skip"
end


# Returns the RightScale account number in which the CAT was launched.
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