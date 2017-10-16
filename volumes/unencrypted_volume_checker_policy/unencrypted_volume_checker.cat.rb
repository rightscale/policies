name 'Encrypted Volume Checker Policy'
rs_ca_ver 20160622
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
  $post_body="from=policy-cat%40services.rightscale.com&to=" + $to + "&subject=[" + $account_name + "] Unencrypted+Volumes&html=" + $$email_body

  $response = http_post(
    url: $mailgun_endpoint,
    headers: { "content-type": "application/x-www-form-urlencoded"},
    body: $post_body
  )
end

define cloud_lookup($href) return $cloud_name do
  $clouds = {
    "/api/clouds/1"    => "AWS US-East",
    "/api/clouds/10"   => "AWS China-Beijing",
    "/api/clouds/11"   => "AWS US-Ohio",
    "/api/clouds/12"   => "AWS AP-Seoul",
    "/api/clouds/13"   => "AWS EU-London",
    "/api/clouds/14"   => "AWS CA-Central",
    "/api/clouds/1415" => "CloudStack 2.2.13 - ESX",
    "/api/clouds/1869" => "SoftLayer",
    "/api/clouds/2"    => "AWS EU-Ireland",
    "/api/clouds/2175" => "Google",
    "/api/clouds/2178" => "Azure West US",
    "/api/clouds/2179" => "Azure East US",
    "/api/clouds/2180" => "Azure East Asia",
    "/api/clouds/2181" => "Azure Southeast Asia",
    "/api/clouds/2182" => "Azure North Europe",
    "/api/clouds/2183" => "Azure West Europe",
    "/api/clouds/2324" => "Rackspace Open Cloud - Chicago",
    "/api/clouds/2373" => "Rackspace Open Cloud - London",
    "/api/clouds/2374" => "Rackspace Open Cloud - Dallas",
    "/api/clouds/2534" => "Rackspace Open Cloud - Sydney",
    "/api/clouds/2535" => "BlueSkies",
    "/api/clouds/2879" => "Rivervale-vMware",
    "/api/clouds/3"    => "AWS US-West",
    "/api/clouds/3032" => "RS-PS VM Test Env",
    "/api/clouds/3037" => "vSphere Cloud",
    "/api/clouds/3040" => "Azure Australia East",
    "/api/clouds/3041" => "Azure Australia Southeast",
    "/api/clouds/3070" => "Openstack Juno",
    "/api/clouds/3243" => "Cisco OpenStack",
    "/api/clouds/3301" => "Rivervale-CloudStack",
    "/api/clouds/3302" => "Curts Big Ass Cloud",
    "/api/clouds/3313" => "curts-cloud",
    "/api/clouds/3338" => "Services UCA",
    "/api/clouds/3339" => "tushar uca cloud",
    "/api/clouds/3342" => "RSUCA",
    "/api/clouds/3343" => "JerseyCloud",
    "/api/clouds/3351" => "MobileStackZ",
    "/api/clouds/3391" => "RCA-V VMware 5.5 Services",
    "/api/clouds/3455" => "nathan-dockercloud",
    "/api/clouds/3482" => "VMware Private Cloud",
    "/api/clouds/3499" => "Openstack Liberty",
    "/api/clouds/3509" => "Uncle Sean's Basement",
    "/api/clouds/3518" => "AzureRM West US",
    "/api/clouds/3519" => "AzureRM Japan East",
    "/api/clouds/3520" => "AzureRM Southeast Asia",
    "/api/clouds/3521" => "AzureRM Japan West",
    "/api/clouds/3522" => "AzureRM East Asia",
    "/api/clouds/3523" => "AzureRM East US",
    "/api/clouds/3524" => "AzureRM West Europe",
    "/api/clouds/3525" => "AzureRM North Central US",
    "/api/clouds/3526" => "AzureRM Central US",
    "/api/clouds/3527" => "AzureRM Canada Central",
    "/api/clouds/3528" => "AzureRM North Europe",
    "/api/clouds/3529" => "AzureRM Brazil South",
    "/api/clouds/3530" => "AzureRM Canada East",
    "/api/clouds/3531" => "AzureRM East US 2",
    "/api/clouds/3532" => "AzureRM South Central US",
    "/api/clouds/3546" => "AzureRM West US 2",
    "/api/clouds/3547" => "AzureRM West Central US",
    "/api/clouds/3567" => "AzureRM UK South",
    "/api/clouds/3568" => "AzureRM UK West",
    "/api/clouds/3569" => "AzureRM West India",
    "/api/clouds/3570" => "AzureRM Central India",
    "/api/clouds/3571" => "AzureRM South India",
    "/api/clouds/3655" => "RCAV-Test",
    "/api/clouds/3658" => "RS OSS RCAV",
    "/api/clouds/4"    => "AWS AP-Singapore",
    "/api/clouds/5"    => "AWS AP-Tokyo",
    "/api/clouds/6"    => "AWS US-Oregon",
    "/api/clouds/7"    => "AWS SA-São Paulo",
    "/api/clouds/8"    => "AWS AP-Sydney",
    "/api/clouds/9"    => "AWS EU-Frankfurt"
  }

  $cloud_name = $clouds[$href]
end
