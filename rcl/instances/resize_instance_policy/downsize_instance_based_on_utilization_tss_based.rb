name "RightSize - Downsize - TSS"
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

parameter "param_action" do
  category "Configuration"
  label "Policy Action"
  type "string"
  allowed_values "Report Only","Report and Resize"
  default "Report Only"
end

parameter "cpu_param_threshold" do
  category "Configuration"
  label "CPU Metric Threshold Percentage"
  type "number"
  default "0"
end

parameter "cpu_param_duration" do
  category "Configuration"
  label "CPU Metric Threshold Duration in minutes"
  type "number"
  default "5"
end

parameter "mem_param_threshold" do
  category "Configuration"
  label "Memory Metric Threshold Percentage"
  type "number"
  default "0"
end

parameter "mem_param_duration" do
  category "Configuration"
  label "Memory Metric Threshold Duration"
  type "number"
  default "5"
end

parameter "param_email" do
  category "Contact"
  label "Email addresses (separate with commas)"
  type "string"
end

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

define launch($param_tag,$param_email,$param_action,$cpu_param_duration,$cpu_param_threshold,$mem_param_duration,$mem_param_threshold) return $cpu_param_duration,$cpu_param_threshold,$mem_param_duration,$mem_param_threshold do
  call sys_log.set_task_target(@@deployment)
  call sys_log.summary("RightSize - Downsize - TSS")
  # call find_servers_needing_downsize($param_email,$param_action,$cpu_param_duration,$cpu_param_threshold,$mem_param_duration,$mem_param_threshold,$param_tag)
  $time = now() + (60*5)
  rs_ss.scheduled_actions.create(
                                  execution_id:       @@execution.id,
                                  name:               "Checking for Servers Needing Downsize",
                                  action:             "run",
                                  operation:          { "name": "find_servers_needing_downsize" },
                                  first_occurrence:   $time,
                                  recurrence:         "FREQ=MINUTELY;INTERVAL=60"
                                )
end

define find_servers_needing_downsize($param_email,$param_action,$cpu_param_duration,$cpu_param_threshold,$mem_param_duration,$mem_param_threshold,$param_tag) do
  call find_account_name() retrieve $account_name
  call find_account_number() retrieve $$account_number
  call find_shard() retrieve $$shard
  $endpoint = "http://policies.services.rightscale.com"
  call get_resource_by_tag('instances', [$param_tag]) retrieve @resources
  call sys_log.detail(join(["tagged resources: ", to_s(to_object(@resources))]))
  @resizeable_instance_collection = rs_cm.instances.empty()
  foreach @resource in @resources do
    call get_monitoring_data(@resource,$cpu_param_duration,$cpu_param_threshold,$mem_param_duration,$mem_param_threshold) retrieve $result
    if $result == true
      @resizeable_instance_collection = @resizeable_instance_collection + @resource
    end
  end
  call sys_log.detail(join(["resizeable resources: ", to_s(to_object(@resizeable_instance_collection))]))
  if size(@resizeable_instance_collection) > 0
    call mailer.create_csv_with_columns($endpoint,["Account Name","Instance Name","Original Size","New Size","Status","link"] ) retrieve $filename
    $$csv_filename = $filename
    $shrink_count = size(@resizeable_instance_collection)
    foreach @resource in @resizeable_instance_collection do
      task_label("resizable instance found:" + @resource.name)
      call sys_log.detail("resizable instance found:" + @resource.name)
      $old_size = @resource.instance_type().name
      # Get server access link
      $server_access_link_root = 'unknown'
      sub on_error: skip do
        call get_server_access_link(@resource.href, 'instances') retrieve $server_access_link_root
      end
      if $server_access_link_root == null
        $server_access_link_root = 'unknown'
      end
      if $param_action == "Report and Resize"
        call resize_by_instance_family(@resource,"down") retrieve $status,@new_resource
        @resource = @new_resource
      else
        $status = @resource.state
      end
      call mailer.update_csv_with_rows($endpoint, $filename, [$account_name,@resource.name,$old_size,@resource.instance_type().name,$status,$server_access_link_root]) retrieve $filename
    end
    $body = join(["We found ", $shrink_count, " instances that can be resized"])
    call mailer.send_html_email($endpoint, $param_email,"policy-cat@services.rightscale.com", "Resize Instances Report", $body, $filename, "text") retrieve $response

    if $response['code'] != 200
      raise 'Failed to send email report: ' + to_s($response)
    end
  end
end

define get_monitoring_data(@instance,$cpu_param_duration,$cpu_param_threshold,$mem_param_duration,$mem_param_threshold) return $result do
  $rs_endpoint = "us-"+$$shard+".rightscale.com"
  $true_counts = 0
  $result = false
  $cpu_duration = (($cpu_param_duration * 60) * -1)
  call sys_log.detail("cpu_duration:" + $cpu_duration)
  $mem_duration = (($mem_param_duration * 60) * -1)
  call sys_log.detail("mem_duration:" + $mem_duration)
  task_label("CPU Monitoring Pull")
  $cpu_response = http_request(
    verb: "get",
    host: $rs_endpoint,
    https: true,
    href: join([@instance.href, "/monitoring_metrics/cpu-0:cpu-idle/data"]),
    headers: { "X-Api-Version": "1.5" },
    query_strings: { "start": $cpu_duration, "end": "0" }
  )
  $cpu_body = $cpu_response["body"]
  $points = $cpu_body["variables_data"][0]["points"]
  $points_array = []
  $median_points = 0
  foreach $point in $points do
    if $point != null
      $points_array << $point
      $median_points = $median_points + $point
    end
  end
  $median = $median_points / size($points_array)
  if $median >= $cpu_param_threshold
    $true_counts = $true_counts + 1
  end

task_label("Memory Monitoring Pull")
  $memory_response = http_request(
    verb: "get",
    host: $rs_endpoint,
    https: true,
    href: join([@instance.href, "/monitoring_metrics/memory:memory-free/data"]),
    headers: { "X-Api-Version": "1.5" },
    query_strings: { "start": $mem_duration, "end": "0" }
  )
  $memory_body = $memory_response["body"]
  $points = $memory_body["variables_data"][0]["points"]
  $points_array = []
  $median_points = 0
  foreach $point in $points do
    if $point != null
      $points_array << $point
      $median_points = $median_points + $point
    end
  end
  $median = $median_points / size($points_array)
  if $median >= $mem_param_threshold
    $true_counts = $true_counts + 1
  end
  if $true_counts == 2
    $result = true
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

define resize_log(@instance, $message) do
  call sys_log.set_task_target(@@deployment)
  call sys_log.summary(join(["resizing instance: ", @instance.name]))
  call sys_log.detail($message)
  call sys_log.set_task_target(@instance)
  call sys_log.detail($message)
  call sys_log.set_task_target(@instance.deployment())
  call sys_log.detail($message)
end

define resize_by_instance_family(@instance,$resize_operation) return $status,@new_resource do
  call sys_log.set_task_target(@@deployment)
  call sys_log.summary(join(["resizing instance: ", @instance.name]))
  task_label(join(["resizing instance: ", @instance.name]))
  call return_instance_size(@instance,$resize_operation) retrieve $new_size
  if $new_size != null
    task_label(join(["resizing instance: ", @instance.name, " to the new size: ", $new_size]))
    call sys_log.detail(join(["resizing instance: ", @instance.name, " to the new size: ", $new_size]))
    call sys_log.set_task_target(@instance)
    call sys_log.detail(join(["resizing instance: ", @instance.name, " to the new size: ", $new_size]))
    call sys_log.set_task_target(@@deployment)
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
  $json = http_get({ url: 'https://raw.githubusercontent.com/rightscale/policies/GMQ/rcl/instances/resize_instance_policy/instance_types.json'})
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