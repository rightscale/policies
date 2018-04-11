permission do
  # TBD
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

resources "instances", type: "rs_cm.instances" do
  cloud $cloud
  tag $instance_tag
end

# produces an array of objects [{ "average_mem"=>44, "id"=>"123bc", "type"=>"m1.small" }]

data_source "instance_metrics" do
  auth $rs
  request do
    host rs_cm_host
    path join([@instances.href, "monitoring_metrics", $monitoring_slug, "data"], "/")
    query "start", -300
    query "end", 0
    header "X-API-Version", "1.5"
  end
  result do
    field "href",        @instances.href
    field "average_mem", avg(jmes_path(data, "variables_data[].points[]"))
    field "id",          @instances.resource_uid
    field "type",        @instances.instance_type
  end
end

policy "rightsize" do
  validate $instance_metrics do
    escalate $downsize
    check_over "2h", lt(data["average_mem"], $min_memory_percent)
  end
  validate $instance_metrics do
    escalate $upsize
    check_over "2h", gt(data["average_mem"], $max_memory_percent)
  end
end

# Do we need this?

# data_source "instance_metrics" do
#   auth $rs
#   url concat(@instances.href, "/monitoring_metrics?title=memory")
#   id    "href":        @instances.href
#   field "average_mem": average(data)
# end

# data_source "reported_instances" do
#   auth $rs
#   url concat($instance_metrics.href, "/monitoring_metrics?title=memory")
#   id    "href":        data.href
#   field "average_mem": average(data)
#   field "id":          $instance_metrics.resource_uid
#   field "type":        data.instance_type
# end

# policy "rightsize" do
#   validate $instances, escalate @downsize, $reported_instances do
#     over "2h", lesser_than(data.average_mem, $min_memory_percent)
#   end
#   validate $instances, escalate @upsize, $reported_instances do
#     over "2h", greater_than(data.average_mem, $max_memory_percent)
#   end
# end

escalation "upsize" do
  template <<-EOS
  { range data }
  instance {$.id} of type {$.type} is using more than {$max_memory_percent}% memory and will be upgraded.
  {- end }
  EOS
  email $escalate_to
  run "right_size_instance", true, data["href"]
end

escalation "downsize" do
  template "instance {data.id} of type {data.type} is using less than {$min_memory_percent}% memory and will be downgraded."
  email $escalate_to
  run "right_size_instance", false, data["href"]
end

# RCL definition that can be used in escalations
define right_size_instance($up, $instance_href) do
   @instance = rs_cm.get(href: $instance_href)
   # ...
end

