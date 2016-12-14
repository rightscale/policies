

name 'Unattached Volume Policy'
rs_ca_ver 20160622
short_description "This automated policy CAT will find unattached volumes, send alerts, and optionally delete them. "

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
  allowed_values "Alert Only", "Alert and Delete"
  default "Alert Only"
end

parameter "param_email" do
  category "Contact"
  label "email address (reports are sent to this address)"
  type "string"
end

parameter "param_days_old" do
  category "Volume"
  label "Report on volumes that are these many days old"
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
    @all_volumes = rs_cm.volumes.index(view: "default")

    #search the collection for only volumes with status = available
    @volumes_not_in_use = select(@all_volumes, { "status": "available" })
    #@@not_attached = select(@all_volumes, { "created_at": "available" })

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
                                              We found the following unattached volumes
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
                                              Volume Size
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
      #refactor.
      if $param_action == "Alert and Delete"
        #insert($list_of_volumes, 0, "The following unattached volumes were found and deleted:%0D ")
      else
      #  insert($list_of_volumes, 0, "The following unattached volumes were found:%0D ")
      end

      #/60/60/24
      $curr_time = now()
      #$$day_old = now() - (60*60*24)

      foreach @volume in @volumes_not_in_use do
        $$error_msg=""
        #convert string to datetime to compare datetime
        $volume_created_at = to_d(@volume.updated_at)

        #the difference between dates
        $difference = $curr_time - $volume_created_at

        #convert the difference to days
        $how_old = $difference /60/60/24


        #check for Azure specific images that report as "available" but should not
        #be reported on or deleted.
        if @volume.resource_uid =~ "@system@Microsoft.Compute/Images/vhds"
          #do nothing.

        #check the age of the volume
        elsif $param_days_old < $how_old
          $volume_name = @volume.name
          $volume_size = @volume.size
          $volume_href = @volume.href

          #get cloud name
          $cloud_href = join(split($volume_href, "/")[0..2], "/") # not sure if 0..2 or 0..3 or whatever
          @cloud = rs_cm.get(href: $cloud_href)
          $cloud_name = @cloud.name

          $volume_id   = @volume.resource_uid
            #here we decide if we should delete the volume
            if $param_action == "Alert and Delete"
              sub task_name: "Delete Volume" do
                task_label("Delete Volume")
                sub on_error: handle_error() do
                  @volume.destroy()
                end
              end
            end

        $volume_table = "<tr>" + $table_start + $volume_name + $table_end + $table_start + $volume_size + $table_end + $table_start + $volume_href + $table_end + $table_start + $cloud_name + $table_end + $table_start + $volume_id + $table_end +"</tr>"
            insert($list_of_volumes, -1, $volume_table)
        end

      end

          $footer="</tr>
      </table>
  </td>
</tr>
<tr>
  <td align=%22left%22 valign=%22top%22>
      <table border=%220%22 cellpadding=%2220%22 cellspacing=%220%22 width=%22100%%22 id=%22emailFooter%22>
          <tr>
              <td align=%22left%22 valign=%22top%22>
                  This report was generated by a policy cloud application template (RightScale)
              </td>
          </tr>
      </table>
  </td>
</tr>
</table>
</td>
</tr>
</table>
</body>
</html>
"
          $$email_text = $header + $list_of_volumes + $footer


end

define handle_error() do
  #error_msg has the response from the api , use that as the error in the email.
  #$$error_msg = $_error["message"]
  $$error_msg = " failed to delete"
  $_error_behavior = "skip"
end

define send_email_mailgun($to) do
  $mailgun_endpoint = "http://smtp.services.rightscale.com/v3/services.rightscale.com/messages"

     $to = gsub($to,"@","%40")

     $post_body="from=policy-cat%40services.rightscale.com&to=" + $to + "&subject=Volume+Policy+Report&html=" + $$email_text


  $$response = http_post(
     url: $mailgun_endpoint,
     headers: { "content-type": "application/x-www-form-urlencoded"},
     body: $post_body
    )
end
