name 'InstanceFinder'
rs_ca_ver 20160622
short_description "Finds long running instances"

#Copyright 2016 RightScale
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
parameter "param_action" do
  category "Instance"
  label "Instance Action"
  type "string"
  allowed_values "Alert"
  #allowed_values "ALERT", "ALERT AND TERMINATE"
  default "Alert"
end

parameter "param_email" do
  category "Contact"
  label "email address (reports are sent to this address)"
  type "string"
  default "edwin@rightscale.com"

end

parameter "param_days_old" do
  category "Instance"
  label "Report on instances that have been running longer than this number of days:"
  type "number"
  default "1"
end



operation "launch" do
  description "Find long running instances"
  definition "launch"
end


##################
# Definitions    #
##################

define launch($param_email,$param_action,$param_days_old) return $param_email,$param_action,$param_days_old do
        call find_long_running_instances($param_days_old)
        sleep(20)
        call send_email_mailgun($param_email)
end


define find_long_running_instances($param_days_old) do

#`pending`, `booting`, `operational`, `stranded`, `stranded in booting`, `running`
    @all_instances = rs_cm.instances.index(filter:["state==operational"])
    @all_instances = @all_instances + rs_cm.instances.index(filter:["state==booting"])
    @all_instances = @all_instances + rs_cm.instances.index(filter:["state==pending"])
    @all_instances = @all_instances + rs_cm.instances.index(filter:["state==stranded"])
    @all_instances = @all_instances + rs_cm.instances.index(filter:["state==running"])
    #get account id to include in the email.
    call find_account_name() retrieve $account_name
    #refactor.
    if $param_action == "Alert and Delete"
      $email_msg = "RightScale discovered the following long running instances in "+ $account_name +". Per the policy set by your organization, these volumes have been deleted and are no longer accessible"
    else
      $email_msg = "RightScale discovered the following long running instances in "+ $account_name +". These instances are incurring cloud charges and should be terminated if they are no longer being used."
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
                                              Instance Name
                                          </td>
                                          <td align=%22left%22 valign=%22top%22>
                                              Type
                                          </td>
                                          <td align=%22left%22 valign=%22top%22>
                                              State
                                          </td>
                                          <td align=%22left%22 valign=%22top%22>
                                              Cloud
                                          </td>
                                          <td align=%22left%22 valign=%22top%22>
                                              Days Old
                                          </td>
                                          <td align=%22left%22 valign=%22top%22>
                                              Link
                                          </td>
                                      </tr>
                                      "
      $list_of_instances=""
      $table_start="<td align=%22left%22 valign=%22top%22>"
      $table_end="</td>"

    #/60/60/24
    $curr_time = now()
    #$$day_old = now() - (60*60*24)

    foreach @instance in @all_instances do

      #convert string to datetime to compare datetime
      $instance_updated_at = to_d(@instance.updated_at)

      #the difference between dates
      $difference = $curr_time - $instance_updated_at

      #convert the difference to days
      $how_old = $difference /60/60/24

    	if $param_days_old < $how_old
      call find_shard() retrieve $shard_number
      call find_account_number() retrieve $account_id

      call get_server_access_link(@instance.href, $shard_number, $account_id) retrieve $server_access_link_root
      $instance_name = @instance.name
      $instance_type = @instance.instance_type().description
      $instance_state = @instance.state
      $cloud_name = @instance.cloud().name
      $display_days_old = first(split(to_s($how_old),"."))
    $instance_table = "<tr>" + $table_start + $instance_name + $table_end + $table_start + $instance_type + $table_end + $table_start + $instance_state + $table_end + $table_start + $cloud_name + $table_end + $table_start + $display_days_old + $table_end + $table_start + $server_access_link_root + $table_end + "</tr>"
    insert($list_of_instances, -1, $instance_table)
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
              This report was automatically generated by a policy template Long Running Instnaces your organization has defined in RightScale.
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
      $$email_body = $header + $list_of_instances + $footer
end




define send_email_mailgun($to) do
    $mailgun_endpoint = "http://smtp.services.rightscale.com/v3/services.rightscale.com/messages"

       $to = gsub($to,"@","%40")
       $subject = "Long Running Instances Report"
       $text = "You have the following long running instances"

       $post_body="from=policy-cat%40services.rightscale.com&to=" + $to + "&subject=Policy+Report&html=" + $$email_body


    $$response = http_post(
       url: $mailgun_endpoint,
       headers: { "content-type": "application/x-www-form-urlencoded"},
       body: $post_body
      )
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
