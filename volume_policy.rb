

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

parameter "param_days_old" do
  category "Volume"
  label "delete volumes that are these many days old"
  allowed_values "1", "7", "30"
  type "number"
  default "30"
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

define launch($param_email,$param_action,$param_days_old) return $param_email,$param_action,$param_days_old do
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

    $list_of_volumes=""

      foreach @volume in @volumes_not_in_use do

        #/60/60/24
        $$curr_time = now()
        #$$day_old = now() - (60*60*24)

        #convert string to datetime to compare datetime
        $$volume_created_at = to_d(@volume.updated_at)

        #the difference between dates
        $$difference = $$curr_time - $$volume_created_at

        #convert the difference to days
        $$how_old = $$difference /60/60/24
        if $param_days_old < $$how_old
          $volume_name = @volume.name + "%0D"
          insert($list_of_volumes, -1, $volume_name)

            #here we decide if we should delete the volume
            if $param_action == "ALERT AND DELETE"
              insert($list_of_volumes, 0, "The following unattached volumes were found and deleted:%0D ")
              @volume.destroy()
            else
              insert($list_of_volumes, 0, "The following unattached volumes were found:%0D ")
            end
        end

      end
          $$email_text = $list_of_volumes

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
