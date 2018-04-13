name 'Schedule Instances Policy'
rs_pt_ver 20180301
type "policy"
short_description "![RS Policy](https://goo.gl/RAcMcU =64x64)\n
This automated policy CAT will Stop and Start instances"
long_description "Version: 1.0"

permission "perm_instances" do
  label     "List, stop and start instances"
  actions   "rs_cm.index", "rs_cm.stop","rs_cm.start"
  resources "rs_cm.instances"
end

parameter "param_action" do
  type "string"
  label "Stop and Start the instance or only Stop"
  allowed_values "Start and Stop", "Stop"
end

parameter "param_include_tag" do
  type "string"
  label "instance tag used to filter instances that must validate policy"
end

parameter "param_exclude_tag" do
  type "string"
  label "instance tag used to filter instances that are excluded from policy"
end

parameter "param_escalate_to" do
  type "string"
  label "Email address to send escalation emails to"
end

auth "rs", type: "rightscale"

resources "instances_us_east_1", type: "rs_cm.instances" do
  cloud_href "/api/clouds/1"
end

resources "instances_us_west_2", type: "rs_cm.instances" do
  cloud_href "/api/clouds/6"
end

datasource "instances_us_east_1" do
    field "href",   val(@instances_us_east_1,'href')
    field "id",     val(@instances_us_east_1,'resource_uid')
    field "name",   val(@instances_us_east_1,'name')
    field "state",  val(@instances_us_east_1,'state')
    field "cloud",  val(@instances_us_east_1,'cloud')
end

datasource "instances_us_west_2" do
    field "href",   val(@instances_us_west_2,'href')
    field "id",     val(@instances_us_west_2,'resource_uid')
    field "name",   val(@instances_us_west_2,'name')
    field "state",  val(@instances_us_east_1,'state')
    field "cloud",  val(@instances_us_west_2,'cloud')
end
datasource "instances" do
  run_script $merge_instances, $instances_us_east_1, $instances_us_west_2
end

script "merge_instances", type: "javascript" do
  parameters "instances_1", "instances_2"
  result "instances"
  code <<-EOF
  var instances = instances_1.concat(instances_2);
  EOF
end

escalation "handle_instances" do
  email $param_escalate_to do
    subject_template "Scheduled Instances" # There will be a default template we use.
    body_template     <<-EOS
    Instances
    The following instances are unattached:
    { range data }
    * Region: { $.cloud }
    * Name: { $.name }
    * State: { $.state }
    * HREF: { $.href }
    { end }
    EOS
  end
  run "schedule_instances", data, $param_action
end

policy "schedule_instances_policy" do
  validate $instances do
    template <<-EOS
    Instances
    The following instances are unattached:
    { range data }
    * Region: { $.cloud }
    * Name: { $.name }
    * State: { $.state }
    * HREF: { $.href }
    { end }
    EOS
    escalate $handle_instances
  end
end

define schedule_instances($data,$param_action) do
  if $param_action=="Stop"
    foreach $item in $data do
        @instance = rs_cm.get(href: $item['href'])
        @instance.stop
    end
  end
  if $param_action=="Start and Stop"
    foreach $item in $data do
        @instance = rs_cm.get(href: $item['href'])
        if @instance.state =~ /provisioned|stopped/
          @instance.start
        end
        if @instance.state =~ /running|operational/
          @instance.stop
        end
    end
  end
end
