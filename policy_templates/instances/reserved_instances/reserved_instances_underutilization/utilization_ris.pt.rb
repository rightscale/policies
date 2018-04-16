name "Reserved Instances Utilization"
rs_pt_ver 20180301
short_description "A policy that sends email notifications when utilization falls below a threshold"
long_description "Version: 0.1"

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
    path join(["/reco/orgs", rs_org_id, "aws_reserved_instances"], "/")
  end
end

escalation "alert" do
  email $param_email do
    subject_template "Reserved Instance Utilization"
    body_template "reserved instance utilization:"
  end
end

policy "ri_utilization" do
  validate $reservations do
    template <<-EOS

{ range data }
* Account: { $.account_name }({ $.account_id })
* Region: {$.region}
* Instance Type: {$.instance_type}
* Instance Count: {$.instance_count}
* Start Time: {$.start_time}
* End Time: {$.end_time}
----------------------------
{ end }
EOS

    escalate $alert
    check lt(data["utilization"]["utilization_percentage"],$param_utilization)
	end
end

