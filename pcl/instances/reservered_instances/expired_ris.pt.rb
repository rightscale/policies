name "Expired Reserved Instances"
rs_pt_ver 20180101
short_description "A policy that sends email notifications before reserved instances expire"

permission do
  label "Access Optima Resources"
  resources "rs_optima.aws_reserved_instances"
  actions "rs_optima.index"
end

parameter "heads_up_days" do
  type "number"
  label "Number of days to prior to expiration date to trigger incident"
end

parameter "escalate_to" do
  type "string"
  label "Email address to send escalation emails to"
end

auth "rs", type: "rightscale"

data_source "reservations" do
  auth $rs
  request do
    host "optima.rightscale.com"
    path join(["/reco/orgs", rs_org, "aws_reserved_instances"], "/")
  end
end

escalation "alert" do
   template <<-EOS
Reserved Instance Expiration

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

   email $escalate_to
end

policy "ri_expiration" do
  validate $reservations do
    escalate $alert
    check lt(sub(to_d(data["end_time"]), now), prod($heads_up_days, 24*3600))
	end
end

