

name 'Unattached Volume Policy'
rs_ca_ver 20160622
short_description "This automated policy CAT will find unattached volumes, send alerts, and optionally delete them."

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
# Find unattached volumes and takes an action (alert, alert + delete)
#
# FEATURES
# Users can automatically have unattached volumes deleted.
#



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

define launch($param_email,$param_action,$param_days_old) return $param_email,$param_action,$param_days_old do
        call find_unattached_volumes($param_action)
        sleep(20)
        call send_email_mailgun($param_email)
end


define find_unattached_volumes($param_action) do

    #get all volumes
    @all_volumes = rs_cm.volumes.index(view: "default")

    #search the collection for only volumes with status = available
    @volumes_not_in_use = select(@all_volumes, { "status": "available" })

    #get account id to include in the email.
    call find_account_name() retrieve $account_name
    #refactor.
    if $param_action == "Alert and Delete"
      $email_msg = "RightScale discovered the following unattached volumes in "+ $account_name +". Per the policy set by your organization, these volumes have been deleted and are no longer accessible"
    else
      $email_msg = "RightScale discovered the following unattached volumes in "+ $account_name +". These volumes are incurring cloud charges and should be deleted if they are no longer being used."
    end


    $header="\<\!DOCTYPE html PUBLIC \"-\/\/W3C\/\/DTD XHTML 1.0 Transitional\/\/EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\"\>
    <html xmlns=\"http:\/\/www.w3.org\/1999\/xhtml\">
        <head>
            <meta http-equiv=%22Content-Type%22 content=%22text/html; charset=UTF-8%22 />
            <a href=%22//www.rightscale.com%22>
<img src=%22https://assets.rightscale.com/6d1cee0ec0ca7140cd8701ef7e7dceb18a91ba20/web/images/logo.png%22 alt=%22RightScale Logo%22 width=%22200px%22 />
</a>
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
                                              Volume Name
                                          </td>
                                          <td align=%22left%22 valign=%22top%22>
                                              Volume Size
                                          </td>
                                          <td align=%22left%22 valign=%22top%22>
                                              Days Old
                                          </td>
                                          <td align=%22left%22 valign=%22top%22>
                                              Volume Href
                                          </td>
                                          <td align=%22left%22 valign=%22top%22>
                                              Cloud
                                          </td>
                                          <td align=%22left%22 valign=%22top%22>
                                              Volume ID
                                          </td>
                                      </tr>
                                      "
      $list_of_volumes=""
      $table_start="<td align=%22left%22 valign=%22top%22>"
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
        end

      end

          $footer="</tr>
      </table>
  </td>
</tr>
<tr>
  <td align=%22left%22 valign=%22top%22>
      <table border=%220%22 cellpadding=%2220%22 cellspacing=%220%22 width=%22100%%22 id=%22emailFooter%22>
          <tr>
              <td align=%22left%22 valign=%22top%22>
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
</html>
"
          $$email_body = $header + $list_of_volumes + $footer


end

define handle_error() do
  #error_msg has the response from the api , use that as the error in the email.
  #$$error_msg = $_error["message"]
  $$error_msg = " failed to delete"
  $_error_behavior = "skip"
end

define send_email_mailgun($to) do
  $mailgun_endpoint = "http://smtp.services.rightscale.com/v3/services.rightscale.com/messages"

   $to = gsub($to,"@","%40")
   $post_body="from=policy-cat%40services.rightscale.com&to=" + $to + "&subject=Volume+Policy+Report&html=" + $$email_body

  $response = http_post(
     url: $mailgun_endpoint,
     headers: { "content-type": "application/x-www-form-urlencoded"},
     body: $post_body
    )
end

# Returns the RightScale account number in which the CAT was launched.
define find_account_name() return $account_name do
  $session_info = rs_cm.sessions.get(view: "whoami")
  $acct_link = select($session_info[0]["links"], {rel: "account"})
  $acct_href = $acct_link[0]["href"]
  $account_name = rs_cm.get(href: $acct_href).name
end
