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
# Finds instances that are underutilized based on CPU and memory utilization then alerts and/or reports them.
#

name 'Underutilized Instance Reporter'
rs_ca_ver 20160622
short_description "![RS Policy](https://goo.gl/RAcMcU =64x64)\n
This automated policy CAT will identify instances that are deemed underutilized and send a report."

long_description "![RS Policy](https://goo.gl/RAcMcU =64x64)\n
This automated policy CloudApp will report underutilized instances by
analyzing cloudwatch metrics that have CPU utilization below input threshold.\n

It is recommended to run this CloudApp with the Always On schedule
unless you want to explicitly exclude times that instances could be stopped.\n

**This app assumes you have the admin role on your account and have AWS&#95;ACCESS&#95;KEY&#95;ID & AWS&#95;SECRET&#95;ACCESS&#95;KEY set in RightScale credentials.**
"

##################
# User inputs    #
##################

parameter 'email_recipients' do
  category 'Email addresses'
  label 'Send report as email to (separate with commas):'
  type 'string'
end

parameter "action" do
  category "Advanced Options"
  label "Action. What to do when underutilized instances are detected"
  type "string"
  allowed_values "email_only","shutdown_and_email","terminate_and_email"
  default "email_only"
end

parameter "clouds" do
  category "Advanced Options"
  label "what clouds?. Let me know what coulds you want scanned."
  type "string"
  allowed_values "AWS","GoogleCompute","Azure"
  default "AWS"
end

parameter 'low_cpu_threshold' do
  category 'Advanced Options'
  label 'Report on CPU utilization below this percentage'
  type 'number'
  default '10'
end

parameter 'period' do
  category 'Advanced Options'
  label 'sample period. Remember that the maximum datapoints returned from AWS CloudWatch is 1440. In combination with days to sample, reduce if error is returned.'
  type 'number'
  allowed_values 300, 3600
  default 3600
end

parameter 'days_back' do
  category 'Advanced Options'
  label 'Number of days to sample. Remember that the maximum datapoints returned is 1440. In combination with sample period, reduce if error is returned.'
  type 'number'
  allowed_values 1, 2, 4, 7, 14, 15, 63
  default 14
end

parameter 'tags_to_exclude' do
  category 'Advanced Options'
  label 'Instance tags to exclude'
  description 'Explicitly exclude any instances that contain these tags (comma separated).'
  type 'list'
  default 'instance:env=dev,instance:lowutil=allow'
end

parameter 'polling_frequency' do
  category 'Advanced Options'
  label 'Polling Frequency'
  description 'The frequency to run the report (in minutes). eg: daily=1440, weekly=10080'
  type 'number'
  default 1440
  allowed_values 5, 1440, 10080
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

##################
# Definitions    #
##################
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
        summary: '[debug] ' + $summary,
        detail: $details
      }
    )
  end
end

define get_instances() return $instances do
  #$allowed_states = /^(running|operational|stranded|booting|pending)$/
  $allowed_states = /^(running|operational|stranded)$/
  call find_shard() retrieve $shard_number
  call find_account_number() retrieve $account_number

  $rs_endpoint = "https://us-"+$shard_number+".rightscale.com"

  $response = http_get(
    url: $rs_endpoint+"/api/instances?view=full",
    headers: {
      "X-Api-Version": "1.6",
      "X-Account": $account_number
    }
  )

  $instances=[]
  $all_instances = $response["body"]
  foreach $instance in $all_instances do
    if $instance['state'] =~ $allowed_states
      $cloud_id = split($instance['href'], '/')[3]
      $server_access_link_root = "https://my.rightscale.com/acct/" + $account_number + "/clouds/" + $cloud_id + "/instances/" + $instance['legacy_id']
      $instances << {name: $instance['name'], href: $instance['href'], resource_uid: $instance['resource_uid'], state: $instance['state'], tags:$instance['tags'], server_access_link_root: $server_access_link_root}
    end
  end
  $instance_count = size($instances)
  call audit_log(to_s($instance_count) + ' instance/s found in allowed state', to_s($instances))
end

define find_underutilized_instances($tags_to_exclude, $period, $days_back, $low_cpu_threshold) return $underutilized_instances do
  call get_instances() retrieve $instances

  if size($instances[0]) > 0
    $underutilized_instances=[]
    foreach $instance in $instances do
      $instance_href = $instance['href']
      $instance_tags=[]
      $instance_tags << $instance['tags']
      call debug_audit_log('instance_tags for instance:' + to_s($instance_href), to_s($instance_tags) )
      $excluded = false
      $tags_excluded = split($tags_to_exclude, ',')
      foreach $tag in $instance_tags do
        foreach $tag_excluded in $tags_excluded do
          if contains?($tag, [ $tag_excluded ])
            $excluded = true
          end
        end
      end
      if $excluded == false
        call debug_audit_log('instance ' + to_s($instance_href) + ' is not excluded by tag', '')
        $resource_uid = $instance['resource_uid']
        call audit_log('Checking cloudwatch utilization metrics for AWS instance ' + $resource_uid, to_s($instance))
        $cpu_metric = 'CPUUtilization'
        call cloudwatch_api($resource_uid,$cpu_metric,$period,$days_back) retrieve $average
        call debug_audit_log('Average CPU utilization metrics for instance ' + $resource_uid + ' is ' + $average, '')
        if $average < $low_cpu_threshold
          call audit_log('CPU utilization for AWS instance ' + $resource_uid + ' is below the ' + $low_cpu_threshold + '% threshold so a report will be sent.', '')
          #Add instance to an array so it can be sent in one report.
          $underutilized_instances  << { id: $resource_uid, href: $instance['href'], name: $instance['name'], average_cpu: $average, server_access_link_root: $instance['server_access_link_root'] }
        end
      else
        call audit_log('instance ' + to_s($instance_href) + ' is excluded by tag', '')
      end
    end
  else
    call audit_log('No valid instances found', '')
  end
end

define cloudwatch_api($resource_uid,$cpu_metric,$period,$days_back) return $average do
  $time = now()
  $before_time = $time - (3600 * 24 * $days_back)
  $end_time = strftime($time, "%Y-%m-%dT%H%%3A%M%%3A%SZ")
  $start_time = strftime($before_time, "%Y-%m-%dT%H%%3A%M%%3A%SZ")
  #$the_body = 'Statistics.member.1=Average&Namespace=AWS%2FEC2&Period=' + $period + '&Dimensions.member.1.Value=' + $resource_uid + '&Version=2010-08-01&StartTime=' + $start_time + '&Action=GetMetricStatistics&Dimensions.member.1.Name=InstanceId&EndTime=' + $end_time + '&MetricName=' + $cpu_metric
  $the_body = 'Statistics.member.1=Maximum&Namespace=AWS%2FEC2&Period=' + $period + '&Dimensions.member.1.Value=' + $resource_uid + '&Version=2010-08-01&StartTime=' + $start_time + '&Action=GetMetricStatistics&Dimensions.member.1.Name=InstanceId&EndTime=' + $end_time + '&MetricName=' + $cpu_metric
  $params = {
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'User-Agent': 'aws-cli/1.11.56 Python/2.7.10 Darwin/16.4.0 botocore/1.5.19',
      'Host': 'monitoring.ap-southeast-2.amazonaws.com'
    },
    body: $the_body,
    signature: { 'type': 'aws' },
    url: 'https://monitoring.ap-southeast-2.amazonaws.com/'
  }
  
  call cloudwatch_post($params) retrieve $result_data
  call debug_audit_log('GetMetricStatisticsResult is:', to_s($result_data))
  #$the_data = $result_data[0]['Average']
  $the_data = $result_data[0]['Maximum']
  $count = size($result_data)
  $total = 0
  foreach $record in $the_data do  
    $total = $total + to_n($record)
  end
  $average = $total / $count
  call debug_audit_log('number of response data records:' + $count, 'Sum of data before being averaged:' + $total)
end

#This define is created to cater for a current need to retry the http post due to some issue that causes the response to contain html and not json data as expected.
#Other appempts to make it work withing the cloudwatch_api define did not work.
define cloudwatch_post($params) return $result_data on_error: retry do
  $response = http_post($params)
  $data = $response["body"]
  call debug_audit_log('data is:', to_s($data))
  $response_data = $data['GetMetricStatisticsResponse']
  $result_data = $response_data['GetMetricStatisticsResult']['Datapoints']['member']
end

define get_html_template() return $html_template do
  $response = http_get(
    url: 'https://raw.githubusercontent.com/rs-services/policy-cats/master/templates/email_template.html'
    #url: 'https://raw.githubusercontent.com/drtywheels/policy-cats/email_template_update/templates/email_template.html'
  )
  $html_template = $response['body']
end

define generate_report($underutilized_instances,$low_cpu_threshold,$period,$days_back,$action) do
  call find_account_name() retrieve $account_name
  $table_rows = ''
  foreach $instance in $underutilized_instances do
    $instance_table = '<tr><td style="border: 1px solid #ccc; border-collapse: collapse; padding: 5px; text-align: left;"><a href="' + $instance['server_access_link_root'] + '">' + $instance['id'] + '</a> (Av CPU:' + $instance['average_cpu'] + ')</td></tr>'
    insert($table_rows, -1, $instance_table)
  end
  call debug_audit_log('table_rows:', to_s($table_rows))

  # email content
  $to = $email_recipients
  $from = 'RightScale Policy <policy-cat@services.rightscale.com>'
  $subject = join(['[', $account_name, ']', ' Underutilized Instance Report'])

  if $action == 'shutdown_and_email'
    $body_html = '<img src="https://assets.rightscale.com/735ca432d626b12f75f7e7db6a5e04c934e406a8/web/images/logo.png" style="width:220px" />
                        <p>RightScale has <b>shutdown</b> instances that were found underutilized based on CPU utilization below ' + $low_cpu_threshold + '%, sampled every ' + $period + ' seconds, going back ' + $days_back + ' days.</p>'
  elsif $action == 'terminate_and_email'
    $body_html = '<img src="https://assets.rightscale.com/735ca432d626b12f75f7e7db6a5e04c934e406a8/web/images/logo.png" style="width:220px" />
                        <p>RightScale has <b>terminated</b> instances that were underutilized based on CPU utilization below ' + $low_cpu_threshold + '%, sampled every ' + $period + ' seconds, going back ' + $days_back + ' days.</p>'
  else
    $body_html = '<img src="https://assets.rightscale.com/735ca432d626b12f75f7e7db6a5e04c934e406a8/web/images/logo.png" style="width:220px" />
                        <p>RightScale discovered instances that are underutilized based on CPU utilization below ' + $low_cpu_threshold + '%, sampled every ' + $period + ' seconds, going back ' + $days_back + ' days.</p>'

  end

  $body_html = $body_html + '<table style="border: 1px solid #ccc; border-collapse: collapse; padding: 5px; text-align: left;"><tr><th style="border: 1px solid #ccc; border-collapse: collapse; padding: 5px; text-align: left;">AWS Instance ID</th>' + $table_rows + '</table>'

  $footer_text = 'This report was automatically generated by a policy template Underutilized Instance Reporter your organization has defined in RightScale.'

  call get_html_template() retrieve $html_template

  # render the template
  $html = $html_template
  $html = gsub($html, '{{title}}', $subject)
  $html = gsub($html, '{{pre_header_text}}', '')
  $html = gsub($html, '{{body}}', $body_html)
  $html = gsub($html, '{{footer_text}}', $footer_text)

  call send_html_email($to, $from, $subject, $html) retrieve $response
  call debug_audit_log('mail send response', to_s($response))

  if $response['code'] != 200
    raise 'Failed to send email report: ' + to_s($response)
  end
end

define send_html_email($to, $from, $subject, $html) return $response do
  $mailgun_endpoint = 'http://smtp.services.rightscale.com/v3/services.rightscale.com/messages'

  $to = gsub($to, "@", "%40")
  $from = gsub($from, "@", "%40")

  # escape ampersands used in html encoding
  $html = gsub($html, "&", "%26")

  $post_body = 'from=' + $from + '&to=' + $to + '&subject=' + $subject + '&html=' + $html

  $response = http_post(
    url: $mailgun_endpoint,
    headers: {"content-type": "application/x-www-form-urlencoded"},
    body: $post_body
  )
  call audit_log('email sent to: ' + gsub($to, "%40","@"), $post_body)
end

define find_account_name() return $account_name do
  $session_info = rs_cm.sessions.get(view: "whoami")
  $acct_link = select($session_info[0]["links"], {rel: "account"})
  $acct_href = $acct_link[0]["href"]
  $account_name = rs_cm.get(href: $acct_href).name
end

  # Returns the RightScale account number in which the CAT was launched.
define find_account_number() return $account_id do
  $session = rs_cm.sessions.index(view: "whoami")
  $account_id = last(split(select($session[0]["links"], {"rel":"account"})[0]["href"],"/"))
end

  # Returns the RightScale shard for the account the given CAT is launched in.
define find_shard() return $shard_number do
  call find_account_number() retrieve $account_number
  $account = rs_cm.get(href: "/api/accounts/" + $account_number)
  $shard_number = last(split(select($account[0]["links"], {"rel":"cluster"})[0]["href"],"/"))
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
                                    name:             "background report run",
                                    action:           "run",
                                    operation:        { "name": "run_scan" },
                                    recurrence:       $recurrence,
                                    timezone:         $timezone,
                                    first_occurrence: $first_occurrence
                                  )
  end
end

define get_my_timezone() return $timezone do
  @user_prefs = rs_ss.user_preferences.get(filter: ["user_id==me"])
  $timezone = @user_prefs.value
end

define run_scan($polling_frequency, $period, $days_back, $low_cpu_threshold, $tags_to_exclude, $debug_mode, $dry_mode, $action, $email_recipients) do
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

  call find_underutilized_instances($tags_to_exclude,$period,$days_back,$low_cpu_threshold) retrieve $underutilized_instances
  if size($underutilized_instances) > 0
    call audit_log('click to see underutilized instances', to_s($underutilized_instances))
    call action_underutilized($action, $underutilized_instances)
    call generate_report($underutilized_instances,$low_cpu_threshold,$period,$days_back,$action)
  end

end

define action_underutilized($action, $underutilized_instances) do
  $short_action = split($action, "_")[0]
  foreach $instance in $underutilized_instances do
    @action_instance = rs_cm.get(href: $instance['href'])
    if $$drymode != true
      if $action == 'shutdown_and_email'
        call audit_log('instance ' + $instance['href'] + ' set for ' + $short_action, to_s($instance))
        @action_instance.stop()
      elsif $action == 'terminate_and_email'
        call audit_log('instance ' + $instance['href'] + ' set for ' + $short_action, to_s($instance))
        @action_instance.terminate()
      end
    else
      call audit_log('dry mode, skipping ' + $short_action + ' for ' + $instance['id'], $action)
    end
  end
end

###
# Launch Definition
###
define launch_scheduler($polling_frequency, $low_cpu_threshold, $period, $days_back, $tags_to_exclude, $email_recipients, $debug_mode, $dry_mode, $action) do 
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
  description 'Find underutilized instances'
  definition 'launch_scheduler'
  label 'Launch'
end

operation 'run_scan' do
  description 'Run the report manually.'
  definition 'run_scan'
  label 'Run report'
end

operation 'terminate' do
  description 'Terminate the scheduler.'
  definition 'terminate_scheduler'
end
