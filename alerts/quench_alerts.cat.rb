name 'Quench Alerts'
rs_ca_ver 20160622
short_description "Quenches alerts on a resource for a specified amount of time"

#Copyright 2017 RightScale
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.

#RightScale Cloud Application Template (CAT)

# DESCRIPTION
# Quenches alerts on a resource for a specified amount of time
#


##################
# User inputs    #
##################

parameter "resource_href" do
  category "User Inputs"
  label "RightScale Resource HREF to quench alerts on"
  description "This parameter accepts deployment, server_array, server, or instance HREFs"
  type "string"
end
parameter "alert_name_regex" do
  category "User Inputs"
  label "Quench alerts containing this string in the name"
  description "Leave blank to quench all alerts on resource. Example value: cpu"
  type "string"
end
parameter "quench_duration_minutes" do
  category "User Inputs"
  label "Duration [minutes] to quench the alert for.  Alert will auto-enable after this duration."
  description "Example value: 60 [quench alert(s) for 1 hour]"
  type "number"
  default 60
  min_value 1
end



####################
# OPERATIONS       #
####################
operation "launch" do
  description "This CloudApp will quench alerts on a resource"
  definition "launch_quench_resource"
end

define launch_quench_resource($resource_href,$alert_name_regex,$quench_duration_minutes)  do
    call quench_resource($resource_href,$alert_name_regex,$quench_duration_minutes)
end

##################
# Definitions    #
##################
define quench_resource($resource_href,$alert_name_regex,$quench_duration_minutes) do
  @resource = rs_cm.get(href: $resource_href)
  $resource_type = type(@resource)
  
  # Currently supported resource types: rs_cm.instances, rs_cm.servers, rs_cm.server_arrays, rs_cm.deployments
  $supported_resources = ["rs_cm.instances","rs_cm.servers","rs_cm.server_arrays","rs_cm.deployments"]
  task_label('Checking if resource is a supported resource time that can have alerts quenched')
  if any?($supported_resources,$resource_type)
    task_label('Resource type is supported, retrieving resource links')
    @resource = @resource.get()
    task_label('Retrieving alerts')
    @resource_alerts = @resource.alerts()
    task_label('Quenching alerts that match regex')
    call quench_alerts(@resource_alerts, $alert_name_regex, $quench_duration_minutes)
  else
    raise "Resource Type '"+$resource_type+"' cannot have alerts quenched. Accepted Types: "+to_s($supported_resources)
  end

  
end
define quench_alerts(@server_alerts, $alert_name_regex, $quench_duration_minutes) do
  task_label('Setting up counters and collections for quenched alerts')
  $$quenched_alerts_count = 0
  #  @@quenched_alerts = rs_cm.alerts.empty()  # Not needed unless we're going to return the alerts that were quenched
  task_label('Looping through alerts')
  concurrent foreach @alert in @server_alerts do
    task_label('Getting alert name from alert_spec')
    $alert_name = @alert.alert_spec().name
    task_label('Checking if alert name matches alert_name_regex')
    if $alert_name_regex == "" || $alert_name =~ $alert_name_regex
      task_label('Quenching '+ $alert_name +' alert -- matches alert_name_regex parameter ["'+$alert_name_regex+'"]')
      @alert.quench(duration:to_s(to_n($quench_duration_minutes)*60))
#      @@quenched_alerts = @@quenched_alerts + @alert  # Not needed unless we're going to return the alerts that were quenched
      $$quenched_alerts_count = $$quenched_alerts_count +1
    else
      task_label('Skipping '+ $alert_name +' alert -- does not match alert_name_regex parameter ["'+$alert_name_regex+'"]')
    end
  end

  task_label('Quenched '+$$quenched_alerts_count+' alerts matching "'+$alert_name_regex+'"')
end