name "RightSize"
rs_ca_ver 20161221
short_description "Downsize instances based on cpu and memory utilization"


##################
# User inputs    #
##################


parameter "param_action" do
    category "Metric"
    label "Utilization metric to monitor"
    type "string"
    allowed_values "CPU", "Memory"
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
 


  operation "launch" do
    description "Find long running instances"
    definition "launch"
  end



define launch() do 

    @all_instances = rs_cm.instances.index(filter:["state==operational"])
      
      
      foreach @server in @all_instances do 
        $tag = "rs_monitoring:edwin"  #edwin for testing, rs_monitoring:status should be the tag
          call has_tag(@server, $tag) retrieve $tagged
      end
    end
    
    define has_tag(@server, $tag) return $tagged do
      call get_tags_for_resource(@server) retrieve $tags_on_server
      
      $href_tag = map $current_tag in $tags_on_server return $tag do
        if $current_tag =~ $tag
          call create_alert_spec(@server) 
          $tagged = "true"
        end
      end
    end
    
    
    define create_alert_spec(@server) do
        rs_cm.alert_specs.create
            (
                alert_spec:{
                    name:         "rightsizing_policy" + @@execution.id,
                    description:  "used by the resizing policy",
                    file:         "users/users",
                    variable:     "users", 
                    condition:    ">", 
                    threshold:    "0",
                    duration:     "1", 
                    subject_href:  @server.href
                    
                
                }
            )
      
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