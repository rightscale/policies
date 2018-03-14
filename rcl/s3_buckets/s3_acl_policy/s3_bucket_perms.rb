name 'S3 Bucket ACL Policy'
rs_ca_ver 20161221
short_description "![RS Policy](https://raw.githubusercontent.com/rightscale/policies/master/s3_buckets/s3_acl_policy/imgs/bucket_icon.png =64x64)\n
This automated policy CAT will provide a report on S3 Buckets in your AWS account."
long_description "Version: 1.0"
import "sys_log"

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
#


##################
# User inputs    #
##################

parameter "param_all_buckets" do
  category "Buckets to Report"
  label "All Buckets?"
  description "If selected, all S3 buckets in your AWS account will appear in the report"
  type "string"
  allowed_values "true","false"
  default "true"
end 

parameter "param_pub_read" do
  category "Buckets to Report"
  label "Public READ Enabled?"
  description "If selected, S3 buckets with the Public READ permission will appear in the report. Note: these buckets will already appear if the 'All Buckets?' parameter is selected."
  type "string"
  allowed_values "true","false"
  default "false"
end

parameter "param_pub_write" do
  category "Buckets to Report"
  label "Public WRITE Enabled?"
  description "If selected, S3 buckets with the Public WRITE permission will appear in the report. Note: these buckets will already appear if the 'All Buckets?' parameter is selected."
  type "string"
  allowed_values "true","false"
  default "false"
end

parameter "param_email" do
  category "Contact"
  label "Email addresses (separate with commas)"
  type "string"
  allowed_pattern '^([a-zA-Z0-9-_.]+[@]+[a-zA-Z0-9-_.]+[.]+[a-zA-Z0-9-_]+,*)+$'
end

operation "launch" do
  description "Find long running instances"
  definition "launch"
end


##################
# Definitions    #
##################

define launch($param_email, $param_all_buckets, $param_pub_read, $param_pub_write) return $param_email,$send_email,$number_of_buckets,$target_buckets,$buckets_array do
        call find_s3_buckets($param_all_buckets, $param_pub_read, $param_pub_write) retrieve $send_email,$number_of_buckets,$target_buckets,$buckets_array
        sleep(20)
        if $send_email == "true"
          call send_email_mailgun($param_email)
        end
end

define find_s3_buckets($param_all_buckets, $param_pub_read, $param_pub_write) return $send_email,$number_of_buckets,$target_buckets,$buckets_array do
  call list_s3_buckets() retrieve $bucket_names
  $buckets_array = []
  foreach $bucket_name in $bucket_names do
    call get_analyze_bucket_acl($bucket_name) retrieve $bucket_hash,$api_response
    $buckets_array << $bucket_hash
  end

  $list_of_buckets=""
  $table_start="<td align=%22left%22 valign=%22top%22>"
  $table_end="</td>"
  $target_buckets = []
  if $param_all_buckets == "true"
    call sys_log.detail("Selected: ALL BUCKETS")
    $target_buckets = $buckets_array
  else    
    if $param_pub_read == "true" && $param_pub_write == "false"
      call sys_log.detail("Selected: READ ONLY")
      foreach $bucket in $buckets_array do         
        if $bucket["public_read"] == "true"
          $target_buckets << $bucket
        end 
      end
    end

    if $param_pub_read == "false" && $param_pub_write == "true"
      call sys_log.detail("Selected: WRITE ONLY")
      foreach $bucket in $buckets_array do  
        if $bucket["public_write"] == "true"
          $target_buckets << $bucket
        end
      end
    end

    if $param_pub_read == "true" && $param_pub_write == "true"
      call sys_log.detail("Selected: READ-WRITE")
      foreach $bucket in $buckets_array do 
        if $bucket["public_write"] == "true" || $bucket["public_read"] == "true"
          $target_buckets << $bucket
        end 
      end
    end
  end 

  $number_of_buckets = size($target_buckets)
  if $number_of_buckets > 0
    $send_email = "true"
  else
    $send_email = "false"
  end

  foreach $bucket in $target_buckets do 
    $bucket_table = "<tr>" + $table_start + $bucket["bucket_name"] + $table_end + $table_start + $bucket["public_read"] + $table_end + $table_start + $bucket["public_write"] + $table_end + "</tr>"
    insert($list_of_buckets, -1, $bucket_table)
  end 
  
  call find_account_name() retrieve $account_name  
  $email_msg = "RightScale discovered <b>" + $number_of_buckets + "</b> S3 Buckets in <b>"+ to_s(gsub($account_name, "&","-")) +"</b> that were flagged per the settings supplied in the automated policy."

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
                                        <td align=%22left%22 valign=%22top%22><b>
                                            S3 Bucket Name
                                        </b></td>
                                        <td align=%22left%22 valign=%22top%22><b>
                                            Public Read?
                                        </b></td>
                                        <td align=%22left%22 valign=%22top%22><b>
                                            Public Write?
                                        </b></td>
                                    </tr>
                                    "
  $footer="</tr></table></td></tr><tr><td align=%22left%22 valign=%22top%22><table border=%220%22 cellpadding=%2220%22 cellspacing=%220%22 width=%22100%%22 id=%22emailFooter%22><tr><td align=%22left%22 valign=%22top%22>
          This report was automatically generated by a policy template S3 Bucket ACL Policy your organization has defined in RightScale.
        </td></tr></table></td></tr></table></td></tr></table></body></html>"
  $$email_body = $header + $list_of_buckets + $footer        

end

define list_s3_buckets() return $bucket_names do
  call start_debugging()
    sub on_error: stop_debugging() do
      $response = http_get(
        url: "https://s3.amazonaws.com",
        signature: {"type": "aws"}
        )
      $buckets = $response["body"]["ListAllMyBucketsResult"]["Buckets"]["Bucket"]
      $bucket_names = []
      foreach $bucket in $buckets do
        $bucket_names << $bucket["Name"]
      end
    end
  call stop_debugging()
  call sys_log.detail("Bucket List: " + to_s($bucket_names))
end

define get_analyze_bucket_acl($bucket_name) return $hash,$response do
  $hash = {}
  if $bucket_name =~ "^([A-Z])"
    call sys_log.detail("Skipping Bucket due to Capital Letter in Name: " + $bucket_name)
    $hash["bucket_name"] = $bucket_name
    $hash["public_read"] = "unknown"
    $hash["public_write"] = "unknown"
  else
    call sys_log.detail("Analyzing Bucket: " + $bucket_name)    
    $_error_behavior = "skip"
    call start_debugging()
    sub on_error: skip do
      $response = http_get(
        url: join(["https://", $bucket_name, ".s3.amazonaws.com/?acl="]),
        signature: {"type": "aws"}
        )

      if $response["code"]==400
          $response = http_get(
            url: "https://" + $bucket_name + ".s3-" + $response["body"]["Error"]["Region"] + ".amazonaws.com/?acl=",
            signature: {"type": "aws"}
            )
      end 
    end
    call stop_debugging()
    if $hash == {}
      $public_read = "false"
      $public_write = "false"
      sub on_error: skip do
        $acls = [] 
        $acls = $response["body"]["AccessControlPolicy"]["AccessControlList"]["Grant"]
        foreach $acl in $acls do
          if $acl["Grantee"]["URI"] == "http://acs.amazonaws.com/groups/global/AllUsers"
            if $acl["Permission"] == "READ"
              $public_read = "true"
            elsif $acl["Permission"] == "WRITE"
              $public_write = "true"
            else
            end
          end
        end
      end
      
      $hash["bucket_name"] = $bucket_name
      $hash["public_read"] = $public_read
      $hash["public_write"] = $public_write 
    end 
  end
  $_error_behavior = "raise"
end 

define handle_error() do
  #error_msg has the response from the api , use that as the error in the email.
  #$$error_msg = $_error["message"]
  $$error_msg = to_s($_error)
  $_error_behavior = "skip"
end

define send_email_mailgun($to) do
  call start_debugging()
  $mailgun_endpoint = "http://smtp.services.rightscale.com/v3/services.rightscale.com/messages"
  call find_account_name() retrieve $account_name
  $to = gsub($to,"@","%40")
  $subject = "S3 Buckets Access Report"
  $text = "The following S3 Buckets met the automated policy settings"
  $post_body="from=policy-cat%40services.rightscale.com&to=" + $to + "&subject=[" + to_s(gsub($account_name, "&","-")) + "] S3+Bucket+Policy+Report&html=" + $$email_body
  call sys_log.detail("RS_POST_BODY:" + $post_body)

  $$response = http_post(
   url: $mailgun_endpoint,
   headers: { "content-type": "application/x-www-form-urlencoded"},
   body: $post_body
  )
  call stop_debugging()
end

# Returns the RightScale account number in which the CAT was launched.
define find_account_number() return $account_id do
  $session = rs_cm.sessions.index(view: "whoami")
  $account_id = last(split(select($session[0]["links"], {"rel":"account"})[0]["href"],"/"))
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