name "Policy: Security Group Updated"
rs_ca_ver 20161221
short_description "Policy to notify when a security group has changed"
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

operation "generate_report" do
  description "generate report on security_group changes"
  definition "generate_report"
end

define launch($param_email) do
  $time = now() + 120
  rs_ss.scheduled_actions.create(
                                  execution_id:       @@execution.id,
                                  name:               "Adding Alert Specs",
                                  action:             "run",
                                  operation:          { "name": "generate_report" },
                                  first_occurrence:   $time,
                                  recurrence:         "FREQ=MINUTELY;INTERVAL=60")
end

define generate_report($param_email) do
  call sys_log.set_task_target(@@deployment)
  call sys_log.summary("SecurityGroupUpdatePolicy")
  $end_api_time = strftime(now(), "%Y/%m/%d %H:%M:%S +0000")
  $start_date = now() - 3600
  $start_api_time = strftime($start_date, "%Y/%m/%d %H:%M:%S +0000")
  $endpoint = "http://policies.services.rightscale.com"
  $subject = "Policy: Security Group Updated"
  $from = "policy-cat@services.rightscale.com"
  @audit_entries = rs_cm.audit_entries.index(start_date: $start_api_time, end_date: $end_api_time, limit:1000)
  @security_audit_entries_array = rs_cm.audit_entries.empty()
  foreach @ae in @audit_entries do
    if to_s(@ae.summary) =~ /Security group/
      @security_audit_entries_array = @security_audit_entries_array + @ae
    end
  end
  if size(@security_audit_entries_array) > 0
    call mailer.create_csv_with_columns($endpoint,["summary", "user_email", "updated_at", "detail"]) retrieve $filename
    $$csv_filename = $filename
    foreach @ae in @security_audit_entries_array do
      call mailer.update_csv_with_rows($endpoint, $filename,[@ae.summary, @ae.user_email, @ae.updated_at, @ae.detail()]) retrieve $filename
    end
    call mailer.send_html_email($endpoint, $param_email, $from, $subject, "Please see attachment for accounts", $filename, "text") retrieve $response
  end
end
