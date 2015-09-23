name 'Halliburton_University_Program_Singleton'
rs_ca_ver 20131202
short_description 'CAT for Halliburton University Program'
resource 'server', type: 'server' do
	name 'Halliburton_Windows2008R2'
	cloud 'EC2 us-east-1'
	ssh_key 'RS_Halliburton_Default'
	security_groups "default", "All RDP"
	server_template find("Halliburton Base ServerTemplate for Windows (v14.1)")
end

#OUTPUTS
output "public" do
	label "Server IP Address"
	category "Outputs"
	#default_value @server.public_ip_address
end

output "rdp" do
	label "RDP Link"
	category "Outputs"
	description "RDP to server"
end

#OPERATIONS
operation "start" do
	definition "restart_server"
	description "Start the server"
	output_mappings do {
		$rdp => $rdp_link,
		$public => $server_ip,
	}end
end

operation "stop" do
	definition "stop_server"
	description "Stop the server"
end

operation "enable" do
	definition "get_rdp_link"
	description "RDP to server"
	output_mappings do {
		$rdp => $rdp_link,
		$public => $server_ip,
	}end
end

operation "launch" do
	definition "launch_server"
	description "launch server and run singleton check"
end

#DEFINITIONS
define stop_server(@server) do
	task_label("Stopping the server.")
	if ( @server.current_instance().state == "operational")
		@server.current_instance().stop()
	end
end

define start_server(@server) return @server do
	task_label("Starting the server.")
	if ( @server.state =~ /^(stopped|provisioned)$/)
		sub timeout: 5m, on_error: retry do
		@server.current_instance().start()
		end
	end
	sleep_until(@server.state == "operational")
end

define get_rdp_link(@server) return $rdp_link, $server_ip do
	
	$rs_endpoint = "https://us-4.rightscale.com"
    
	# Find the instance href for this server
	$instance_href = @server.current_instance().href
	#rs.audit_entries.create(notify: "None", audit_entry: { auditee_href: @server, summary: to_s($instance_href), detail: ""})
 
	# Use the API 1.6 instances index call mainly to get the legacy ID which is what is used for the RDP link.
	$response = http_get(
		url: $rs_endpoint+"/api/instances",
		headers: { 
		"X-Api-Version": "1.6",
		"X-Account": "81843"
		}
	)
  
	# all the instances in the account
	$instances = $response["body"]
  
	# the instance that matches the server's instance href
	$instance_of_interest = select($instances, { "href" : $instance_href })[0]
  
	# the all important legacy id needed to create the RDP link
	$legacy_id = $instance_of_interest["legacy_id"]  
	#rs.audit_entries.create(notify: "None", audit_entry: { auditee_href: @server, summary: join(["legacy id: ", $legacy_id]), detail: ""})
	
	# get the instance's cloud ID also
	$cloud_id = $instance_of_interest["links"]["cloud"]["id"]
    
	# now build the rdp link of the form: https://my.rightscale.com/acct/ACCOUNT_NUMBER/clouds/CLOUD_ID/instances/INSTANCE_LEGACY_ID/rdp
	$rdp_link = "https://my.rightscale.com/acct/81843/clouds/"+$cloud_id+"/instances/"+$legacy_id+"/rdp"

	$server_ip = to_s(@server.public_ip_addresses[0])
	#rs.audit_entries.create(notify: "None", audit_entry: { auditee_href: @server, summary: "rdp link", detail: $rdp_link})
end

define restart_server(@server) return @server, $rdp_link, $server_ip do
	call start_server(@server) retrieve @server
	
	call get_rdp_link(@server) retrieve $rdp_link, $server_ip
	
	#$server_ip = @server.public_ip_address
end

# Returns all tags for a specified resource. Assumes that only one resource
# is passed in, and will return tags for only the first resource in the collection.
#
# @param @resource [ResourceCollection] a ResourceCollection containing only a
#   single resource for which to return tags
#
# @return $tags [Array<String>] an array of tags assigned to @resource
define get_tags_for_resource(@resource) return $tags do
  $tags = []
  $tags_response = rs.tags.by_resource(resource_hrefs: [@resource.href])
  $inner_tags_ary = first(first($tags_response))["tags"]
  $tags = map $current_tag in $inner_tags_ary return $tag do
    $tag = $current_tag["name"]
  end
  $tags = $tags
end

# Fetches the email/username of the user who launched "this" cloud app using the default tags set on a
# deployment created by SS.
# selfservice:launched_by=foo@bar.baz
#
# @return [String] The email/username of the user who launched the current cloud app
define sys_get_launched_by() return $launched_by do
  call get_tags_for_resource(@@deployment) retrieve $tags_on_deployment
  $href_tag = map $current_tag in $tags_on_deployment return $tag do
    if $current_tag =~ "(selfservice:launched_by)"
      $tag = $current_tag
    end
  end

  if type($href_tag) == "array" && size($href_tag) > 0
    $tag_split_by_value_delimiter = split(first($href_tag), "=")
    $launched_by = last($tag_split_by_value_delimiter)
  else
    $launched_by = "N/A"
  end

end

# Creates a "log" entry in the form of an audit entry.  The target of the audit
# entry defaults to the deployment created by the CloudApp, but can be specified
# with the "auditee_href" option.
#
# @param $summary [String] the value to write in the "summary" field of an audit entry
# @param $options [Hash] a hash of options where the possible keys are;
#   * detail [String] the message to write to the "detail" field of the audit entry. Default: ""
#   * notify [String] the event notification catgory, one of (None|Notification|Security|Error).  Default: None
#   * auditee_href [String] the auditee_href (target) for the audit entry. Default: @@deployment.href
#
# @see http://reference.rightscale.com/api1.5/resources/ResourceAuditEntries.html#create
define sys_log($summary,$options) do
  $log_default_options = {
    detail: "",
    notify: "None",
    auditee_href: @@deployment.href
  }

  $log_merged_options = $options + $log_default_options
  rs.audit_entries.create(
    notify: $log_merged_options["notify"],
    audit_entry: {
      auditee_href: $log_merged_options["auditee_href"],
      summary: $summary,
      detail: $log_merged_options["detail"]
    }
  )
end

define launch_server(@server) return @server do

  ####################################
  # Perform the Singleton Check first
  ####################################

  call sys_get_launched_by() retrieve $launched_by_user
 
  $launched_by_tag = "selfservice:launched_by="+$launched_by_user
  
  $by_tag_params = {
    match_all: "true",
    resource_type: "deployments",
    tags: [$launched_by_tag]
  }

  # TODO: Syslog those params.
  call sys_log("by_tag params", {detail: to_json($by_tag_params)})

  $existing_deployments = rs.tags.by_tag($by_tag_params)
  $links = first(first($existing_deployments))["links"]
  call sys_log("Found deployments", {detail: to_json($links)})

  # There will always be one, because this one counts
  if size($links) > 1
    raise "Only one instance is allowed per user!"
  end
  ####################################
  # /Perform the Singleton Check first
  ####################################

  concurrent return @server do
	provision(@server)
  end

end
