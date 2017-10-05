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

name 'Shutdown Scheduler'
short_description "![RS Policy](https://goo.gl/RAcMcU =64x64)\n
Stops or terminates instances based on the existance of specific tags containing a date and time."
long_description "![RS Policy](https://goo.gl/RAcMcU =64x64)
This automated policy CloudApp will find instances specifically tagged for shutdown and or terminate.

This policy CAT will find instances specifically tagged for shutdown or termination and applies that action once the shutdown date in the tag value is reached or exceeded.

It is recommended to run the CloudApp using the \"Always On\" schedule
unless you want to explicitly exclude times that instances could be shutdown.

For documentation including usage, see the [README](https://github.com/rs-services/policy-cats/blob/master/README.md).

- **Author**: Chris Fordham <chris.fordham@rightscale.com>
- **Team**: RightScale Cloud Solutions Engineering"

rs_ca_ver 20160622

###
# Global Mappings
###

###
# User Inputs
###
parameter 'polling_frequency' do
  category 'Advanced Options'
  label 'Polling Frequency'
  description 'The frequency to check instances for possible shutdown actions (in minutes).'
  type 'number'
  default 5
  allowed_values 5, 10, 15, 30, 60, 120
end

parameter 'exclude_tags' do
  category 'Advanced Options'
  label 'Tags to exclude'
  description 'Explicitly exclude any instances with these tags (comma separated).'
  type 'list'
  default 'instance:scheduler_exclude=true,instance:immutable=true'
end

parameter 'dry_mode' do
  category 'Advanced Options'
  label 'Dry Mode'
  type 'string'
  default 'false'
  allowed_values 'true', 'false'
end

parameter 'debug_mode' do
  category 'Advanced Options'
  label 'Debug Mode'
  type 'string'
  default 'false'
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

define action_instance($search_tags) do
  $time = now()
  $curr_epoc_time = strftime($time, "%s")
  $actionable_state = /^(running|operational|stranded)$/
  $action = split(to_s($search_tags), ':')[1]
  $action = split(to_s($action), '_')[0]

  $tagged_resources = rs_cm.tags.by_tag(resource_type: 'instances', tags: $search_tags, match_all: 'false')
  if type($tagged_resources[0][0]) == 'object'
    call audit_log(to_s(size($tagged_resources[0][0]['links'])) + ' candidate instance(s) found', to_s($tagged_resources))

    foreach $tagged_resource in $tagged_resources[0][0]['links'] do
      $instance_href = $tagged_resource['href']
      $resource_tags = rs_cm.tags.by_resource(resource_hrefs: [$instance_href])
      $instance_tags = first(first($resource_tags))['tags']
      $instance_action_tag = select($instance_tags, { "name": "/" + $search_tags[0] + "/" })

      call debug_audit_log('instance_tags: ' + ($instance_href), to_s($instance_tags))
      call debug_audit_log('instance_action_tag: ' + to_s($instance_href), to_s($instance_action_tag))

      $action_time_value = split(to_s($instance_action_tag), '=')[1]
      $action_time_value = split(to_s($action_time_value), '"')[0]
      $action_time_epoc = strftime(to_d($action_time_value), "%s")

      call debug_audit_log('Time value for ' + $action + ' tag is: ' + $action_time_value, '')
      call debug_audit_log('epoc time is ' + $curr_epoc_time + ', action epoc time is ' + $action_time_epoc, '')

      if $curr_epoc_time > $action_time_epoc
        call debug_audit_log('If running, it is time to ' + $action + ' ' + $instance_href, '')
        $tags_excluded = split($exclude_tags, ',')
        # if we find a tag that makes the instance excluded, flag for exclusion
        $excluded = false

        foreach $tag_excluded in $tags_excluded do
          #call debug_audit_log('checking if instance ' + $first_instance_href + ' is excluded by tag ' + $tag_excluded, to_s($tagged_resource))
          if contains?($instance_tags, [{ name: $tag_excluded }])
            $excluded = true
            call debug_audit_log('instance ' + $instance_href + ' is excluded by tag ' + $tag_excluded, '')
          else
            call debug_audit_log('instance ' + $instance_href + ' is not excluded by tag ' + $tag_excluded, '')
          end
        end

        # continue if no exclusion by tag
        if $excluded != true
          call debug_audit_log('fetching instance ' + $instance_href, $instance_href)
          @instance = rs_cm.get(href: $instance_href)
          call debug_audit_log('@instance', to_s(to_object(@instance)))

          # stop the instance
          if $dry_mode != 'true'
            if ($action == 'shutdown' && @instance.state =~ $actionable_state)
              call audit_log('instance ' + @instance.href + ' set for ' + $action, to_s(@instance))
              @instance.stop()
              call debug_audit_log($action + ' task initiated, ' + $action + ' in progress', to_s(@instance))
            elsif $action == 'terminate'
              call audit_log('instance ' + @instance.href + 'set for ' + $action, to_s(@instance))
              @instance.terminate()
              call debug_audit_log($action + ' completed', to_s(@instance))
            else
              call debug_audit_log('instance marked for ' + $action + ' not in required state: running, operational or stranded', '')
            end
          else
            call audit_log('dry mode, skipping stop of ' + @instance.href, $action)
          end
        else
          call audit_log('No ' + $action + ' action taken due to tag exclusion', $instance_href)
        end
      else
        call audit_log('No ' + $action + ' action taken due to time not reached', $instance_href)
      end
    end
  else
    call audit_log('No instances found with required instance:' + $action + '_datetime= tag', '')
  end
end

define get_user_preference_infos() return @user_preference_infos do
  @user_preference_infos = rs_ss.user_preference_infos.get(filter: ['user_id==me'])
end

define get_my_timezone() return $timezone do
  @user_preference_infos = rs_ss.user_preference_infos.get(filter: ['user_id==me'])
  @user_prefs = rs_ss.user_preferences.get(filter: ['user_id==me', 'user_preference_info_id==' + @user_preference_infos.id])
  if @user_prefs.value
    $timezone = @user_prefs.value
  else
    $timezone = @user_preference_infos.default_value
  end
end

define run_scan($polling_frequency, $exclude_tags, $dry_mode, $debug_mode) do
  call audit_log('instance scan started', '')

  if $debug_mode == 'true'
    $$debug = true
    call audit_log('debug mode enabled', $debug_mode)
  end
  if $dry_mode == 'true'
    $$drymode = true
    call audit_log('dry mode enabled', $dry_mode)
  end

  call get_my_timezone() retrieve $timezone

  $search_tags = ['instance:shutdown_datetime']
  call action_instance($search_tags)

  $search_tags = ['instance:terminate_datetime']
  call action_instance($search_tags)

end


define setup_scheduled_scan($polling_frequency, $timezone) do
  sub task_label: "Setting up scan scheduled task" do
    # use http://coderstoolbox.net/unixtimestamp/ to calculate
    # we assume setting in past works ok because calculating the first
    # real schedule would be non-trivial
    $recurrence = 'FREQ=MINUTELY;INTERVAL=' + $polling_frequency
    # RFC-2822 Mon, 25 Jul 2016 03:00:00 +10:00
    $first_occurrence = "2017-01-01T01:00:00+10:00"
    #$time = now()
    #$first_occurrence = strftime($time, "%Y-%m-%dT%H:%M:%S +0000")

    call audit_log("scan schedule rrule", join([$recurrence, " with first on ", $first_occurrence]))

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
define launch_scheduler($polling_frequency, $exclude_tags, $dry_mode, $debug_mode) do
  call get_my_timezone() retrieve $timezone

  call audit_log('using timezone: ' + $timezone, $timezone)

  call setup_scheduled_scan($polling_frequency, $timezone)

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
operation 'launch' do
  description 'Launch the scheduler.'
  definition 'launch_scheduler'
  label 'Launch'
end

operation 'run_scan' do
  description 'Run the instance scan manually.'
  definition 'run_scan'
  label 'Run Instance Scan'
end

operation 'terminate' do
  description 'Terminate the scheduler.'
  definition 'terminate_scheduler'
end
