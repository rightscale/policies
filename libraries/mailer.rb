name "Policies Mailer Package"
rs_ca_ver 20161221
short_description "This package provides definitions to support the policies_mailer service"
long_description "Version: 1.0"
package "mailer"
import "sys_log"

########################################################
#  USAGE
#
#  This package provides definitions to support the policies_mailer service
#
#  EXAMPLE
#  -----
#  To define which groups can launch this cat, use the following code.
#  ```
#  import 'mailer'
#  call mailer.create_csv_with_columns($endpoint,["column-a","column-b"]) retrieve $filename
#  ```
#  ------
# API Documentation: https://rs-services.github.io/policies_mailer/#/
#

#######
# deletes csv file from policies_mailer server
# $endpoint - host of policies_mailer api server
# $filename - name of the filename to delete, ex: 6901f064-8077-4644-984b-a3ee258f57c3.csv
#######
define delete_csv($endpoint,$filename) do
  call start_debugging()
  $api_endpoint = join([$endpoint, "/api/csv/", $filename])
  call sys_log.detail("endpoint: " + $api_endpoint)
  sub on_error: stop_debugging() do
    $response = http_delete(
      url: $api_endpoint,
      headers: {"X-Api-Version": "1.0"}
    )
  end
  call stop_debugging()
end

#######
# creates csv file from policies_mailer server
# $endpoint - host of policies_mailer api server
# $columns - array of strings for column names, ex: [ "column-a", "column-b" ] 
#######
define create_csv_with_columns($endpoint,$columns) return $filename do
  task_label("creating csv file")
  $filename = ""
  $api_endpoint = join([$endpoint, "/api/csv"])
  call sys_log.detail("endpoint: " + $api_endpoint)
  call start_debugging()
  sub on_error: stop_debugging() do
    call sys_log.detail("endpoint_sub: " + $api_endpoint)
    $response = http_post(
      url: $api_endpoint,
      headers: {"X-Api-Version": "1.0"},
      body: { "data": [$columns] }
    )
    $filename = $response["body"]["file"]
    $$mailer_filename = $filename
  end
  call stop_debugging()
end

#######
# adds rows to csv file from policies_mailer server
# $endpoint - host of policies_mailer api server
# $filename - name of the filename to delete, ex: 6901f064-8077-4644-984b-a3ee258f57c3.csv
# $row - row to add to the csv file, ex: ["row-1-1", "row-1-2"]
#######
define update_csv_with_rows($endpoint,$filename,$row) return $filename do
  task_label("csv:" + $filename + " name: " + $rows[0])
  call start_debugging()
  $api_endpoint = join([$endpoint, "/api/csv/", $filename])
  call sys_log.detail("endpoint: " + $api_endpoint)
  $filename = ""
  sub on_error: stop_debugging() do
    $response = http_put(
      url: $api_endpoint,
      headers: {"X-Api-Version": "1.0"},
      body: { "data": [$row] }
    )
    $filename = $response["body"]["file"]
  end
  $$update_filename = $filename
  call stop_debugging()
end

#######
# sends emails 
# $endpoint - host of policies_mailer api server
# $to - email address to send to. 
# $from - email address for from address
# $subject - subject of the email
# $body - body of the email
# $filename - name of the filename to delete, ex: 6901f064-8077-4644-984b-a3ee258f57c3.csv
# $encoding - email encoding type: text, html
#######
define send_html_email($endpoint,$to, $from, $subject, $body, $filename, $encoding) return $response do
  task_label("Sending email")
  $api_endpoint = join([$endpoint, "/api/mail"])
  call sys_log.detail("endpoint: " + $api_endpoint)
  $response = ""
  call start_debugging()
  $email_body = {
    "to": $to,
    "from": $from,
    "subject": $subject,
    "body": $body
  }
  if $filename != ""
    $email_body["attachment"] =  $filename
  end

  if $encoding != ""
    $email_body["encoding"] = $encoding
  end

  sub on_error: stop_debugging() do
    $response = http_post(
      url: $api_endpoint,
      headers: {"X-Api-Version": "1.0"},
      body: $email_body
    )
  end
  call stop_debugging()
end

#######
# creates csv and sends email
# $endpoint - host of policies_mailer api server
# $to - email address to send to. 
# $from - email address for from address
# $subject - subject of the email
# $body - body of the email
# $two_dimensional_array_of_csv_data - ex: [["column-a","column-b"],["row-1-1", "row-1-2"]]
# $encoding - email encoding type: text, html
#######
define create_csv_and_send_email($endpoint,$to,$from,$subject,$body,$two_dimensional_array_of_csv_data,$encoding) return $response do
  task_label("creating csv and send email")
  $api_endpoint = join([$endpoint, "/api/csv"])
  call sys_log.detail("endpoint: " + $api_endpoint)
  $response = ""
  $filename = ""
  call start_debugging()
  sub on_error: stop_debugging() do
    $response = http_post(
      url: $api_endpoint,
      headers: {"X-Api-Version": "1.0"},
      body: { "data": $two_dimensional_array_of_csv_data }
    )
    $filename = $response["body"]["file"]
    $$mailer_filename = $filename
  end
  call stop_debugging()
  call send_html_email($endpoint, $to, $from, $subject, $body, $filename, $encoding) retrieve $response
end

define start_debugging() do
  if $$debugging == false || logic_and($$debugging != false, $$debugging != true)
    initiate_debug_report()
    $$debugging = true
  end
end

define stop_debugging() do
  if $$debugging == true
    $debug_report = complete_debug_report()
    call sys_log.detail($debug_report)
    $$debugging = false
  end
end