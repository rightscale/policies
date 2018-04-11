name "Policy: Managed Login Updated"
rs_ca_ver 20161221
short_description "Policy to track audit entry updates for managed login"
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
  call sys_log.summary("ManagedLoginPolicy")
  $end_api_time = strftime(now(), "%Y/%m/%d %H:%M:%S +0000")
  $start_date = now() - 3600
  $start_api_time = strftime($start_date, "%Y/%m/%d %H:%M:%S +0000")
  $endpoint = "http://policies.services.rightscale.com"
  $subject = "Policy: Managed Login Updated"
  $from = "policy-cat@services.rightscale.com"
  @audit_entries = rs_cm.audit_entries.index(start_date: $start_api_time, end_date: $end_api_time, limit:1000)
  @security_audit_entries_array = rs_cm.audit_entries.empty()
  $$ae_array = [["summary","resource","api_href", "updated_at", "detail"]]
  foreach @ae in @audit_entries do
    sub on_error: skip do
      if to_s(@ae.summary) =~ /RightLink10/
        task_label(join(["searching: ", @ae.summary]))
        @security_audit_entries_array = @security_audit_entries_array + @ae
        @resource = @ae.auditee()
        $detail = @ae.detail()
        $line_array = lines(first($detail))
        $details_to_include = []
        foreach $line in $line_array do
          $temp_line = ""
          if $line =~ /New users to process/
            $temp_line = $line
          end
          if $line =~ /User removed from/
            $temp_line = $line
          end
          $str_array = split($temp_line,' ')
          if size($str_array) > 1
            $date = to_d(join($str_array[0..1], ' '))
            $api_time = strftime($date, "%Y/%m/%d %H:%M:%S +0000")
            if $api_time > $start_api_time
              $details_to_include << $line
            end
          end
        end
        if size($details_to_include) > 0
          $$ae_array << [@ae.summary,@resource.name,@ae.href, @ae.updated_at, $details_to_include]
        end
      end
    end
  end
  if size($$ae_array) > 1
    call mailer.create_csv_and_send_email($endpoint,$param_email,$from,$subject,"Please see attachment for accounts",$$ae_array,"text") retrieve $response
  end
end
