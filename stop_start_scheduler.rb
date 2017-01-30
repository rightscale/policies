# Copyright 2017 RightScale
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

name 'Start/Stop Scheduler'
short_description "![RS Policy](https://goo.gl/RAcMcU =64x64)

Starts or stops instances based on a given schedule."
long_description "![RS Policy](https://goo.gl/RAcMcU =64x64)
This automated policy CloudApp will find instances specifically tagged for start or stop/terminate
based on specific schedules.

It is recommened to run this CloudApp with the Always On schedule unless you want to explicitly exclude times that instances could be started or stopped.

- **Author**: Chris Fordham <chris.fordham@rightscale.com>
- **Team**: RightScale Cloud Solutions Engineering"

rs_ca_ver 20160622

# To be a candidate for the Start/Stop Scheduler, any instance/server
# must have the following tag on it's current instance:
#    instance:scheduler=true
#    instance:schedule=<name of ss schedule>
#        e.g. instance:schedule=7am-11pm Weekdays

###
# Global Mappings
###

###
# User Inputs
###
parameter 'ss_schedule_name' do
  category 'Scheduler Policy'
  label 'Schedule Name'
  description "The self-service schedule to use (this needs to match an existing schedule within the 'Schedule Manager')."
  type 'string'
  min_length 1
end

parameter 'scheduler_tags_exclude' do
  category 'Scheduler Policy'
  label 'Tags Exclude'
  description 'Explicitly exclude any instances with these tags (comma separated).'
  type 'list'
  default 'instance:scheduler_exclude=true,instance:immutable=true'
end

parameter 'scheduler_servers_only' do
  category 'Scheduler Policy'
  label 'RightScale-managed servers only'
  # commented-out as it doesn't display very nice with the checkbox in UI atm
  # description 'Only include RightScale-managed servers in the scheduling.'
  type 'string'
  default 'false'
  allowed_values 'true', 'false'
end

parameter 'scheduler_enforce_strict' do
  category 'Scheduler Policy'
  label 'Stop instances outside the schedule without a schedule tag'
  type 'string'
  default 'false'
  allowed_values 'true', 'false'
end

parameter 'timezone_override' do
  category 'Advanced Options'
  label 'Timezone Override'
  description "By default, the self-service user's timezone is used."
  type 'string'
end

parameter 'rrule_override' do
  category 'Advanced Options'
  label 'RRULE Override'
  description "By default, the the iCal RRULE is taken from the scheduler policy."
  type 'string'
end

parameter 'polling_frequency' do
  category 'Advanced Options'
  label 'Polling Frequency'
  description 'The regularity to check instances for possible scheduling actions (in minutes).'
  type 'number'
  default 5
  allowed_values 5, 10, 15, 30, 60, 120
end

parameter 'scheduler_dry_mode' do
  category 'Advanced Options'
  label 'Dry Mode'
  type 'string'
  # currently always on due to dev/test
  default 'true'
  allowed_values 'true', 'false'
end

parameter 'debug_mode' do
  category 'Advanced Options'
  label 'Debug Mode'
  type 'string'
  # currently always on due to dev/test
  default 'true'
  allowed_values 'true', 'false'
end

###
# Local Definitions
###
define audit_log($summary, $details) do
  rs_cm.audit_entries.create(
    notify: "None",
    audit_entry: {
      auditee_href: @@deployment,
      summary: $summary,
      detail: $details
    }
  )
end

define debug_audit_log($summary, $details) do
  if $$debug == true
    rs_cm.audit_entries.create(
      notify: "None",
      audit_entry: {
        auditee_href: @@deployment,
        summary: $summary,
        detail: $details
      }
    )
  end
end

define get_schedule_by_name($ss_schedule_name) return @schedule do
  @schedules = rs_ss.schedules.index()
  @schedule = select(@schedules, { "name": $ss_schedule_name })
end

define window_active($start_hour, $start_minute, $start_rule, $stop_hour, $stop_minute, $stop_rule, $tz) return $window_active do
  $params = {
    verb: 'get',
    host: 'gm2zkzuvdb.execute-api.ap-southeast-2.amazonaws.com',
    https: true,
    href: '/window_check',
    query_strings: {
      'start_hour': $start_hour,
      'start_minute': $start_minute,
      'start_rule': $start_rule,
      'stop_minute': $stop_minute,
      'stop_hour': $stop_hour,
      'stop_rule': $stop_rule,
      'tz': $tz
    }
  }
  call audit_log('window active $params', to_s($params))
  $response = http_request($params)
  call audit_log('window active $response', to_s($response))
  $body = $response['body']
  call audit_log('window active $body', to_s($body))

  $window_active = to_b($body['event_active'])
end

define run_scan($ss_schedule_name, $scheduler_enforce_strict, $scheduler_tags_exclude, $scheduler_servers_only, $scheduler_dry_mode, $polling_frequency, $debug_mode, $timezone_override, $rrule_override) do
  if size($timezone_override) > 0
    $timezone = $timezone_override
  else
    call get_my_timezone() retrieve $timezone
  end

  # get the ss schedule by name and check if the event window is active
  call get_schedule_by_name($ss_schedule_name) retrieve @schedule
  $start_rule = @schedule.start_recurrence['rule']
  $start_hour = @schedule.start_recurrence['hour']
  $start_minute = @schedule.start_recurrence['minute']
  $stop_rule = @schedule.stop_recurrence['rule']
  $stop_hour = @schedule.stop_recurrence['hour']
  $stop_minute = @schedule.stop_recurrence['minute']
  call window_active($start_hour, $start_minute, $start_rule, $stop_hour, $stop_minute, $stop_rule, $timezone) retrieve $window_active

  if $scheduler_enforce_strict == 'true'
    # TODO: not yet implemented/supported
    # all instances are candidates for a stop action
    sub task_label: "Getting all instances" do
      @instances = rs_cm.servers.get()
    end
  else
    # only instances tagged with a schedule are candidates for either a stop or start action
    $search_tags = [join(['instance:schedule=', $ss_schedule_name])]
    call audit_log('$search_tags', to_s($search_tags))

    $by_tag_params = {
      match_all: 'true',
      resource_type: 'instances',
      tags: $search_tags
    }
    call audit_log('searching by tag', to_s($by_tag_params))
    $tagged_resources = rs_cm.tags.by_tag($by_tag_params)
    call audit_log('$tagged_resources', to_json($tagged_resources))

    if type($tagged_resources[0][0]) == 'object'
      call audit_log(to_s(size($tagged_resources[0][0]['links'])) + ' candidate instance(s) found', to_s($tagged_resources))
      foreach $tagged_resource in $tagged_resources[0][0]['links'] do
        $instance_href = $tagged_resource['href']
        $resource_tags = rs_cm.tags.by_resource(resource_hrefs: [$instance_href])

        $instance_tags = first(first($resource_tags))['tags']
        call audit_log('tags: ' + $instance_href, to_s($instance_tags))

        # get the instance
        call audit_log('fetching instance ' + $instance_href, $instance_href)
        @instance = rs_cm.get(href: $instance_href)
        call debug_audit_log('@instance', to_s(to_object(@instance)))

        $stoppable = /^(running|operational|stranded)$/
        $startable = /^(stopped|provisioned)$/

        # determine if instance should be stopped or started based on:
        # 1. inside or outside schedule
        # 2. current operational state

        if ! $window_active
          call audit_log('schedule window is currently not active', '')
        end

        if (! $window_active && @instance.state =~ $stoppable)
          # stop the instance
          if $scheduler_dry_mode != 'true'
            call audit_log('stopping ' + @instance.href, to_s(@instance))
            @instance.stop()
          else
            call audit_log('dry mode, skipping stop of ' + @instance.href, @instance.href)
          end
        end

        if ($window_active && @instance.state =~ $startable)
          # start the instance
          if $scheduler_dry_mode != 'true'
            call audit_log('starting ' + @instance.href, to_s(@instance))
            @instance.start()
          else
            call audit_log('dry mode, skipping start of ' + @instance.href, @instance.href)
          end
        end
      end
    else
      call audit_log('no instances found with needed scheduling tag(s)', to_s($results))
    end
  end
end

define get_my_timezone() return $timezone do
  @user_prefs = rs_ss.user_preferences.get(filter: ["user_id==me"])
  $timezone = @user_prefs.value
end

define setup_scheduled_scan($polling_frequency, $timezone) do
  sub task_label: "Setting up scan scheduled task" do
    # use http://coderstoolbox.net/unixtimestamp/ to calculate
    # we assume setting in past works ok because calculating the first
    # real schedule would be non-trivial
    $recurrence = 'FREQ=MINUTELY;INTERVAL=' + $polling_frequency
    # RFC-2822 Mon, 25 Jul 2016 03:00:00 +10:00
    $first_occurrence = "2016-07-25T03:00:00+10:00"

    call audit_log("scan schedule", join([$recurrence, " with first on ", $first_occurrence]))

    rs_ss.scheduled_actions.create(
                                    execution_id:     @@execution.id,
                                    name:             "Run instance scan",
                                    action:           "run",
                                    operation:        { "name": "run_scan" },
                                    recurrence:       $recurrence,
                                    timezone:         $timezone,
                                    first_occurrence: $first_occurrence
                                  )
  end
end

###
# Launch Definition
###
define launch_scheduler($ss_schedule_name, $scheduler_enforce_strict, $scheduler_tags_exclude, $scheduler_servers_only, $scheduler_dry_mode, $polling_frequency, $debug_mode, $timezone_override, $rrule_override) do
  if $debug_mode == 'true'
    $$debug = true
  end

  call get_my_timezone() retrieve $timezone
  call audit_log('my timezone: ' + $timezone, $timezone)

  call setup_scheduled_scan($polling_frequency, $timezone)

  # uncomment to run a scan on cloudapp start
  #call run_scan($cm_instance_schedule_map, $ss_schedule_name, $scheduler_enforce_strict, $scheduler_tags_exclude, $scheduler_servers_only, $scheduler_dry_mode, $polling_frequency, $debug_mode, $timezone_override, $rrule_override)
end

###
# Terminate Definition
###
define terminate_scheduler() do
  call audit_log('scheduler terminated', '')
end

###
# Operations
###
operation "launch" do
  description "Launch the scheduler."
  definition "launch_scheduler"
  label "Launch"
end

operation "run_scan" do
  description "Run the instance scan manually."
  definition "run_scan"
end

operation "terminate" do
  description "Terminate the scheduler."
  definition "terminate_scheduler"
end
