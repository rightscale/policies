name "Policy: Governance Update"
rs_ca_ver 20161221
short_description "Policy to track audit entry updates for governance"
long_description "Version: 0.1"
import "sys_log"
import "mailer"

##################
# User inputs    #
##################

parameter "param_email" do
  category "Contact"
  label "Email addresses (separate with commas)"
  type "string"
end

operation "launch" do
  description "Search for resizing opportunities"
  definition "launch"
end

define launch($param_email) return $response do
  call sys_log.set_task_target(@@deployment)
  call sys_log.summary("Policy: Governance Update")
  $end_api_time = strftime(now(), "%Y/%m/%d %H:%M:%S +0000")
  $start_date = now() - 3600
  $start_api_time = strftime($start_date, "%Y/%m/%d %H:%M:%S +0000")
  $endpoint = "http://policies.services.rightscale.com"
  $subject = "Policy: Managed Login Updated"
  $from = "policy-cat@services.rightscale.com"
  @audit_entries = rs_cm.audit_entries.index(start_date: $start_api_time, end_date: $end_api_time, limit:1000)
  @governance_audit_entries_array = rs_cm.audit_entries.empty()
  $$ae_array = [["summary","resource","api_href", "updated_at", "detail"]]
  foreach @ae in @audit_entries do
    if (to_s(@ae.summary) =~ /Granted Role/) || (to_s(@ae.summary) =~ /Modified memberships/)
      @governance_audit_entries_array = @governance_audit_entries_array + @ae
    end
  end
  if size(@governance_audit_entries_array) > 0
    call mailer.create_csv_with_columns($endpoint,["summary", "user_email", "updated_at"]) retrieve $filename
    $$csv_filename = $filename
    foreach @ae in @governance_audit_entries_array do
      call mailer.update_csv_with_rows($endpoint, $filename,[@ae.summary, @ae.user_email, @ae.updated_at]) retrieve $filename
    end
    call mailer.send_html_email($endpoint, $param_email, $from, $subject, "Please see attachment for accounts", $filename, "text") retrieve $response
  end
end
