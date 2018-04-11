name 'Schedule Instances Policy'
#rs_ca_ver 20160622
short_description "![RS Policy](https://goo.gl/RAcMcU =64x64)\n
This automated policy CAT will Stop and Start instances"
long_description "Version: 1.0"

permission "perm_instances" do
  label     "List, stop and start instances"
  actions   "rs_cm.index", "rs_cm.stop" "rs_cm.start"
  resources "rs_cm.instances"
end

# parameter "param_action" do
#   type "string"
#   label "Stop and Start the instance or only Stop"
#   allowed_values "Start and Stop", "Stop"
# end
#
# parameter "param_include_tag" do
#   type "string"
#   label "instance tag used to filter instances that must validate policy"
# end
#
# parameter "param_exclude_tag" do
#   type "string"
#   label "instance tag used to filter instances that are excluded from policy"
# end
#
# parameter "param_escalate_to" do
#   type "string"
#   label "Email address to send escalation emails to"
# end

# auth "rs", type: "rightscale"
#
# resources "instances", type: "rs_cm.instances" do
# end

# datasource "instances" do
#     field "href",   val(@instances,'href')
#     field "id",     val(@instances,'resource_uid')
#     field "name",   val(@instances,'name')
#     field "state",  val(@instances,'state')
#     field "cloud",  val(@instances,'cloud')
# end
#
# escalation "handle_instances" do
#   template <<-EOS
# Instances
# The following instances are unattached:
# { range data }
# * Region: { $.cloud }
# * Name: { $.name }
# * State: { $.state }
# * HREF: { $.href }
# { end }
# EOS
#   email $param_escalate_to do
#     subject_template "Scheduled Instances" # There will be a default template we use.
#   end
#   run "schedule_instances", data, $param_action
# end
#
# policy "schedule_instances_policy" do
#   validate $instances do
#     escalate $handle_instances
#   end
# end
#
# define schedule_instances($data,$param_action) do
#   if $param_action=="stop"
#     foreach $item in $data do
#         @instance = rs_cm.get(href: $item['href'])
#         @instance.stop
#     end
#   end
#   if $param_action=="Start and Stop"
#     foreach $item in $data do
#         @instance = rs_cm.get(href: $item['href'])
#         if @instance.state =~ "/provisioned|stopped/"
#           @instance.start
#         end
#         if @instance.state =~ /running|operational/
#           @instance.stop
#         end
#     end
#   end
# end
