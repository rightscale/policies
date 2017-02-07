name 'Public Security Group Rule Policy'
rs_ca_ver 20160622
short_description 'This automated policy CAT will find security group rules that allow traffic to/from 0.0.0.0/0, send alerts, and optionally delete them.'

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
# Finds public security group rules and reports on them
#


##################
# User inputs    #
##################

parameter "param_hrefs_whitelist" do
  category "Policy"
  label "Whitelisted security group rules (separate with commas)"
  type "string"
end

parameter "param_action" do
  category "Policy"
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

operation "launch" do
  description "Find public security group rules"
  definition "launch"
end



##################
# Definitions    #
##################

define launch($param_email,$param_action,$param_hrefs_whitelist) return $param_email,$param_action,$param_hrefs_whitelist do
        call find_public_security_group_rules($param_email,$param_action,$param_hrefs_whitelist) retrieve $send_email
        sleep(20)
        if $send_email == "true"
          call send_email_mailgun($param_email)
        end
end

define find_public_security_group_rules($param_email,$param_action,$param_hrefs_whitelist) return $send_email do

    #get account id to include in the email.
    call find_account_name() retrieve $account_name
    #refactor.
    if $param_action == "Alert and Terminate"
      $email_msg = "RightScale discovered the following instances in "+ $account_name +". Per the policy set by your organization, these instances have been terminated and are no longer accessible"
    else
      $email_msg = "RightScale discovered the following security group rules in "+ $account_name +" that allow access to the internet [CIDR: 0.0.0.0/0]."
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
                                                    Security Group Rule Href
                                                </td>                                            
                                                <td align=%22left%22 valign=%22top%22>
                                                    Description (Optional)
                                                </td>
                                                <td align=%22left%22 valign=%22top%22>
                                                    Direction
                                                </td>
                                                <td align=%22left%22 valign=%22top%22>
                                                    Protocol
                                                </td>
                                                <td align=%22left%22 valign=%22top%22>
                                                    Ports
                                                </td>
                                                <td align=%22left%22 valign=%22top%22>
                                                    Security Group
                                                </td>
                                                <td align=%22left%22 valign=%22top%22>
                                                    Network
                                                </td>                                             
                                            </tr>
                                      "
                                     
      $table_start="<td align=%22left%22 valign=%22top%22>"
      $table_end="</td>"
      $footer="</tr></table></td></tr><tr><td align=%22left%22 valign=%22top%22><table border=%220%22 cellpadding=%2220%22 cellspacing=%220%22 width=%22100%%22 id=%22emailFooter%22><tr><td align=%22left%22 valign=%22top%22>
              This report was automatically generated by a policy template Instance Runtime Policy your organization has defined in RightScale.
          </td></tr></table></td></tr></table></td></tr></table></body></html>"

  $public_security_group_rules_table = ""
  $public_security_group_rules_detail = ""

  task_label('Retrieving all Security Group Rules from Account')
  @security_group_rules = rs_cm.security_group_rules.index()
  
  task_label('Filtering Security Group Rules that match CIDR 0.0.0.0/0')
  @public_security_group_rules = select(@security_group_rules, {'cidr_ips': "0.0.0.0/0"})
  task_label('Counting the results')
  $public_security_group_rules_count = size(@public_security_group_rules)

  task_label('Checking if there are any public security group rules that were found')
  if $public_security_group_rules_count > 0
    $send_email = "true"
    task_label('Found ' + $public_security_group_rules_count + ' open security group rules')
    
    task_label('Generating Public Security Group Details')

    $curr_time = now()
    call find_shard() retrieve $shard_number
    call find_account_number() retrieve $account_id
    foreach @rule in @public_security_group_rules do

        sub on_error: skip do
        $rule_href = @rule.href
        end     
        if $rule_href == null
          $rule_href = 'unknown'
        end        

        sub on_error: skip do
        $rule_description = @rule.description
        end     
        if $rule_description == null
          $rule_description = 'unknown'
        end

        #if we're unable to get the instance type, it will be listed as unknown in the email report.
        sub on_error: skip do
        $rule_direction = @rule.direction
        end     
        if $rule_direction == null
          $rule_direction = 'unknown'
        end

        sub on_error: skip do
        $rule_protocol = @rule.protocol
        end
        if $rule_protocol == null
            $rule_protocol = 'unknown'
        end

        sub on_error: skip do
        $rule_startPort = @rule.start_port
        end
        if $rule_startPort == null
            $rule_startPort = 'unknown'
        end

        sub on_error: skip do
        $rule_endPort = @rule.end_port
        end
        if $rule_endPort == null
            $rule_endPort = 'unknown'
        end    

        sub on_error: skip do
        $sg_name = @rule.security_group().name
        end
        if $sg_name == null
            $sg_name = 'unknown'
        end   

        sub on_error: skip do
        $cloud_name = @rule.security_group().cloud().name
        end
        if $cloud_name == null
            $cloud_name = 'unknown'
        end   


        $public_security_group_rules_table = $public_security_group_rules_table + "<tr>" + $table_start + $rule_href + $table_end + $table_start + $rule_description + $table_end + $table_start + $rule_direction + $table_end + $table_start + $rule_protocol + $table_end + $table_start + $rule_startPort + "-" + $rule_endPort + $table_end + $table_start + $sg_name + $table_end + $table_start + $cloud_name + $table_end  + "</tr>"
    end
  else
    task_label('No open security groups rules found')
  end
   
  $$email_body = $header + $public_security_group_rules_table + $footer
      
end






















define send_email_mailgun($to) do
  $mailgun_endpoint = "http://smtp.services.rightscale.com/v3/services.rightscale.com/messages"
  call find_account_name() retrieve $account_name

     $to = gsub($to,"@","%40")
     $subject = "Long Running Instances Report"
     $text = "You have the following long running instances"

     $post_body="from=policy-cat%40services.rightscale.com&to=" + $to + "&subject=[" + $account_name + "] Instance+Policy+Report&html=" + $$email_body


  $$response = http_post(
     url: $mailgun_endpoint,
     headers: { "content-type": "application/x-www-form-urlencoded"},
     body: $post_body
    )
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
