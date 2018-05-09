name "Reserved Instances Utilization"
rs_pt_ver 20180301
type "policy"
short_description "A policy that sends email notifications when utilization falls below a threshold"
long_description "Version 0.1"
severity "medium"
category "Cost"

permission "optima_aws_ri" do
  label "Access Optima Resources"
  resources "rs_optima.aws_reserved_instances"
  actions "rs_optima.index"
end

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

auth "rs", type: "rightscale"

datasource "reservations" do
  request do
    auth $rs
    host "optima.rightscale.com"
    path join(["/reco/orgs", rs_org_id, "aws_reserved_instances"])
  end
  result do
    encoding "json"
    collect jmes_path(response,"[*]") do
      field "utilization_percentage", jmes_path(col_item,"utilization.utilization_percentage")
      field "end_datetime", jmes_path(col_item,"end_datetime")
      field "start_datetime", jmes_path(col_item,"start_datetime")
      field "account_name", jmes_path(col_item,"account_name")
      field "account_id", jmes_path(col_item,"account_id")
      field "region", jmes_path(col_item,"region")
      field "instance_type", jmes_path(col_item,"instance_type")
      field "instance_count", jmes_path(col_item,"instance_count")
    end
  end
end

escalation "alert" do
  email $param_email do
    subject_template "Reserved Instance Utilization"
    body_template "reserved instance utilization:"
  end
end

policy "ri_utilization" do
  validate_each $reservations do
    summary_template "Reserved Instance Utilization"
    detail_template <<-EOS

{ range data }
* Account: { $.account_name }({ $.account_id })
* Region: {$.region}
* Instance Type: {$.instance_type}
* Instance Count: {$.instance_count}
* Start Time: {$.start_datetime}
* End Time: {$.end_datetime}
----------------------------
{ end }
EOS

    escalate $alert
    check lt(val(item,"utilization_percentage"),$param_utilization)
  end
end

