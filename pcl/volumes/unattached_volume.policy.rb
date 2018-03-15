name 'Unattached Volume Policy'
rs_ca_ver 20160622
short_description "![RS Policy](https://goo.gl/RAcMcU =64x64)\n
This automated policy CAT will find unattached volumes, send alerts, and optionally delete them."
long_description "Version: 1.1"
import "mailer"
import "sys_log"

#Copyright 2017-2018 RightScale
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
# Find unattached volumes and takes an action (alert, alert + delete)
#
# FEATURES
# Users can automatically have unattached volumes deleted.
# 02/26/2018
# Added CSV file export with email
#03/02/2018
# adding auto terminate once completed.




##################
# User inputs    #
##################
parameter "param_action" do
  category "Volume"
  label "Volume Action"
  type "string"
  allowed_values "Alert Only", "Alert and Delete"
  default "Alert Only"
end

parameter "param_email" do
  category "Contact"
  label "Email addresses (separate with commas)"
  type "string"
end

parameter "param_days_old" do
  category "Unattached Volumes"
  label "Include volumes with minimum days unattached of"
  type "number"
  default "30"
end


resources "volumes", type: "rs_cm.volumes" do
end

data_source "volumes" do
  field "name",  field(@volume,"name")
  field "size", field(@volume,"size")
  field "cloud", field(@volume,"cloud_id")
  field 'href',field(@volume,"href")
  field 'created_at',field(@volume,"created_at")
end

data_source "ds_volumes" do
  run_script $filter_volumes, $volumes,$param_days_old
end

script "filter_volumes", type: "javascript" do
  parameters "instances", "ds_volumes","days_old"
  result "filtered_volumes"
  code <<-EOS

var filtered_volumes = [];
var now = new Date.now()

for (i = 0; i < volumes.length; i++) {
  volume = volumes[i];
  if ( volume.resource_uid.match(/@system@Microsoft.Compute/Images/vhds/) ) {
    break;
  }
  var volume_created_at = Date.parse(volume.created_at)
  var difference = now - volume_created_at

  #convert the difference to days
  how_old = difference /60/60/24

  if ( days_old < how_old ) {
    filtered_volumes.push({
      "name": volume.name,
      "size": volume.size,
      "cloud":volume.cloud,
      "href":volume.href,
      "age": how_old,
      "created_at": volume.created_at
      })
  }

}
  EOS
end

escalation "handle_unattached_volumes" do
  template <<-EOS
Unattached Volumes
The following volumes are unattached:
{ range data }
* Region: { $.cloud }
* Volume Name: { $.name }
* Volume Size: { $.size }
* Volume Age: { $.age }
* Volume HREF: { $.href }
{ end }
EOS
  email $param_email do
    subject_template "Unattached volumes" # There will be a default template we use.
#    attachment do
#      filename "policy.csv"
#      template <<-EOS
#Cloud,Name,Size,Age,HREF
#{ range data }
#{ $.cloud },{ $.name },{ $.size },{ $.age },{ $.href}
#{ end }

#EOS

#    end
  end
  run "delete_volumes", data, $param_email_only
end

policy "unattached_volume_policy" do
  validate $ds_volumes do
    escalate $handle_unattached_volumes
  end
end

define delete_volumes($data,$param_email_only) do
  if $param_email_only=="false"
    foreach $item in $data do
        @volume = rs_cm.get(href: $item['href'])
        @volume.destroy
    end
  end
end
