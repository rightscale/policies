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
  $links = {}

  # Find unencrypted volumes
  foreach $volume in $volume_list['details'] do
    sub on_error: skip do
      if $volume['cloud_specific_attributes']['encrypted'] == false
        $unencrypted_vols << $volume
      end
    end
  end

  # Find volume HREF and name and add it to the $links hash
  foreach $volume in $unencrypted_vols do
    foreach $link in $volume['links'] do
      if $link['rel'] == 'self'
         $links[$link['href']] = $volume['name']
      end
    end
  end

  $$email_body = "<html><table>"

  foreach $key in keys($links) do
    $$email_body = $$email_body + "<tr><td>" + $key + "</td><td>" + $links[$key] + "</td></tr>"
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
  $post_body="from=policy-cat%40services.rightscale.com&to=" + $to + "&subject=[" + $account_name + "] Stefhen+Testing&html=" + $$email_body

  $response = http_post(
    url: $mailgun_endpoint,
    headers: { "content-type": "application/x-www-form-urlencoded"},
    body: $post_body
  )
end








##################################################################

define gen_table() do
$header=
  "\<\!DOCTYPE html PUBLIC \"-\/\/W3C\/\/DTD XHTML 1.0 Transitional\/\/EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\"\>
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
                                              Volume Name
                                          </td>
                                          <td align=%22left%22 valign=%22top%22>
                                              Volume Size (GB)
                                          </td>
                                          <td align=%22left%22 valign=%22top%22>
                                              Days Old
                                          </td>
                                          <td align=%22left%22 valign=%22top%22>
                                              Volume Href
                                          </td>
                                          <td align=%22left%22 valign=%22top%22>
                                              Cloud
                                          </td>
                                          <td align=%22left%22 valign=%22top%22>
                                              Volume ID
                                          </td>
                                      </tr>
                                      "
      $list_of_volumes=""
      $table_start="<td align=%22left%22 valign=%22top%22>"
      $table_end="</td>"
end




##################### test

define testing() return $links do
  @volume_list = rs_cm.volumes.index(view: 'default')
  $volume_list = to_object(@volume_list)
  $unencrypted_vols = []
  $links = {}

  # Find unencrypted volumes
  foreach $volume in $volume_list['details'] do
    sub on_error: skip do
      if $volume['cloud_specific_attributes']['encrypted'] == false
        $unencrypted_vols << $volume
      end
    end
  end

  # Find volume HREF and name and add it to the $links hash
  foreach $volume in $unencrypted_vols do
    foreach $link in $volume['links'] do
      if $link['rel'] == 'self'
         $links[$link['href']] = $volume['name']
      end
    end
  end
end
