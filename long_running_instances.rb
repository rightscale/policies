name 'InstanceFinder'
rs_ca_ver 20160622
short_description "Finds long running instances"

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
# Finds long running instances and reports on them
#


##################
# User inputs    #
##################
parameter "param_action" do
  category "Instance"
  label "Instance Action"
  type "string"
  allowed_values "ALERT"
  #allowed_values "ALERT", "ALERT AND TERMINATE"
  default "ALERT"
end

parameter "param_email" do
  category "Contact"
  label "email address (reports are sent to this address)"
  type "string"

end

parameter "param_days_old" do
  category "Instance"
  label "Report on instances that have been running longer than this number of days:"
  allowed_values "1", "7", "30"
  type "number"
end



operation "launch" do
  description "Find long running instances"
  definition "launch"
end


##################
# Definitions    #
##################

define launch($param_email,$param_action,$param_days_old) return $param_email,$param_action,$param_days_old do
        call find_long_running_instances($param_days_old)
        sleep(20)
        call send_email_mailgun($param_email)
end


define find_long_running_instances($param_days_old) do

    @all_instances = rs_cm.instances.index(filter:["state==operational"])
    $list_of_instances="The following instance have been found: %0D"

    #/60/60/24
    $curr_time = now()
    #$$day_old = now() - (60*60*24)

    foreach @instance in @all_instances do

      #convert string to datetime to compare datetime
      $volume_created_at = to_d(@instance.created_at)

      #the difference between dates
      $difference = $curr_time - $volume_created_at

      #convert the difference to days
      $how_old = $difference /60/60/24

    	if $param_days_old < $how_old
     call find_shard() retrieve $shard_number
     call find_account_number() retrieve $account_id

     call get_server_access_link(@instance.href, $shard_number, $account_id) retrieve $server_access_link_root
    $instance_name = @instance.name + "  " + $server_access_link_root +"%0D"
    #$instance_name = @instance.name + @instance.href + "%0D"

   		insert($list_of_instances, -1, $instance_name)
      end
    end
    $$email_text = $list_of_instances
end




define send_email_mailgun($to) do
    $mailgun_endpoint = "http://smtp.services.rightscale.com/v3/services.rightscale.com/messages"

       $to = gsub($to,"@","%40")
       $subject = "Long Running Instances Report"
       $text = "You have the following long running instances"

       $post_body="from=policy-cat%40services.rightscale.com&to=" + $to + "&subject=Policy+Report&text=" + $$email_text


    $$response = http_post(
       url: $mailgun_endpoint,
       headers: { "content-type": "application/x-www-form-urlencoded"},
       body: $post_body
      )
  end


  define get_server_access_link($instance_href, $shard, $account_number) return $server_access_link_root do

      $rs_endpoint = "https://us-"+$shard+".rightscale.com"


      $response = http_get(
        url: $rs_endpoint+"/api/instances?view=default",
        headers: {
        "X-Api-Version": "1.6",
        "X-Account": $account_number
        }
       )

       $instances = $response["body"]
       $instance_of_interest = select($instances, { "href" : $instance_href })[0]
       $legacy_id = $instance_of_interest["legacy_id"]
       $data = split($instance_href, "/")
       $cloud_id = $data[3]
       $server_access_link_root = "https://my.rightscale.com/acct/" + $account_number + "/clouds/" + $cloud_id + "/instances/" + $legacy_id
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
