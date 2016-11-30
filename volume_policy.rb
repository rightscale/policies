

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
  allowed_values "ALERT", "ALERT AND DELETE"
  default "ALERT"
end

parameter "param_email" do
  category "Contact"
  label "email address (reports are sent to this address)"
  type "string"
end


##################
# Operations     #
##################

operation "launch" do
  description "Find unattached volumes"
  definition "launch"
end


##################
# Definitions    #
##################

define launch($param_email,$param_action) return $param_email,$param_action do
        call find_unattached_volumes($param_action)
        sleep(20)
        call send_email_mailgun($param_email)
end


define find_unattached_volumes($param_action) do

    #get all volumes
    @all_volumes = rs_cm.volumes.index()

    #search the collection for only volumes with status = available
    @volumes_not_in_use = select(@all_volumes, { "status": "available" })
    #@@not_attached = select(@all_volumes, { "created_at": "available" })

    #TODO
    #For each volume check to see if it was recently created ( we don't want to include a recently created volume to the list of unattached volumes)
    #use select to create a collection with older volumes

    #format email output with links to the volumes , not useful if they are deleted.
    #https://us-4.rightscale.com/acct/58242/clouds/1/volumes/207011592004

    #Percent-encoding the collection  https://en.wikipedia.org/wiki/Percent-encoding
    $list_of_volumes=to_s(@volumes_not_in_use)
    $list_of_volumes = gsub($list_of_volumes,"rs_cm.volumes:","")
    $list_of_volumes = gsub($list_of_volumes,",","%2C%0D")
    $list_of_volumes = gsub($list_of_volumes,"/","%2F")
    
    insert($list_of_volumes, 0, "The following unattached volumes were found:%0D ")
    $$email_text = $list_of_volumes

    #if action = alert/delete
    if $param_action == "ALERT AND DELETE"
      foreach @volume in @volumes_not_in_use do
        @volume.destroy()
        #TODO
        #For each volume check to see if it was recently created ( we don't want to include a recently created volume to the list of unattached volumes)
        #use select to create a collection with older volumes
        #updated_at":"2014/04/30 22:25:24 +0000"}}
        $volume_href = @volume.href
        #$time = now()
        #$api_time = strftime($time, "%Y/%m/%d %H:%M:%S +0000")
      #  @vol = rs_cm.get(href:"$volume_href")
        #@vol.destroy()

      end
    end

    #TODO
    #For each volume check to see if it was recently created ( we don't want to include a recently created volume to the list of unattached volumes)
end


define send_email_mailgun($to) do
  $mailgun_endpoint = "http://174.129.76.224/v3/services.rightscale.com/messages"

     $to = gsub($to,"@","%40")
     $subject = "Volume Policy Report"
     $text = "You have the following unattached volumes"

     $post_body="from=policy-cat%40services.rightscale.com&to=" + $to + "&subject=Policy+Report&text=" + $$email_text


  $$response = http_post(
     url: $mailgun_endpoint,
     headers: { "content-type": "application/x-www-form-urlencoded"},
     body: $post_body
    )
end
