name "Policy: RI Expiration"
rs_ca_ver 20161221
short_description "RI Expiration Policy"
long_description "Version: 0.1"
import "sys_log"
import "mailer"

##################
# User inputs    #
##################
parameter "param_organization_account_number" do
  category "RI"
  label "Organization Account Number"
  type "number"
  default "2932"
end

parameter "param_email" do
  category "Contact"
  label "Email addresses (separate with commas)"
  type "string"
end

output "underutilized" do
  label "Expiring"
  category "Cloud"
  default_value $arr_expiring_s
  description "Instance type that is running"
end

operation "launch" do
  description "Search for resizing opportunities"
  definition "launch"
  output_mappings do {
    $underutilized => join(["underutilized:",$arr_expiring_s])
  } end
end

define launch($param_email,$param_organization_account_number) return $arr_expiring_s do
  call sys_log.set_task_target(@@deployment)
  call sys_log.summary("Policy: RI-Expiration")
  # start date = 1hr * 24 * 30 days
  $start_date = now() + ( 3600 * 24 * 30 * 12)
  $start_api_time = strftime($start_date, "%Y/%m/%d %H:%M:%S +0000")
  $url = join(["https://optima.rightscale.com/api/reco/orgs/", $param_organization_account_number,"/aws_reserved_instances"])
  call sys_log.detail("url: "+ $url)
  $response = http_get(
    url: $url
  )
  $body = $response["body"]
  $$body = $body
  $arr_expiring = []
  foreach $item in $body do
    $cancellation_datetime = strftime(to_d($item["cancellation_datetime"]), "%Y/%m/%d %H:%M:%S +0000")
    $end_datetime = strftime(to_d($item["end_datetime"]), "%Y/%m/%d %H:%M:%S +0000")
    if $end_datetime < $start_api_time
      $arr_expiring << $item
    end
  end
  $arr_expiring_s = to_s($arr_expiring)
  $keys = keys($arr_expiring[0])
  $endpoint = "http://policies.services.rightscale.com"
  $subject = "RI expiring Policy"
  $from = "policy-cat@services.rightscale.com"
  call sys_log.detail(join(["keys: ", $keys]))
  call mailer.create_csv_with_columns($endpoint,$keys) retrieve $filename
  $$csv_filename = $filename
  foreach $item in $arr_expiring do
    call mailer.update_csv_with_rows($endpoint, $filename, values($item)) retrieve $filename
  end
  call mailer.send_html_email($endpoint, $param_email, $from, $subject, "Please see attachment for accounts", $filename, "text") retrieve $response
end