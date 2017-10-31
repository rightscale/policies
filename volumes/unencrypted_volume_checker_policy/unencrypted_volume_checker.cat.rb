name 'Encrypted Volume Checker Policy'
rs_ca_ver 20161221
short_description 'This automated policy CAT will find unencrypted EBS volumes and generate a report of them.'

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
# Find unencrypted EBS volumes and generate a report.
#

###############
# User inputs #
###############

parameter 'param_email' do
  category 'Email'
  label 'Email addresses (separate with commas)'
  type 'string'
end

##############
# Operations #
##############

operation 'launch' do
  description 'Find unencrypted volumes'
  definition 'launch'
end

###############
# Definitions #
###############

define launch($param_email) return $param_email do
  call find_unencrypted_volumes() retrieve $send_email
end

define find_unencrypted_volumes() return $send_email do
  @volume_list = rs_cm.volumes.index(view: 'default')
  $volume_list = to_object(@volume_list)
  $unencrypted_vols = []
  $report_table = {}

  # Find unencrypted volumes
  foreach $volume in $volume_list['details'] do
    sub on_error: skip do
      if $volume['cloud_specific_attributes']['encrypted'] == false
        $unencrypted_vols << $volume
      end
    end
  end

  # Find volume HREF and name and add it to the $report_table hash
  foreach $volume in $unencrypted_vols do
    $volume_href = ""

    foreach $link in $volume['links'] do
      if $link['rel'] == 'self'
        $volume_href = $link['href']
        $report_table[$volume_href] = {}
        $report_table[$volume_href]['volume_name'] = $volume['name']
      end
    end

    foreach $link in $volume['links'] do
      if $link['rel'] == 'cloud'
        $report_table[$volume_href]['cloud_href'] = $link['href']
      end
    end
  end
  
  $$email_body = "<html><table>"

  foreach $key in sort(keys($report_table)) do
    call cloud_lookup($report_table[$key]['cloud_href']) retrieve $cloud_name
    $$email_body = $$email_body + "<tr><td>" + $cloud_name + "</td><td>" + $key + "</td><td>" + $report_table[$key]['volume_name'] + "</td></tr>"
  end

  $$email_body = $$email_body + "</table></html>"
  
  call send_email_mailgun($param_email)
end
 
define find_account_name() return $account_name do
  $session_info = rs_cm.sessions.get(view: "whoami")
  $acct_link = select($session_info[0]["links"], {rel: "account"})
  $acct_href = $acct_link[0]["href"]
  $account_name = rs_cm.get(href: $acct_href).name
end

define send_email_mailgun($param_email) do
  $mailgun_endpoint = "http://smtp.services.rightscale.com/v3/services.rightscale.com/messages"
  call find_account_name() retrieve $account_name

  $to = gsub($param_email,"@","%40")
  $post_body="from=policies%40services.rightscale.com&to=" + $to + "&subject=[" + $account_name + "] Unencrypted+Volumes&html=" + $$email_body

  $response = http_post(
    url: $mailgun_endpoint,
    headers: { "content-type": "application/x-www-form-urlencoded"},
    body: $post_body
  )
end

define cloud_lookup($href) return $cloud_name do
  $cloud_name = rs_cm.get(href: $href).display_name
end
