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

name 'Underutilized Instance Runtime Policy'
rs_ca_ver 20160622
short_description "![RS Policy](https://goo.gl/RAcMcU =64x64)\n
This automated policy CAT will identify instances that are deemed underutilized and send an alert or report."

long_description "![RS Policy](https://goo.gl/RAcMcU =64x64)\n
This automated policy CloudApp will report on instances deemed underutilized by anaalyzing cloudwatch metrics for instances that have CPU and memory utilization below input thresholds.

It is recommened to run this CloudApp with the Always On schedule
unless you want to explicitly exclude times that instances could be stopped.

This app assumes you have the admin role on your account and have AWS_ACCESS_KEY_ID & AWS_SECRET_ACCESS_KEY set in RightScale credentials.
"

##################
# User inputs    #
##################

parameter 'low_cpu_threshold' do
  category 'Advanced Options'
  label 'Report on CPU utilization below this percentage'
  type 'number'
  default '10'
end

parameter 'low_mem_threshold' do
  category 'Advanced Options'
  label 'Report on memory utilization below this percentage'
  type 'number'
  default '10'
end

parameter 'period' do
  category 'Advanced Options'
  label 'sample period. Max datapoints is 1440. In combination with days_back reduce if error is returned.'
  type 'number'
  allowed_values 300, 3600
  default 3600
end

parameter 'days_back' do
  category 'Advanced Options'
  label 'Number of days to sample. Max datapoints is 1440. In combination with period reduce if error is returned.'
  type 'number'
  allowed_values 1, 2, 7, 14, 15, 63
  default 14
end

#parameter 'param_action' do
#  category 'Instance'
#  label 'Report Action'
#  type 'string'
#  allowed_values 'Alert Only','Email Only', 'Alert and Email'
#  default 'Alert Only'
#end

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
  default 5
  allowed_values 5, 1440, 10080
end

parameter 'debug_mode' do
  category 'Advanced Options'
  label 'Debug Mode'
  type 'string'
  default 'true'
  allowed_values 'true', 'false'
end

parameter 'param_email' do
  category 'Email addresses'
  label 'Send report as email to (separate with commas):'
  type 'string'
  default 'peter.allen@industrieit.com'
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
        summary: $summary,
        detail: $details
      }
    )
  end
end

define find_underutilized_instances($tags_to_exclude,$period,$days_back,$low_cpu_threshold,$low_mem_threshold) return $instance_ids do
  $allowed_states = /^(running|operational|stranded|booting|pending|provisioned)$/
  @all_instances = rs_cm.instances.index(filter:["state==operational"])
  @all_instances = @all_instances + rs_cm.instances.index(filter:["state==booting"])
  @all_instances = @all_instances + rs_cm.instances.index(filter:["state==pending"])
  @all_instances = @all_instances + rs_cm.instances.index(filter:["state==stranded"])
  @all_instances = @all_instances + rs_cm.instances.index(filter:["state==running"])
  @all_instances = @all_instances + rs_cm.instances.index(filter:["state==provisioned"])

  if size(@all_instances[0][0]['links']) > 0
    call audit_log(to_s(size(@all_instances)) + ' candidate instance(s) found', to_s(@all_instances))

    $instance_ids=[]
    foreach @instance in @all_instances do
      $instance_href = to_object(@instance)['hrefs']
      call debug_audit_log('instance_href: ' + to_s($instance_href), to_s(@instance))
      $resource_tags = rs_cm.tags.by_resource(resource_hrefs: [@instance.href])
      $instance_tags = first(first($resource_tags))['tags']
      call debug_audit_log('instance_tags: ' + to_s($instance_tags), to_s($resource_tags))

      $tags_excluded = split($tags_to_exclude, ',')

      foreach $tag_excluded in $tags_excluded do
        #call debug_audit_log('checking if instance ' + to_s($instance_href) + ' is excluded by tag ' + $tag_excluded, to_s(@instance))
        if contains?($instance_tags, [{ name: $tag_excluded }])
          $excluded = true
          call debug_audit_log('instance ' + to_s($instance_href) + ' is excluded by tag ' + $tag_excluded, '')
          call audit_log('No action taken due to tag exclusion', '')
        else
          $excluded = false
          call debug_audit_log('instance ' + to_s($instance_href) + ' is not excluded by tag ' + $tag_excluded, '')
        end
      end
      if $excluded != true
        @instance = rs_cm.get(href: @instance.href)
        #call debug_audit_log('instance details', to_s(to_object(@instance)))
        $resource_uid = @instance.resource_uid
        if @instance.state =~ $allowed_states
          call audit_log('lets check cloudwatch utilization metrics for instance ' + $resource_uid, to_s(@instance))
          $cpu_metric = 'CPUUtilization'
          $mem_metric = 'CPUUtilization'
          call cloudwatch_api($resource_uid,$cpu_metric,$period,$days_back) retrieve $response,$average
          call debug_audit_log('Average CPU utilization metrics for instance ' + $resource_uid + ' is ' + $average, to_s($response))
          if $average < $low_cpu_threshold
            call audit_log('CPU utilization is below the ' + $low_cpu_threshold + '% threshold so a report will be emailed.', '')
            #Add instance to an array so it can be sent in one report.
            $instance_ids << $resource_uid
          end
        else
          call audit_log('No action taken due to instance not in allowed state', '')
        end
      end
    end
  else
    call audit_log('No valid instances found', '')
  end
end

define cloudwatch_api($resource_uid,$cpu_metric,$period,$days_back) return $response,$average do
  $time = now()
  $before_time = $time - (3600 * 24 * $days_back)
  $end_time = strftime($time, "%Y-%m-%dT%H%%3A%M%%3A%SZ")
  $start_time = strftime($before_time, "%Y-%m-%dT%H%%3A%M%%3A%SZ")
  $the_body = 'Statistics.member.1=Average&Namespace=AWS%2FEC2&Period=' + $period + '&Dimensions.member.1.Value=' + $resource_uid + '&Version=2010-08-01&StartTime=' + $start_time + '&Action=GetMetricStatistics&Dimensions.member.1.Name=InstanceId&EndTime=' + $end_time + '&MetricName=' + $cpu_metric
  $params = {
    body: $the_body,
    headers: { 
      'Content-Type': 'application/x-www-form-urlencoded',
      'User-Agent': 'aws-cli/1.11.56 Python/2.7.10 Darwin/16.4.0 botocore/1.5.19',
      'Host': 'monitoring.ap-southeast-2.amazonaws.com'
    },
    signature: { 'type': 'aws' },
    url: 'https://monitoring.ap-southeast-2.amazonaws.com/'
  }
  
  call post_http($params) retrieve $response,$GetMetricStatisticsResult
  call debug_audit_log('GetMetricStatisticsResult is:', to_s($GetMetricStatisticsResult))
  $Average_data = $GetMetricStatisticsResult[0]['Average']
  $count = size($GetMetricStatisticsResult)
  call debug_audit_log('number of response data records:' + $count, '')
  $total = 0
  foreach $record in $Average_data do  
    $total = $total + to_n($record)
  end
  $average = $total / $count
end

define post_http($params) return $response,$GetMetricStatisticsResult on_error: retry do
  $response = http_post($params)
  $data = $response["body"]
  call debug_audit_log('data is:', to_s($data))
  $GetMetricStatisticsResponse = $data['GetMetricStatisticsResponse']
  $GetMetricStatisticsResult = $GetMetricStatisticsResponse['GetMetricStatisticsResult']['Datapoints']['member']
end

define generate_report($instance_ids,$low_cpu_threshold,$low_mem_threshold) return $send_email do
  $table_start="<td align=%22left%22 valign=%22top%22>"
  $table_end="</td>"
  $send_email = "true"

  $instanceids = []
  $list_of_instances = ''
  foreach $instance in $instance_ids do
    $instance_table = "<tr>" + $table_start + to_s($instance) + $table_end + "</tr>"
    insert($list_of_instances, -1, $instance_table)
  end
  call debug_audit_log('list_of_instances:', to_s($list_of_instances))

  #form email
  $email_msg = "RightScale discovered instances that are underutilised based on CPU utilization below " + $low_cpu_threshold + " percent and memory utilization below " + $low_mem_threshold + " percent."

  $header="\<\!DOCTYPE html PUBLIC \"-\/\/W3C\/\/DTD XHTML 1.0 Transitional\/\/EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\"\>
    <html xmlns=\"http:\/\/www.w3.org\/1999\/xhtml\">
      <head>
        <meta http-equiv=%22Content-Type%22 content=%22text/html; charset=UTF-8%22 />
        <a href=%22//www.rightscale.com%22>
          <img src=%22https://assets.rightscale.com/6d1cee0ec0ca7140cd8701ef7e7dceb18a91ba20/web/images/logo.png%22 alt=%22RightScale Logo%22 width=%22200px%22 />
        </a>
        <style></style>
      </head>
      <body>
        <table border=%220%22 cellpadding=%220%22 cellspacing=%220%22 height=%22100%%22 width=%22100%%22 id=%22bodyTable%22>
          <tr>
            <td align=%22left%22 valign=%22top%22>
              <table border=%220%22 cellpadding=%2220%22 cellspacing=%220%22 width=%22100%%22 id=%22emailContainer%22>
                <tr>
                  <td align=%22left%22 valign=%22top%22>
                    <table border=%220%22 cellpadding=%2220%22 cellspacing=%220%22 width=%22100%%22 id=%22emailHeader%22>
                      <tr>
                        <td align=%22left%22 valign=%22top%22>
                          " + $email_msg + "
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
                <tr>
                  <td align=%22left%22 valign=%22top%22>
                    <table border=%220%22 cellpadding=%2210%22 cellspacing=%220%22 width=%22100%%22 id=%22emailBody%22>
                      <tr>
                        <td align=%22left%22 valign=%22top%22>
                          Instance ID
                        </td>"

  $footer="</tr></table></td></tr><tr><td align=%22left%22 valign=%22top%22><table border=%220%22 cellpadding=%2220%22 cellspacing=%220%22 width=%22100%%22 id=%22emailFooter%22><tr><td align=%22left%22 valign=%22top%22>
             This report was automatically generated by a policy template Instance Runtime Policy your organization has defined in RightScale.
           </td></tr></table></td></tr></table></td></tr></table></body></html>"
  $$email_body = $header + $list_of_instances + $footer
end

define handle_error() do
  #error_msg has the response from the api , use that as the error in the email.
  $$error_msg = $_error["message"]
  $_error_behavior = "skip"
end

define send_email_mailgun($to) do
  $mailgun_endpoint = "http://smtp.services.rightscale.com/v3/services.rightscale.com/messages"
  call find_account_name() retrieve $account_name
  $to = gsub($to,"@","%40")
  $subject = "Underutilised Instance Report"
  $text = "You have the following underutilised instances"

  $post_body="from=policy-cat%40services.rightscale.com&to=" + $to + "&subject=[" + $account_name + "] " + $subject + "&html=" + $$email_body

  $$response = http_post(
     url: $mailgun_endpoint,
     headers: { "content-type": "application/x-www-form-urlencoded"},
     body: $post_body
  )
  call audit_log('email sent to: ' + gsub($to, "%40","@"), $post_body)
end

define error_GetMetricStatisticsResponse() return $GetMetricStatisticsResult do
  $GetMetricStatisticsResult = []
  $_error_behavior = "retry"
end

define find_account_name() return $account_name do
  $session_info = rs_cm.sessions.get(view: "whoami")
  $acct_link = select($session_info[0]["links"], {rel: "account"})
  $acct_href = $acct_link[0]["href"]
  $account_name = rs_cm.get(href: $acct_href).name
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

define run_scan($polling_frequency, $period, $days_back, $low_cpu_threshold, $low_mem_threshold, $tags_to_exclude, $debug_mode, $param_email) do
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

  call find_underutilized_instances($tags_to_exclude,$period,$days_back,$low_cpu_threshold,$low_mem_threshold) retrieve $instance_ids
  call audit_log('instance ids', to_s($instance_ids))
  call generate_report($instance_ids,$low_cpu_threshold,$low_mem_threshold) retrieve $send_email

  sleep(20)
  if $send_email == "true"
    call send_email_mailgun($param_email)
  end

end
###
# Launch Definition
###
define launch_scheduler($polling_frequency, $low_cpu_threshold, $low_mem_threshold, $period, $days_back, $tags_to_exclude, $param_email, $debug_mode) do
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
