name "RightSize"
rs_ca_ver 20161221
short_description "Downsize instances based on cpu and memory utilization"


##################
# User inputs    #
##################


parameter "param_metric" do
    category "Metric"
    label "Utilization metric to monitor"
    type "string"
    allowed_values "Idle CPU | cpu-0/cpu-idle.value", "Free Memory | memory/memory-free.value"
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



define launch($param_metric) return $param_metric do 

#split inputs for metric info
$$metric = last(split($param_metric, "|"))
$$metric_variable = first(split($$metric, "/"))

@all_instances = rs_cm.instances.index(filter:["state==operational"])
      
    foreach @server in @all_instances do 
      $tag = "rs_monitoring:edwin"  #edwin for testing, rs_monitoring:status should be the tag
        call has_tag(@server,$tag) retrieve $tagged
    end
end

#check for monitoring tag and call create alert spec 
define has_tag(@server, $tag) return $tagged do
  call get_tags_for_resource(@server) retrieve $tags_on_server
  
  $href_tag = map $current_tag in $tags_on_server return $tag do
    if $current_tag =~ $tag
      #check to see if alert spec exists if it does, check if  is triggered. filter on "name=rightsizing_policy_" + @@execution.id , else create
      call create_alert_spec(@server) 
      $tagged = "true"
    end
  end
end

    
#creates the alert spec 
define create_alert_spec(@server)  do

  #coverted to object to insert metric info
  @spec = rs_cm.alert_specs.empty()
  $spec_object=to_object(@spec)
  $spec_object["details"][0]="name=rightsizing_policy_" + @@execution.id
  $spec_object["details"][1]="description=used by the resizing policy"
  $spec_object["details"][2]="file=" + $$metric
  $spec_object["details"][3]="variable=" + $$metric_variable
  $spec_object["details"][4]="condition=>"
  $spec_object["details"][5]="threshold=0"  #need to get from inputs - percentages
  $spec_object["details"][6]="duration=1"   #need to get from inputs minimum 1 day  
  $spec_object["details"][7]="vote_tag=rightsize"
  $spec_object["details"][8]="vote_type=shrink"
  $spec_object["details"][9]=@server.href
   
  

 @server.alert_specs().create(alert_spec:$spec_object)

end

    
    
define get_tags_for_resource(@resource) return $tags do
  
  $tags = []
  $tags_response = rs_cm.tags.by_resource(resource_hrefs: [@resource.href])
  $inner_tags_ary = first(first($tags_response))["tags"]
  $tags = map $current_tag in $inner_tags_ary return $tag do
    $tag = $current_tag["name"]
  end
  $tags = $tags
end