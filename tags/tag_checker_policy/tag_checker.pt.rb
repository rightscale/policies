name "Tag Checker"
rs_pt_ver 20180101
short_description "![Tag](https://s3.amazonaws.com/rs-pft/cat-logos/tag.png)\n
Check for a tag and report which instances and volumes are missing it."


##################
# Permissions    #
##################

permission do
  label "Access Volumes"
  resources "rs_cm.volumes"
  actions "rs_cm.destroy", "rs_cm.index"
end

permission do
  label "Access Instances"
  resources "rs_cm.instances"
  actions "rs_cm.destroy", "rs_cm.index"
end

##################
# User inputs    #
##################

parameter "param_tag_key" do
  category "User Inputs"
  label "Tags' Namespace:Keys List"
  type "string"
  description "Comma-separated list of Tags' Namespace:Keys to audit. For example: \"ec2:project_code\" or \"bu:id\"."
  # allow namespace:key or nothing
  allowed_pattern '^([a-zA-Z0-9-_]+:[a-zA-Z0-9-_]+,*|)+$'
end

parameter "param_email" do
  category "Contact"
  label "Email addresses (separate with commas)"
  type "string"
  # allow list of comma seperated email addresses or nothing
  allowed_pattern '^([a-zA-Z0-9-_.]+[@]+[a-zA-Z0-9-_.]+[.]+[a-zA-Z0-9-_]+,*|)+$'
end

# Auth defines how to authenticate the request made to retrieve the data source.
auth "rs", type: "rightscale"


resources "instances", type: "rs_cm.instances" do
  #all clouds ??
  cloud $cloud # The cloud to filter on.
end


# Data source defines what data source is used for validating the conditions of a policy.
data_source "instances" do
  field "href",    field(@instances, "href")
  field "state", field(@instances, "state")
end


