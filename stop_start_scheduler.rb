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

# Tie to an existing native Self-Service Schedule Name:
#    instance:ss_schedule=<schedule name>

# Use a CM pre-defined (non-SS) schedule, e.g.:
#    instance:cm_schedule=weekdays7to7

# CM scheduling convention (when the instance should be running):
#     instance:cm_schedule=<days><hour-to-hour>

# supported:
# <days> - weekdays, alldays
# <hour-to-hour> - <0-23>-to-<0-23>

# CM supported (non-SS) schedules:
# - instance:cm_schedule=weekdays7to7
#       stop conditions:
#       - after 7pm, before 7am
#       start conditions:
#       - after 7am, before 7pm
#       - not on sat or sun
# - instance:cm_schedule=weekdays9to5
#       stop conditions:
#       - after 5pm, before 9am
#       start conditions:
#       - after 5am, before 9pm
#       - not on sat or sun

###
# Global Mappings
###
mapping 'cm_instance_schedule_map' do {
  'Weekdays 7am to 7pm' => {
    'tag_value' => 'weekdays7to7',
    'active_days' => 'MO,TU,WE,TH,FR',
    'term_after' => '19:00',
    'start_before' => '7:00'
  },
  'Weekdays 9am to 5pm' => {
    'tag_value' => 'weekdays9to5',
    'active_days' => 'MO,TU,WE,TH,FR,SA,SU',
    'term_after' => '17:00',
    'start_before' => '9:00'
  },
} end

# likely not needed as abbreviation is simply first two letters upcased
# iCal format
mapping 'days' do {
  'Monday' => {
    'abbrev' => 'MO'
  },
  'Tuesday' => {
    'abbrev' => 'TU'
  },
  'Wednesday' => {
    'abbrev' => 'WE'
  },
  'Thursday' => {
    'abbrev' => 'TH'
  },
  'Friday' => {
    'abbrev' => 'FR'
  },
  'Saturday' => {
    'abbrev' => 'SA'
  },
  'Sunday' => {
    'abbrev' => 'SU'
  },
} end

###
# User Inputs
###
parameter 'scheduler_type' do
  label 'Scheduler'
  description 'The type of scheduler to use (only CM currently implemented).'
  type 'string'
  default 'Cloud Management-based'
  # ss not yet implemented
  # allowed_values 'Cloud Management-based', 'Self-Service Schedule'
  allowed_values 'Cloud Management-based'
end

parameter 'schedule_name' do
  category 'Scheduler Policy'
  label 'Schedule'
  description "The schedule to use when using the 'Cloud Management-based' scheduler."
  type 'string'
  default 'Weekdays 7am to 7pm'
  allowed_values 'Weekdays 7am to 7pm', 'Weekdays 9am to 5pm'
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

define run_scan($cm_instance_schedule_map, $scheduler_type, $schedule_name, $scheduler_enforce_strict, $scheduler_tags_exclude, $scheduler_servers_only, $scheduler_dry_mode, $polling_frequency, $debug_mode) do
  if $scheduler_enforce_strict == 'true'
    # TODO: not yet implemented/supported
    # all instances are candidates for a stop action
    sub task_label: "Getting all instances" do
      @instances = rs_cm.servers.get()
    end
  else
    # only instances tagged with a schedule are candidates for either a stop or start action
    $search_tags = [join(['instance:cm_schedule=', map($cm_instance_schedule_map, $schedule_name, 'tag_value')])]
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

        # debug/example of getting the tag originally searched with
        # $cm_schedule_tag = select($instance_tags, { "name": "/instance:cm_schedule/" })
        # $cm_schedule = split($cm_schedule_tag[0]['name'], '=')[1]

        # get the instance
        call audit_log('fetching instance ' + $instance_href, $instance_href)
        @instance = rs_cm.get(href: $instance_href)
        call debug_audit_log('@instance', to_s(to_object(@instance)))

        $stoppable = /^(running|operational|stranded)$/
        $startable = /^(stopped|provisioned)$/

        # determine if instance should be stopped or started based on:
        # 1. inside or outside schedule
        # 2. current operational state
        # TODO: UTC to RFC datetime with timezone
        # WIP!!
        $current_datetime = now()
        $current_day = strftime($current_datetime, "%A")
        $current_time = strftime($current_datetime, "%R")
        call audit_log('$day is ' + $current_day + ', $time is ' + $current_time, '')

        if @instance.state =~ $stoppable
          # stop the instance
          if $scheduler_dry_mode != 'true'
            call audit_log('stopping ' + @instance.href)
            @instance.stop()
          else
            call audit_log('dry mode, skipping stop of ' + @instance.href, @instance.href)
          end
        elsif @instance.state =~ $startable
          # stop the instance
          if $scheduler_dry_mode != 'true'
            call audit_log('starting ' + @instance.href)
            @instance.start()
          else
            call audit_log('dry mode, skipping start of ' + @instance.href, @instance.href)
          end
        else
          call audit_log('instance is neither in a stoppable or startable state')
        end
      end
    else
      call audit_log('no instances found with needed scheduling tag(s), sleeping', to_s($results))
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
define launch_scheduler($cm_instance_schedule_map, $scheduler_type, $schedule_name, $scheduler_enforce_strict, $scheduler_tags_exclude, $scheduler_servers_only, $scheduler_dry_mode, $polling_frequency, $debug_mode) do
  if $debug_mode == 'true'
    $$debug = true
  end

  call get_my_timezone() retrieve $timezone
  call audit_log('my timezone: ' + $timezone, $timezone)

  call setup_scheduled_scan($polling_frequency, $timezone)

  call run_scan($cm_instance_schedule_map, $scheduler_type, $schedule_name, $scheduler_enforce_strict, $scheduler_tags_exclude, $scheduler_servers_only, $scheduler_dry_mode, $polling_frequency, $debug_mode)
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
