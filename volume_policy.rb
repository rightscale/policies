
name 'VolumeFinder'
rs_ca_ver 20160622
short_description "Finds unattached volumes"

#Copyright 2016 RightScale
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
#



##################
# User inputs    #
##################
parameter "param_action" do
  category "Volume"
  label "Volume Action"
  type "string"
  allowed_values "DRY-RUN","ALERT", "ALERT AND DELETE"
  default "DRY-RUN"
end

parameter "param_email" do
  category "Email"
  label "email"
  type "string"
  default "edwin@rightscale.com"
end


define find_unattached_volumes() do

    #get all volumes
    @@all_volumes = rs_cm.volumes.index()

    #search the collection for only volumes with status = available
    @@volumes_not_in_use = select(@@all_volumes, { "status": "available" })

    #TODO
    #For each volume check to see if it was recently created ( we don't want to include a recently created volume to the list of unattached volumes)
    $$size=size(@@volumes_not_in_use)

end


define send_email_mailgun($to,$volumes) do
  $mailgun_endpoint = "https://api:key-fa2de8fb14368260a3d9e308b42e8feb@api.mailgun.net/v3/services.rightscale.com/messages"


     $from = "policy-cat@services.rightscale.com"
     $to = "edwin@rightscale.com"
     $subject = "Policy Report"
     $text = "You have the following volumes unattached"


 $post_body="from=policy-cat%40services.rightscale.com&to=edwin%40rightscale.com&subject=Policy+Report&text=You+have+the+following+volumes+unattached"


  $$response = http_post(
     url: $mailgun_endpoint,
     headers: { "content-type": "application/x-www-form-urlencoded"},
     body: $post_body
    )
end
