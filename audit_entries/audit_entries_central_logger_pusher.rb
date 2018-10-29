name 'Audit Entries to Central Logger Pusher CAT'
rs_ca_ver 20160622
short_description "![RS Policy](https://goo.gl/RAcMcU =64x64)\n
This automated policy CAT collects audit entries and (will eventually) push them to a central logging system (e.g. Splunk)."
long_description "Version: 0.1"
import "mailer"
import "sys_log"
import "pft/err_utilities"

##################
# Permissions    #
##################
permission "general_permissions" do
  resources "rs_cm.audit_entries"
  actions   "rs_cm.index"
end

##################
# User inputs    #
##################
parameter "param_how_long_ago" do
  label "Number of minutes in the past to go for audit entries"
  type "number"
  min_value 15
  default 60
end

parameter "param_email" do
  category "Contact"
  label "Email addresses (separate with commas)"
  type "string"
end

##################
# Operations     #
##################

operation "launch" do
  description "Collect audit entries"
  definition "audit_entries_harvester"
end


### launch definitions ###
define audit_entries_harvester($param_how_long_ago, $param_email) do
  call get_audit_times($param_how_long_ago) retrieve $start_time, $end_time
  $audit_data = []
  @audit_entries = rs_cm.audit_entries.index(limit: 1000, start_date: $start_time, end_date: $end_time)
  foreach @audit_entry in @audit_entries do
    $audit_summary = @audit_entry.summary
    
    # Some audits we may want to skip outright, they are not applicable to the use-case and are large and time consuming to process
    call check_audit($audit_summary) retrieve $good_audit
    if $good_audit
      $audit_href = @audit_entry.href
      $audit_user_email = @audit_entry.user_email
      
      # Build the base audit detail hash
      $audit_data_element = { 
        audit_href: $audit_href, 
        audit_summary: $audit_summary, 
        audit_user_email: $audit_user_email, 
        auditee_href: "N/A", 
        auditee_name: "N/A",
        rightscript_name: "N/A",
        rightscript_duration: "N/A"
      }
      
      # If the auditee resource is gone by the time we try to get tin the info, so be it.
      sub on_error: skip do
        @auditee =  @audit_entry.auditee()
        $audit_data_element["auditee_name"] = @auditee.name
        $audit_data_element["auditee_href"]= @auditee.href
      end
      
      # audit details may have multiple events so create an audit data item for each detailed event.
      # some audit details may not be returned as an array, so just skip those.
      $audit_detail = @audit_entry.detail()
      if type($audit_detail) == "array"
        while type($audit_detail) == "array" do
          $audit_detail = $audit_detail[0]
          sub on_error: skip do
            $details_array = split($audit_detail, "********************************************************************************")
            foreach $details_item in $details_array do
              call get_audit_detail_info($details_item) retrieve $rightscript_name, $rightscript_duration
              # We only care about this item if it has rightscript-related info in it.
              if $rightscript_name != "N/A"
                $audit_data_element["rightscript_name"] = $rightscript_name
                $audit_data_element["rightscript_duration"] = $rightscript_duration 
                $audit_data << $audit_data_element
              end
            end
          end
        end
      else
        $audit_data << $audit_data_element
      end
    end
  end
  
  # Call uploader
  call audit_entries_uploader($audit_data, $param_email)
  
end



define audit_entries_uploader($audit_data, $param_email) do
  
  # Emailer placeholder
  # But eventually this will host the logic for sending the data to the central logging system.

    #get account id to include in the email.
    call find_account_name() retrieve $account_name
    $endpoint = "http://policies.services.rightscale.com"
    $from = "policy-cat@services.rightscale.com"
    $subject = $account_name + " - Audit Entries Report"
    $to = $param_email
    $columns = ["Auditee Name", "Auditee HREF", "Audit Summary", "Audit HREF", "User", "RightScript Name", "RightScript Duration"]
    call mailer.create_csv_with_columns($endpoint,$columns) retrieve $filename
    $email_msg = "Audit Entries Found"


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
                                              Auditee Name
                                          </td>
                                          <td align="left" valign="top">
                                              Auditee HREF
                                          </td>
                                          <td align="left" valign="top">
                                              Audit Summary
                                          </td>
                                          <td align="left" valign="top">
                                              Audit HREF
                                          </td>
                                          <td align="left" valign="top">
                                              User
                                          </td>
                                          <td align="left" valign="top">
                                              RightScript Name
                                          </td>
                                          <td align="left" valign="top">
                                              RightScript Duration
                                          </td>
                                      </tr>
                                      '
      $list_of_audits=""
      $table_start='<td align="left" valign="top">'
      $table_end="</td>"

      foreach $audit_item in $audit_data do
        $auditee_name = $audit_item["auditee_name"]
        $auditee_href = $audit_item["auditee_href"]
        $audit_summary = $audit_item["audit_summary"]
        $audit_href = $audit_item["audit_href"]
        $audit_user = $audit_item["audit_user_email"]
        $audit_rightscript_name = $audit_item["rightscript_name"]
        $audit_rightscript_duration = $audit_item["rightscript_duration"]
        
        $audit_table = "<tr>" + $table_start + $auditee_name + $table_end + $table_start + $auditee_href + $table_end + $table_start + $audit_summary + $table_end + $table_start + $audit_href + $table_end + $table_start + $audit_user + $table_end + $table_start + $audit_rightscript_name + $table_end + $table_start + $audit_rightscript_duration + $table_end+"</tr>"
        insert($list_of_audits, -1, $audit_table)
		
        call mailer.update_csv_with_rows($endpoint,$filename,[$auditee_name, $auditee_href,$audit_summary, $audit_href,$audit_user,$audit_rightscript_name,$audit_rightscript_duration]) retrieve $filename
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
                  This report was automatically generated by a policy template Audit Entry Harvester your organization has defined in RightScale.
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

  $email_body = $header + $list_of_audits + $footer
  call mailer.send_html_email($endpoint, $to, $from, $subject, $email_body, $filename, "html") retrieve $response

  if $response['code'] != 200
    raise 'Failed to send email report: ' + to_s($response)
  end
end



define get_audit_times($param_how_long_ago) return $start_time_formatted, $end_time_formatted do
  $end_time = now()
  $start_time = now() - (to_n($param_how_long_ago) * 60)
  $end_time_formatted = strftime($end_time, "%Y/%m/%d %H:%M:%S +0000")
  $start_time_formatted = strftime($start_time, "%Y/%m/%d %H:%M:%S +0000")
end

define check_audit($summary) return $good_audit do
  $good_audit = true
  if $summary =~ "RightLink10 .* log pid"
    $good_audit = false
  end
end

define get_audit_detail_info($audit_detail) return $rightscript_name, $rightscript_duration do
  $detail_array = split($audit_detail, "\n")
  $rightscript_name = "N/A"
  $rightscript_duration = "N/A"
  foreach $item in $detail_array do
    if $item =~ "RightScript:"
      $item_array = split($item, "'")
      $rightscript_name = $item_array[1]
    elsif $item =~ "Duration:"
      $rightscript_duration = sub($item, /^.*Duration: /,"")
      $rightscript_duration = sub($rightscript_duration, / seconds.*$/,"")
    end
  end
end

# Returns the RightScale account number in which the CAT was launched.
define find_account_name() return $account_name do
  $session_info = rs_cm.sessions.get(view: "whoami")
  $acct_link = select($session_info[0]["links"], {rel: "account"})
  $acct_href = $acct_link[0]["href"]
  $account_name = rs_cm.get(href: $acct_href).name
end


