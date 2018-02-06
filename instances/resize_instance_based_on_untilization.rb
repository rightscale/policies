name "RightSize"
rs_ca_ver 20161221
short_description "Downsize instances based on cpu and memory utilization"

 
define find_rs_monitored_instances() do 

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
        @@alert_specs = rs_cm.alertspecs.empty() 

        @@hello =  rs_cm.alert_specs.create(
            alert_spec:{
                name:         "rightsizing_policy" + @@execution.id,
                description:  "Triggers autoscaling if users ssh into instances",
                file:         "users/users",
                variable:     "users", 
                condition:    ">", 
                threshold:    "0",
                duration:     "1",
                vote_type:    "grow",
                subject_href:  @server.current_instance().href
                vote_tag:     "node"
                
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