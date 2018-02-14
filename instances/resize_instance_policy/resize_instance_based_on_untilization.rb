name "RightSize"
rs_ca_ver 20161221
short_description "Downsize instances based on cpu and memory utilization"
long_description "Version: 0.1"
import "sys_log"
import "mailer"

##################
# User inputs    #
##################

parameter "param_tag" do
  category "Tag"
  label "Tag to Check"
  type "string"
  default "rs_monitoring:resize=1"
end

parameter "param_metric" do
    category "Metric"
    label "Utilization metric to monitor"
    type "string"
    allowed_values "Idle_CPU", "Free_Memory"
end

parameter "param_action" do
  category "Configuration"
  label "Policy Action"
  type "string"
  allowed_values "Report Only","Report and Resize"
  default "Report Only"
end

parameter "param_threshold" do
  category "Configuration"
  label "Metric Threshold Percentage"
  type "number"
  default "0"
end

parameter "param_duration" do
  category "Configuration"
  label "Metric Threshold Duration"
  type "number"
  default "1"
end

parameter "param_email" do
  category "Contact"
  label "Email addresses (separate with commas)"
  type "string"
end

mapping "alert_conditions" do {
  "Idle_CPU" => {
    "file" => "cpu-0/cpu-idle",
    "variable" => "value" },
  "Free_Memory" => {
    "file" => "memory/memory-free",
    "variable" => "value"
  }
} end

##################
# Operations     #
##################

operation "launch" do
  description "Search for resizing opportunities"
  definition "launch"
end

operation "find_servers_needing_downsize" do
  definition 'find_servers_needing_downsize'
  description "checks for servers down"
end

operation "add_alert_specs" do
  definition 'add_alert_specs'
  description "Adds Alert Specs to Servers"
end

define launch($param_tag,$param_metric,$alert_conditions,$param_email,$param_threshold,$param_duration,$param_action) return $param_metric do 
  call add_alert_specs($param_tag,$param_metric,$alert_conditions,$param_email,$param_threshold,$param_duration,$param_action)
  $time = now() + (60*2)
  rs_ss.scheduled_actions.create(
                                  execution_id:       @@execution.id,
                                  name:               "Checking for Servers Needing Downsize",
                                  action:             "run",
                                  operation:          { "name": "find_servers_needing_downsize" },
                                  first_occurrence:   $time,
                                  recurrence:         "FREQ=MINUTELY;INTERVAL=60"
                                )
  $time = now() + (60*30)
  rs_ss.scheduled_actions.create(
                                  execution_id:       @@execution.id,
                                  name:               "Adding Alert Specs",
                                  action:             "run",
                                  operation:          { "name": "add_alert_specs" },
                                  first_occurrence:   $time,
                                  recurrence:         "FREQ=MINUTELY;INTERVAL=30"
                                )
end

define add_alert_specs($param_tag,$param_metric,$alert_conditions,$param_email,$param_threshold,$param_duration,$param_action) do
  call get_resource_by_tag('instances',["rs_monitoring:util=v2",$param_tag]) retrieve @resources
  foreach @resource in @resources do
    call create_alert_spec(@resource,$param_metric,$alert_conditions,$param_threshold,$param_duration)
  end
end

#creates the alert spec 
define create_alert_spec(@server,$param_metric,$alert_conditions,$param_threshold,$param_duration)  do
  call sys_log.set_task_target(@@deployment)
  call sys_log.summary("Alert Spec")
  if !contains?(@server.alert_specs().name[], [join(["rightsizing_policy_",$param_metric])])
  #coverted to object to insert metric info
    @spec = { 
      "namespace": "rs_cm",
      "type": "alert_specs",
      "fields": {
        "name": join(["rightsizing_policy_",$param_metric]),
        "description": "used by the resizing policy",
        "file": map($alert_conditions, $param_metric, "file"),
        "variable": map($alert_conditions, $param_metric, "variable"),
        "condition": ">",
        "threshold": $param_threshold,
        "duration": $param_duration,
        "vote_tag": "rightsize",
        "vote_type": "shrink",
        "subject_href": @server.href
      }
    }
    call start_debugging()
    call sys_log.detail("Alert_Spec:" + to_s(to_object(@spec)))
    sub on_error: stop_debugging() do
      provision(@spec)
    end
    call stop_debugging()
  else
    call sys_log.detail(join(["Instance: ", @server.name, " already has alert spec"]))
  end
end

define find_servers_needing_downsize($param_email,$param_action,$param_metric,$alert_conditions,$param_threshold,$param_duration) do
  call find_account_name() retrieve $account_name
  call find_account_number() retrieve $$account_number
  call find_shard() retrieve $$shard
  $endpoint = "http://policies.services.rightscale.com"
  call get_resource_by_tag('instances', ["rs_vote:rightsize=shrink"]) retrieve @resources
  call mailer.create_csv_with_columns($endpoint,["Account Name","Instance Name","Status","link"] ) retrieve $filename
  $$csv_filename = $filename
  $shrink_count = size(@resources)
  foreach @resource in @resources do
    # Get server access link
    $server_access_link_root = 'unknown'
    sub on_error: skip do
      call get_server_access_link(@resource.href, 'instances') retrieve $server_access_link_root
    end
    if $server_access_link_root == null
      $server_access_link_root = 'unknown'
    end
    if $param_action == "Report and Resize"
      call resize_by_instance_family(@resource,"down",$param_metric,$alert_conditions,$param_threshold,$param_duration) retrieve $status,@new_resource
      @resource = @new_resource
    else
      $status = @resource.state
    end
    call mailer.update_csv_with_rows($endpoint, $filename, [$account_name,@resource.name,$status,$server_access_link_root]) retrieve $filename
  end
  $body = join(["We found ", $shrink_count, " instances that can be resized"])
  call mailer.send_html_email($endpoint, $param_email,"policy-cat@services.rightscale.com", "Resize Instances Report", $body, $filename, "text") retrieve $response

  if $response['code'] != 200
    raise 'Failed to send email report: ' + to_s($response)
  end
end

define find_account_name() return $account_name do
  $session_info = rs_cm.sessions.get(view: "whoami")
  $acct_link = select($session_info[0]["links"], {rel: "account"})
  $acct_href = $acct_link[0]["href"]
  $account_name = rs_cm.get(href: $acct_href).name
end

define find_account_number() return $account_id do
  $session = rs_cm.sessions.index(view: "whoami")
  $account_id = last(split(select($session[0]["links"], {"rel":"account"})[0]["href"],"/"))
end

# Returns the RightScale shard for the account the given CAT is launched in.
define find_shard() return $shard_number do
  $account = rs_cm.get(href: "/api/accounts/" + $$account_number)
  $shard_number = last(split(select($account[0]["links"], {"rel":"cluster"})[0]["href"],"/"))
end

define get_server_access_link($instance_href, $resource_type) return $server_access_link_root do
  $rs_endpoint = "https://us-"+$$shard+".rightscale.com"

  $instance_id = last(split($instance_href, "/"))

  if $resource_type == 'instances'
    $response = http_get(
      url: $rs_endpoint+"/api/" + $resource_type + "?ids=" + $instance_id,
      headers: {
        "X-Api-Version": "1.6",
        "X-Account": $$account_number
      }
    )
    $instances = $response["body"]
    $instance_of_interest = select($instances, { "href" : $instance_href })[0]

    if $instance_of_interest["legacy_id"] == null
      $legacy_id = "unknown"
    else
      $legacy_id = $instance_of_interest["legacy_id"]
    end

    $data = split($instance_href, "/")
    $cloud_id = $data[3]
    $server_access_link_root = "https://my.rightscale.com/acct/" + $$account_number + "/clouds/" + $cloud_id + "/"+ $resource_type +"/" + $legacy_id
  elsif $resource_type == 'volumes'
    $server_access_link_root = "https://my.rightscale.com" + $instance_href
  end
end

define get_resource_by_tag($resource_type, $tags) return @resources do
  $$resources = rs_cm.tags.by_tag(resource_type: $resource_type, tags: $tags, match_all: true)
  if empty?(first($$resources))
    raise "No Servers found with Tag"
  else
    # by_tag returns an array of an array of a hash and the hrefs for the resources are in the "links"
    $$resources_1 = first(first($$resources))["links"]
    # initialize a collection of servers
    @resources = rs_cm.$resource_type.empty()
    foreach $resource in $$resources_1 do
      @resources = rs_cm.get(href: $resource["href"]) + @resources
    end
  end
end

define resize_by_instance_family(@instance,$resize_operation,$param_metric,$alert_conditions,$param_threshold,$param_duration) return $status,@new_resource do
  call sys_log.set_task_target(@@deployment)
  call sys_log.summary(join(["resizing instance: ", @instance.name]))
  task_label(join(["resizing instance: ", @instance.name]))
  call return_instance_size(@instance,$resize_operation) retrieve $new_size
  if $new_size != null
    task_label(join(["resizing instance: ", @instance.name, " to the new size: ", $new_size]))
    call sys_log.detail(join(["resizing instance: ", @instance.name, " to the new size: ", $new_size]))
    @current_server = @instance.parent()
    task_label("stopping instance")
    @instance.stop()
    task_label("sleeping until instance stopped")
    sleep_until(@current_server.state == 'provisioned')
    call sys_log.detail("instance is provisioned")
    @current_instance = @current_server.current_instance()
    call sys_log.detail(join(["name: ", @current_instance.name, " href: ", @current_instance.href]))
    @cloud = @current_instance.cloud()
    @new_instance_type = first(@cloud.instance_types(filter: ["name=="+$new_size]))
    @current_instance.update(instance: { instance_type_href: @new_instance_type.href })
    @current_instance.start()
    task_label("sleeping until instance started")
    sleep_until(@current_instance.state == 'operational')
    call sys_log.detail("instance started")
    call create_alert_spec(@current_instance,$param_metric,$alert_conditions,$param_threshold,$param_duration)
    $status = join(["Server: ", @current_server.name, " Size: ", $new_size, " State: ", @current_instance.state])
    call sys_log.detail($status)
    @new_resource = @current_instance
  else
    $status = "Can Not Be Resized"
    call sys_log.detail($status)
    @new_resource = @instance
  end
end

define return_instance_size(@instance,$resize_operation) return $new_size do
  @cloud = @instance.cloud()
  $json = http_get({ url: 'https://raw.githubusercontent.com/rightscale/policies/resizing_policy_PS-619/instances/resize_instance_policy/instance_types.json'})
  $instance_types_vote_map = from_json($json['body'])
  $new_size = $instance_types_vote_map[@cloud.cloud_type][@instance.instance_type().name][$resize_operation]
end

define start_debugging() do
  if $$debugging == false || logic_and($$debugging != false, $$debugging != true)
    initiate_debug_report()
    $$debugging = true
  end
end

define stop_debugging() do
  if $$debugging == true
    $debug_report = complete_debug_report()
    call sys_log.detail($debug_report)
    $$debugging = false
  end
end