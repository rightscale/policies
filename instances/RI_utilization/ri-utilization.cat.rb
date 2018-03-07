name "RI-Utilization"
rs_ca_ver 20161221
short_description "Downsize instances based on cpu and memory utilization"
long_description "Version: 0.1"
import "sys_log"
import "mailer"

##################
# User inputs    #
##################

parameter "param_utilization" do
  category "RI"
  label "Utilization"
  type "number"
  default "100"
end

parameter "param_email" do
  category "Contact"
  label "Email addresses (separate with commas)"
  type "string"
end

output "underutilized" do
  label "underutilized"
  category "Cloud"
  default_value $arr_underutilized_s
  description "Instance type that is running"
end

operation "launch" do
  description "Search for resizing opportunities"
  definition "launch"
  output_mappings do {
    $underutilized => join(["underutilized:",$arr_underutilized_s])
  } end
end

define launch($param_utilization) return $arr_underutilized_s do
  call sys_log.set_task_target(@@deployment)
  call sys_log.summary("utilization")
  $response = http_get(
    url: "https://optima.rightscale.com/api/reco/orgs/2932/aws_reserved_instances"
  )
  $body = $response["body"]
  $arr_underutilized = []
  foreach $item in $body do
    if to_n($item["utilization"]["utilization_percentage"]) < $param_utilization
      call sys_log.detail($item["utilization"]["utilization_percentage"])
      $arr_underutilized << $item
    end
  end
  $arr_underutilized_s = to_s($arr_underutilized)
end
