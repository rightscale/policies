name "RightSize Policy Template"
rs_pt_ver 20180301
short_description "A policy that resizes instances based on monitoring metrics"
long_description "Version: 0.1"

permission "instance" do
  actions "rs_cm.index", "rs_cm.show", "rs_cm.data"
  resources "rs_cm.instances", "rs_cm.monitoring_metrics"
end

parameter "max_memory_percent" do
  type "number"
  label "Maximum memory usage allowed before scaling up instance type"
end

parameter "min_memory_percent" do
  type "number"
  label "Minimum memory usage allowed before scaling down instance type"
end

parameter "instance_tag" do
  type "string"
  label "instance tag used to filter instances that must validate policy"
end

parameter "escalate_to" do
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
    field "state",  val(@instances_us_west_2,'state')
    field "cloud",  val(@instances_us_west_2,'cloud')
end
# produces an array of objects [{ "average_mem"=>44, "id"=>"123bc", "type"=>"m1.small" }]

datasource "instance_metrics" do
  request do
    auth $rs
    host rs_cm_host
    path join([val(@instances_us_east_1,'href'), "monitoring_metrics", $monitoring_slug, "data"], "/")
    query "start", -300
    query "end", 0
    header "X-API-Version", "1.5"
  end
  result do
    field "href",        val(@instances_us_east_1,'href')
    field "average_mem", avg(jmes_path(data, "variables_data[].points[]"))
    field "id",          val(@instances_us_east_1,'resource_uid')
    field "type",        val(@instances_us_east_1,'instance_type')
  end
end

policy "rightsize" do
  validate $instance_metrics do
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
    escalate $downsize
    #check_over "2h", lt(data["average_mem"], $min_memory_percent)
  end
  validate $instance_metrics do
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
    escalate $upsize
    #check_over "2h", gt(data["average_mem"], $max_memory_percent)
  end
end

escalation "upsize" do
  email $escalate_to do
    body_template <<-EOS
  { range data }
  instance {$.id} of type {$.type} is using more than {$max_memory_percent}% memory and will be upgraded.
  {- end }
  EOS
  end
  run "right_size_instance", true, data
end

escalation "downsize" do
  email $escalate_to do
    subject_template "instance {data.id} of type {data.type} is using less than {$min_memory_percent}% memory and will be downgraded."
  end
  run "right_size_instance", false, data
end

# RCL definition that can be used in escalations
define right_size_instance($up, $instance_href) do
   @instance = rs_cm.get(href: $instance_href)
end
