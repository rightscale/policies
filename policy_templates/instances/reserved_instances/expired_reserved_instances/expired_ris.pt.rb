name "Expired Reserved Instances"
rs_pt_ver 20180301
type "policy"
short_description "A policy that sends email notifications before reserved instances expire"
long_description "Version 0.1"
severity "medium"
category "Cost"

permission "optima" do
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

datasource "reservations" do
  request do
    auth $rs
    host "optima.rightscale.com"
    path join(["/reco/orgs", rs_org_id, "aws_reserved_instances"], "/")
  end
  result do
    encoding "json"
    collect do
      field "end_datetime", jmes_path(response,"{{end_datetime}}")
    end
  end
end

escalation "alert" do
  email $escalate_to do
    subject_template "Reserved Instance Expiration"
    body_template "Reserved Instance Expiration"
  end
end

policy "ri_expiration" do
  validate_each $reservations do
    summary_template "Reserved instances are nearing expiration."
    detail_template <<-EOS
Reserved Instance Expiration
{{ range data }}
* Account: {{ .account_name }}({{ .account_id }})
* Region: {{.region}}
* Instance Type: {{.instance_type}}
* Instance Count: {{.instance_count}}
* End Time: {{.end_datetime}}
----------------------------
{{ end }}
EOS

    escalate $alert
    check gt(dec(to_d(val(item, "end_datetime"), now), prod($heads_up_days, 24*3600)))
  end
end