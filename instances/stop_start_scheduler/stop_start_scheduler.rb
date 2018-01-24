# Copyright 2017 RightScale
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

name 'Start/Stop Scheduler'
short_description "![RS Policy](https://goo.gl/RAcMcU =64x64)
Starts or stops instances based on a given schedule."
long_description "Version 1.1"
rs_ca_ver 20161221

parameter 'ss_schedule_name' do
  category 'Scheduler Policy'
  label 'Schedule Name'
  description "ALL to scan for all schedules, or enter a schedule name to scan for only the one schedule."
  type 'string'
  default "ALL"
end

parameter 'scheduler_tags_exclude' do
  category 'Scheduler Policy'
  label 'Tags Exclude'
  description 'Explicitly exclude any instances with these tags (comma separated).'
  type 'list'
  default 'instance:scheduler_exclude=true,instance:immutable=true'
end

parameter 'email_recipients' do
  category 'Reporting'
  label 'Email Recipients'
  description 'A comma-separated list of email addresses to send reports to when actions are taken on instances.'
  type 'string'
end

parameter 'timezone_override' do
  category 'Advanced Options'
  label 'Timezone Override'
  description "By default, the self-service user's timezone is used."
  type 'string'
  allowed_values  '',
                  'Africa/Abidjan',
                  'Africa/Accra',
                  'Africa/Addis_Ababa',
                  'Africa/Algiers',
                  'Africa/Asmara',
                  'Africa/Asmera',
                  'Africa/Bamako',
                  'Africa/Bangui',
                  'Africa/Banjul',
                  'Africa/Bissau',
                  'Africa/Blantyre',
                  'Africa/Brazzaville',
                  'Africa/Bujumbura',
                  'Africa/Cairo',
                  'Africa/Casablanca',
                  'Africa/Ceuta',
                  'Africa/Conakry',
                  'Africa/Dakar',
                  'Africa/Dar_es_Salaam',
                  'Africa/Djibouti',
                  'Africa/Douala',
                  'Africa/El_Aaiun',
                  'Africa/Freetown',
                  'Africa/Gaborone',
                  'Africa/Harare',
                  'Africa/Johannesburg',
                  'Africa/Juba',
                  'Africa/Kampala',
                  'Africa/Khartoum',
                  'Africa/Kigali',
                  'Africa/Kinshasa',
                  'Africa/Lagos',
                  'Africa/Libreville',
                  'Africa/Lome',
                  'Africa/Luanda',
                  'Africa/Lubumbashi',
                  'Africa/Lusaka',
                  'Africa/Malabo',
                  'Africa/Maputo',
                  'Africa/Maseru',
                  'Africa/Mbabane',
                  'Africa/Mogadishu',
                  'Africa/Monrovia',
                  'Africa/Nairobi',
                  'Africa/Ndjamena',
                  'Africa/Niamey',
                  'Africa/Nouakchott',
                  'Africa/Ouagadougou',
                  'Africa/Porto-Novo',
                  'Africa/Sao_Tome',
                  'Africa/Timbuktu',
                  'Africa/Tripoli',
                  'Africa/Tunis',
                  'Africa/Windhoek',
                  'America/Adak',
                  'America/Anchorage',
                  'America/Anguilla',
                  'America/Antigua',
                  'America/Araguaina',
                  'America/Argentina/Buenos_Aires',
                  'America/Argentina/Catamarca',
                  'America/Argentina/ComodRivadavia',
                  'America/Argentina/Cordoba',
                  'America/Argentina/Jujuy',
                  'America/Argentina/La_Rioja',
                  'America/Argentina/Mendoza',
                  'America/Argentina/Rio_Gallegos',
                  'America/Argentina/Salta',
                  'America/Argentina/San_Juan',
                  'America/Argentina/San_Luis',
                  'America/Argentina/Tucuman',
                  'America/Argentina/Ushuaia',
                  'America/Aruba',
                  'America/Asuncion',
                  'America/Atikokan',
                  'America/Atka',
                  'America/Bahia',
                  'America/Bahia_Banderas',
                  'America/Barbados',
                  'America/Belem',
                  'America/Belize',
                  'America/Blanc-Sablon',
                  'America/Boa_Vista',
                  'America/Bogota',
                  'America/Boise',
                  'America/Buenos_Aires',
                  'America/Cambridge_Bay',
                  'America/Campo_Grande',
                  'America/Cancun',
                  'America/Caracas',
                  'America/Catamarca',
                  'America/Cayenne',
                  'America/Cayman',
                  'America/Chicago',
                  'America/Chihuahua',
                  'America/Coral_Harbour',
                  'America/Cordoba',
                  'America/Costa_Rica',
                  'America/Creston',
                  'America/Cuiaba',
                  'America/Curacao',
                  'America/Danmarkshavn',
                  'America/Dawson',
                  'America/Dawson_Creek',
                  'America/Denver',
                  'America/Detroit',
                  'America/Dominica',
                  'America/Edmonton',
                  'America/Eirunepe',
                  'America/El_Salvador',
                  'America/Ensenada',
                  'America/Fort_Nelson',
                  'America/Fort_Wayne',
                  'America/Fortaleza',
                  'America/Glace_Bay',
                  'America/Godthab',
                  'America/Goose_Bay',
                  'America/Grand_Turk',
                  'America/Grenada',
                  'America/Guadeloupe',
                  'America/Guatemala',
                  'America/Guayaquil',
                  'America/Guyana',
                  'America/Halifax',
                  'America/Havana',
                  'America/Hermosillo',
                  'America/Indiana/Indianapolis',
                  'America/Indiana/Knox',
                  'America/Indiana/Marengo',
                  'America/Indiana/Petersburg',
                  'America/Indiana/Tell_City',
                  'America/Indiana/Vevay',
                  'America/Indiana/Vincennes',
                  'America/Indiana/Winamac',
                  'America/Indianapolis',
                  'America/Inuvik',
                  'America/Iqaluit',
                  'America/Jamaica',
                  'America/Jujuy',
                  'America/Juneau',
                  'America/Kentucky/Louisville',
                  'America/Kentucky/Monticello',
                  'America/Knox_IN',
                  'America/Kralendijk',
                  'America/La_Paz',
                  'America/Lima',
                  'America/Los_Angeles',
                  'America/Louisville',
                  'America/Lower_Princes',
                  'America/Maceio',
                  'America/Managua',
                  'America/Manaus',
                  'America/Marigot',
                  'America/Martinique',
                  'America/Matamoros',
                  'America/Mazatlan',
                  'America/Mendoza',
                  'America/Menominee',
                  'America/Merida',
                  'America/Metlakatla',
                  'America/Mexico_City',
                  'America/Miquelon',
                  'America/Moncton',
                  'America/Monterrey',
                  'America/Montevideo',
                  'America/Montreal',
                  'America/Montserrat',
                  'America/Nassau',
                  'America/New_York',
                  'America/Nipigon',
                  'America/Nome',
                  'America/Noronha',
                  'America/North_Dakota/Beulah',
                  'America/North_Dakota/Center',
                  'America/North_Dakota/New_Salem',
                  'America/Ojinaga',
                  'America/Panama',
                  'America/Pangnirtung',
                  'America/Paramaribo',
                  'America/Phoenix',
                  'America/Port_of_Spain',
                  'America/Port-au-Prince',
                  'America/Porto_Acre',
                  'America/Porto_Velho',
                  'America/Puerto_Rico',
                  'America/Rainy_River',
                  'America/Rankin_Inlet',
                  'America/Recife',
                  'America/Regina',
                  'America/Resolute',
                  'America/Rio_Branco',
                  'America/Rosario',
                  'America/Santa_Isabel',
                  'America/Santarem',
                  'America/Santiago',
                  'America/Santo_Domingo',
                  'America/Sao_Paulo',
                  'America/Scoresbysund',
                  'America/Shiprock',
                  'America/Sitka',
                  'America/St_Barthelemy',
                  'America/St_Johns',
                  'America/St_Kitts',
                  'America/St_Lucia',
                  'America/St_Thomas',
                  'America/St_Vincent',
                  'America/Swift_Current',
                  'America/Tegucigalpa',
                  'America/Thule',
                  'America/Thunder_Bay',
                  'America/Tijuana',
                  'America/Toronto',
                  'America/Tortola',
                  'America/Vancouver',
                  'America/Virgin',
                  'America/Whitehorse',
                  'America/Winnipeg',
                  'America/Yakutat',
                  'America/Yellowknife',
                  'Antarctica/Casey',
                  'Antarctica/Davis',
                  'Antarctica/DumontDUrville',
                  'Antarctica/Macquarie',
                  'Antarctica/Mawson',
                  'Antarctica/McMurdo',
                  'Antarctica/Palmer',
                  'Antarctica/Rothera',
                  'Antarctica/South_Pole',
                  'Antarctica/Syowa',
                  'Antarctica/Troll',
                  'Antarctica/Vostok',
                  'Arctic/Longyearbyen',
                  'Asia/Aden',
                  'Asia/Almaty',
                  'Asia/Amman',
                  'Asia/Anadyr',
                  'Asia/Aqtau',
                  'Asia/Aqtobe',
                  'Asia/Ashgabat',
                  'Asia/Ashkhabad',
                  'Asia/Atyrau',
                  'Asia/Baghdad',
                  'Asia/Bahrain',
                  'Asia/Baku',
                  'Asia/Bangkok',
                  'Asia/Barnaul',
                  'Asia/Beirut',
                  'Asia/Bishkek',
                  'Asia/Brunei',
                  'Asia/Calcutta',
                  'Asia/Chita',
                  'Asia/Choibalsan',
                  'Asia/Chongqing',
                  'Asia/Chungking',
                  'Asia/Colombo',
                  'Asia/Dacca',
                  'Asia/Damascus',
                  'Asia/Dhaka',
                  'Asia/Dili',
                  'Asia/Dubai',
                  'Asia/Dushanbe',
                  'Asia/Famagusta',
                  'Asia/Gaza',
                  'Asia/Harbin',
                  'Asia/Hebron',
                  'Asia/Ho_Chi_Minh',
                  'Asia/Hong_Kong',
                  'Asia/Hovd',
                  'Asia/Irkutsk',
                  'Asia/Istanbul',
                  'Asia/Jakarta',
                  'Asia/Jayapura',
                  'Asia/Jerusalem',
                  'Asia/Kabul',
                  'Asia/Kamchatka',
                  'Asia/Karachi',
                  'Asia/Kashgar',
                  'Asia/Kathmandu',
                  'Asia/Katmandu',
                  'Asia/Khandyga',
                  'Asia/Kolkata',
                  'Asia/Krasnoyarsk',
                  'Asia/Kuala_Lumpur',
                  'Asia/Kuching',
                  'Asia/Kuwait',
                  'Asia/Macao',
                  'Asia/Macau',
                  'Asia/Magadan',
                  'Asia/Makassar',
                  'Asia/Manila',
                  'Asia/Muscat',
                  'Asia/Nicosia',
                  'Asia/Novokuznetsk',
                  'Asia/Novosibirsk',
                  'Asia/Omsk',
                  'Asia/Oral',
                  'Asia/Phnom_Penh',
                  'Asia/Pontianak',
                  'Asia/Pyongyang',
                  'Asia/Qatar',
                  'Asia/Qyzylorda',
                  'Asia/Rangoon',
                  'Asia/Riyadh',
                  'Asia/Saigon',
                  'Asia/Sakhalin',
                  'Asia/Samarkand',
                  'Asia/Seoul',
                  'Asia/Shanghai',
                  'Asia/Singapore',
                  'Asia/Srednekolymsk',
                  'Asia/Taipei',
                  'Asia/Tashkent',
                  'Asia/Tbilisi',
                  'Asia/Tehran',
                  'Asia/Tel_Aviv',
                  'Asia/Thimbu',
                  'Asia/Thimphu',
                  'Asia/Tokyo',
                  'Asia/Tomsk',
                  'Asia/Ujung_Pandang',
                  'Asia/Ulaanbaatar',
                  'Asia/Ulan_Bator',
                  'Asia/Urumqi',
                  'Asia/Ust-Nera',
                  'Asia/Vientiane',
                  'Asia/Vladivostok',
                  'Asia/Yakutsk',
                  'Asia/Yangon',
                  'Asia/Yekaterinburg',
                  'Asia/Yerevan',
                  'Atlantic/Azores',
                  'Atlantic/Bermuda',
                  'Atlantic/Canary',
                  'Atlantic/Cape_Verde',
                  'Atlantic/Faeroe',
                  'Atlantic/Faroe',
                  'Atlantic/Jan_Mayen',
                  'Atlantic/Madeira',
                  'Atlantic/Reykjavik',
                  'Atlantic/South_Georgia',
                  'Atlantic/St_Helena',
                  'Atlantic/Stanley',
                  'Australia/ACT',
                  'Australia/Adelaide',
                  'Australia/Brisbane',
                  'Australia/Broken_Hill',
                  'Australia/Canberra',
                  'Australia/Currie',
                  'Australia/Darwin',
                  'Australia/Eucla',
                  'Australia/Hobart',
                  'Australia/LHI',
                  'Australia/Lindeman',
                  'Australia/Lord_Howe',
                  'Australia/Melbourne',
                  'Australia/North',
                  'Australia/NSW',
                  'Australia/Perth',
                  'Australia/Queensland',
                  'Australia/South',
                  'Australia/Sydney',
                  'Australia/Tasmania',
                  'Australia/Victoria',
                  'Australia/West',
                  'Australia/Yancowinna',
                  'Brazil/Acre',
                  'Brazil/DeNoronha',
                  'Brazil/East',
                  'Brazil/West',
                  'Canada/Atlantic',
                  'Canada/Central',
                  'Canada/Eastern',
                  'Canada/East-Saskatchewan',
                  'Canada/Mountain',
                  'Canada/Newfoundland',
                  'Canada/Pacific',
                  'Canada/Saskatchewan',
                  'Canada/Yukon',
                  'CET',
                  'Chile/Continental',
                  'Chile/EasterIsland',
                  'CST6CDT',
                  'Cuba',
                  'EET',
                  'Egypt',
                  'Eire',
                  'EST',
                  'EST5EDT',
                  'Etc/GMT',
                  'Etc/GMT+0',
                  'Etc/GMT+1',
                  'Etc/GMT+10',
                  'Etc/GMT+11',
                  'Etc/GMT+12',
                  'Etc/GMT+2',
                  'Etc/GMT+3',
                  'Etc/GMT+4',
                  'Etc/GMT+5',
                  'Etc/GMT+6',
                  'Etc/GMT+7',
                  'Etc/GMT+8',
                  'Etc/GMT+9',
                  'Etc/GMT0',
                  'Etc/GMT-0',
                  'Etc/GMT-1',
                  'Etc/GMT-10',
                  'Etc/GMT-11',
                  'Etc/GMT-12',
                  'Etc/GMT-13',
                  'Etc/GMT-14',
                  'Etc/GMT-2',
                  'Etc/GMT-3',
                  'Etc/GMT-4',
                  'Etc/GMT-5',
                  'Etc/GMT-6',
                  'Etc/GMT-7',
                  'Etc/GMT-8',
                  'Etc/GMT-9',
                  'Etc/Greenwich',
                  'Etc/UCT',
                  'Etc/Universal',
                  'Etc/UTC',
                  'Etc/Zulu',
                  'Europe/Amsterdam',
                  'Europe/Andorra',
                  'Europe/Astrakhan',
                  'Europe/Athens',
                  'Europe/Belfast',
                  'Europe/Belgrade',
                  'Europe/Berlin',
                  'Europe/Bratislava',
                  'Europe/Brussels',
                  'Europe/Bucharest',
                  'Europe/Budapest',
                  'Europe/Busingen',
                  'Europe/Chisinau',
                  'Europe/Copenhagen',
                  'Europe/Dublin',
                  'Europe/Gibraltar',
                  'Europe/Guernsey',
                  'Europe/Helsinki',
                  'Europe/Isle_of_Man',
                  'Europe/Istanbul',
                  'Europe/Jersey',
                  'Europe/Kaliningrad',
                  'Europe/Kiev',
                  'Europe/Kirov',
                  'Europe/Lisbon',
                  'Europe/Ljubljana',
                  'Europe/London',
                  'Europe/Luxembourg',
                  'Europe/Madrid',
                  'Europe/Malta',
                  'Europe/Mariehamn',
                  'Europe/Minsk',
                  'Europe/Monaco',
                  'Europe/Moscow',
                  'Europe/Nicosia',
                  'Europe/Oslo',
                  'Europe/Paris',
                  'Europe/Podgorica',
                  'Europe/Prague',
                  'Europe/Riga',
                  'Europe/Rome',
                  'Europe/Samara',
                  'Europe/San_Marino',
                  'Europe/Sarajevo',
                  'Europe/Saratov',
                  'Europe/Simferopol',
                  'Europe/Skopje',
                  'Europe/Sofia',
                  'Europe/Stockholm',
                  'Europe/Tallinn',
                  'Europe/Tirane',
                  'Europe/Tiraspol',
                  'Europe/Ulyanovsk',
                  'Europe/Uzhgorod',
                  'Europe/Vaduz',
                  'Europe/Vatican',
                  'Europe/Vienna',
                  'Europe/Vilnius',
                  'Europe/Volgograd',
                  'Europe/Warsaw',
                  'Europe/Zagreb',
                  'Europe/Zaporozhye',
                  'Europe/Zurich',
                  'GB',
                  'GB-Eire',
                  'GMT',
                  'GMT+0',
                  'GMT0',
                  'GMT-0',
                  'Greenwich',
                  'Hongkong',
                  'HST',
                  'Iceland',
                  'Indian/Antananarivo',
                  'Indian/Chagos',
                  'Indian/Christmas',
                  'Indian/Cocos',
                  'Indian/Comoro',
                  'Indian/Kerguelen',
                  'Indian/Mahe',
                  'Indian/Maldives',
                  'Indian/Mauritius',
                  'Indian/Mayotte',
                  'Indian/Reunion',
                  'Iran',
                  'Israel',
                  'Jamaica',
                  'Japan',
                  'Kwajalein',
                  'Libya',
                  'MET',
                  'Mexico/BajaNorte',
                  'Mexico/BajaSur',
                  'Mexico/General',
                  'MST',
                  'MST7MDT',
                  'Navajo',
                  'NZ',
                  'NZ-CHAT',
                  'Pacific/Apia',
                  'Pacific/Auckland',
                  'Pacific/Bougainville',
                  'Pacific/Chatham',
                  'Pacific/Chuuk',
                  'Pacific/Easter',
                  'Pacific/Efate',
                  'Pacific/Enderbury',
                  'Pacific/Fakaofo',
                  'Pacific/Fiji',
                  'Pacific/Funafuti',
                  'Pacific/Galapagos',
                  'Pacific/Gambier',
                  'Pacific/Guadalcanal',
                  'Pacific/Guam',
                  'Pacific/Honolulu',
                  'Pacific/Johnston',
                  'Pacific/Kiritimati',
                  'Pacific/Kosrae',
                  'Pacific/Kwajalein',
                  'Pacific/Majuro',
                  'Pacific/Marquesas',
                  'Pacific/Midway',
                  'Pacific/Nauru',
                  'Pacific/Niue',
                  'Pacific/Norfolk',
                  'Pacific/Noumea',
                  'Pacific/Pago_Pago',
                  'Pacific/Palau',
                  'Pacific/Pitcairn',
                  'Pacific/Pohnpei',
                  'Pacific/Ponape',
                  'Pacific/Port_Moresby',
                  'Pacific/Rarotonga',
                  'Pacific/Saipan',
                  'Pacific/Samoa',
                  'Pacific/Tahiti',
                  'Pacific/Tarawa',
                  'Pacific/Tongatapu',
                  'Pacific/Truk',
                  'Pacific/Wake',
                  'Pacific/Wallis',
                  'Pacific/Yap',
                  'Poland',
                  'Portugal',
                  'PRC',
                  'PST8PDT',
                  'ROC',
                  'ROK',
                  'Singapore',
                  'Turkey',
                  'UCT',
                  'Universal',
                  'US/Alaska',
                  'US/Aleutian',
                  'US/Arizona',
                  'US/Central',
                  'US/Eastern',
                  'US/East-Indiana',
                  'US/Hawaii',
                  'US/Indiana-Starke',
                  'US/Michigan',
                  'US/Mountain',
                  'US/Pacific',
                  'US/Pacific-New',
                  'US/Samoa',
                  'UTC',
                  'WET',
                  'W-SU',
                  'Zulu'
end

#parameter 'rrule_override' do
#  category 'Advanced Options'
#  label 'RRULE Override'
#  description "By default, the the iCal RRULE is taken from the scheduler policy."
#  type 'string'
# end

parameter 'polling_frequency' do
  category 'Advanced Options'
  label 'Polling Frequency'
  description 'The regularity to check instances for possible scheduling actions (in minutes).'
  type 'number'
  default 60
  allowed_values 5, 10, 15, 30, 60, 120
end

parameter 'scheduler_dry_mode' do
  category 'Advanced Options'
  label 'Dry Mode'
  type 'string'
  default 'false'
  allowed_values 'true', 'false'
end

parameter 'debug_mode' do
  category 'Advanced Options'
  label 'Debug Mode'
  type 'string'
  default 'false'
  allowed_values 'true', 'false'
end

###
# Local Definitions
###
define audit_log($summary, $details) do
  rs_cm.audit_entries.create(
    notify: "None",
    audit_entry: {
      auditee_href: @@deployment,
      summary: $summary,
      detail: $details
    }
  )
end

define debug_audit_log($summary, $details) do
  if $$debug == true
    rs_cm.audit_entries.create(
      notify: "None",
      audit_entry: {
        auditee_href: @@deployment,
        summary: $summary,
        detail: $details
      }
    )
  end
end

define get_schedule_by_name($ss_schedule_name) return @schedule do
  @schedules = rs_ss.schedules.index()
  @schedule = select(@schedules, { "name": $ss_schedule_name })
end

define get_ss_schedules() return $values do
  @schedules = rs_ss.schedules.get()
  $values = @schedules.name[]
end

define error_server_stop() return $server_stop_error do
  $server_stop_error = "unknown"
  $_error_behavior = "skip"
end

define window_active($start_hour, $start_minute, $start_rule, $stop_hour, $stop_minute, $stop_rule, $tz) return $window_active do
  $params = {
    verb: 'post',
    host: 'bjlaftw4kh.execute-api.us-east-1.amazonaws.com',
    https: true,
    href: '/production',
    headers:{
      'content-type': 'application/json'
    },
    body: {
      'start_hour': $start_hour,
      'start_minute': $start_minute,
      'start_rule': $start_rule,
      'stop_minute': $stop_minute,
      'stop_hour': $stop_hour,
      'stop_rule': $stop_rule,
      'tz': $tz
    }
  }
  call debug_audit_log('window active $params', to_s($params))
  $response = http_request($params)
  call debug_audit_log('window active $response', to_s($response))
  $body = $response['body']
  call debug_audit_log('window active $body', to_s($body))

  $window_active = to_b($body['event_active'])
end

define find_account_name() return $account_name do
  $session_info = rs_cm.sessions.get(view: 'whoami')
  $acct_link = select($session_info[0]['links'], {rel: 'account'})
  $acct_href = $acct_link[0]['href']
  $account_name = rs_cm.get(href: $acct_href).name
end

define get_html_template() return $html_template do
  $response = http_get(
    url: 'https://raw.githubusercontent.com/rightscale/policies/master/templates/email_template.html'
  )
  $html_template = $response['body']
end

define send_html_email($to, $from, $subject, $html) return $response do
  $mailgun_endpoint = 'http://smtp.services.rightscale.com/v3/services.rightscale.com/messages'

  $to = gsub($to, "@", "%40")
  $from = gsub($from, "@", "%40")

  # escape ampersands used in html encoding
  $html = gsub($html, "&", "%26")
  $subject = gsub($subject, "&", "%26")

  $post_body = 'from=' + $from + '&to=' + $to + '&subject=' + $subject + '&html=' + $html

  $response = http_post(
    url: $mailgun_endpoint,
    headers: {"content-type": "application/x-www-form-urlencoded"},
    body: $post_body
  )
end

define send_report($start_count, $stop_count, $email_recipients, $schedule_name, $instances_started, $instances_stopped) return $response do
  call find_account_name() retrieve $account_name

  # email content
  $to = $email_recipients
  $from = 'RightScale Policy <policy-cat@services.rightscale.com>'
  $subject = join(['[', $account_name, ']', ' Instance stop/start scheduler report'])

  call get_html_template() retrieve $html_template

  $body_html = '<html><body><img src="https://assets.rightscale.com/735ca432d626b12f75f7e7db6a5e04c934e406a8/web/images/logo.png" style="width:220px" />
                <p>RightScale started ' + to_s($start_count) + ' instance(s) and stopped ' + to_s($stop_count) + ' instance(s) based on the ' + $schedule_name + ' Self-Service schedule.</p>'

  if $start_count > 0
    $table_rows = ''
    foreach $instance in $instances_started do
      sub on_error: skip do
        call get_server_access_link($instance['href']) retrieve $server_access_link_root
        $table_rows = $table_rows + '<tr><td>' + $instance['name'] + '</td><td>' + $server_access_link_root + '</td><td>started</td></tr>'
      end
    end
  end
  if $stop_count > 0
    $table_rows = ''
    foreach $instance in $instances_stopped do
      sub on_error: skip do
        call get_server_access_link($instance['href']) retrieve $server_access_link_root
        $table_rows = $table_rows + '<tr><td>' + $instance['name'] + '</td><td>' + $server_access_link_root + '</td><td>stopped</td></tr>'
      end
    end
  end
  $body_html = $body_html + '<table><tr><th>Instance Name</th><th>Href</th><th>Action</tr>' + $table_rows + '</table></body></html>'

  $footer_text = 'This report was automatically generated by a policy template Start/Stop Scheduler your organization has defined in RightScale.'

  # render the template
  $html = $html_template
  $html = gsub($html, '{{pre_header_text}}', '')
  $html = gsub($html, '{{title}}', $subject)
  $html = gsub($html, '{{body}}', $body_html)
  $html = gsub($html, '{{footer_text}}', $footer_text)

  call send_html_email($to, $from, $subject, $html) retrieve $response
  call debug_audit_log('mail send response', to_s($response))

  if $response['code'] != 200
    raise 'Failed to send email report: ' + to_s($response)
  end
end

define run_scan($ss_schedule_name, $scheduler_tags_exclude, $scheduler_dry_mode, $polling_frequency, $debug_mode, $timezone_override, $email_recipients) do

  call audit_log('Instance Scheduler scan started', '')

  if $debug_mode == 'true'
    $$debug = true
    call audit_log('Debug mode enabled', '')
  end

  if size($timezone_override) > 0
    $timezone = $timezone_override
  else
    call get_my_timezone() retrieve $timezone
  end

  # set the counters and action stores
  $stop_count = 0
  $start_count = 0
  $instances_started = []
  $instances_stopped = []

  if $ss_schedule_name == 'ALL'
    call get_ss_schedules() retrieve $ss_schedules
  else
    $ss_schedules = [$ss_schedule_name]
  end


  # For each schedule, find candidates, exclude them, start/stop them.
  foreach $ss_schedule in $ss_schedules do
      call audit_log("Starting scan for schedule: " + $ss_schedule, '')
      # get the ss schedule by name and check if the event window is active
      # call get_schedule_by_name($ss_schedule_name) retrieve @schedule
      call get_schedule_by_name($ss_schedule) retrieve @schedule

      # If schedule not found will throw an error so added IF.
      if (size(@schedule) == 0)
        call audit_log("Schedule not found!",'')
      else
        # Schedule is found.
        # formulate variables to check if the schedule window is active
        $start_rule = @schedule.start_recurrence['rule']
        $start_hour = @schedule.start_recurrence['hour']
        $start_minute = @schedule.start_recurrence['minute']
        $stop_rule = @schedule.stop_recurrence['rule']
        $stop_hour = @schedule.stop_recurrence['hour']
        $stop_minute = @schedule.stop_recurrence['minute']


        # get state of schedule window
        call window_active($start_hour, $start_minute, $start_rule, $stop_hour, $stop_minute, $stop_rule, $timezone) retrieve $window_active

        if ($window_active)
          call audit_log($ss_schedule + ' schedule window is currently active: Instances may be started.', '')
        else
          call audit_log($ss_schedule + ' schedule window is currently in-active: Instances may be stopped.', '')
        end

        # only instances tagged with a schedule are candidates for either a stop or start action
        $search_tags = [join(['instance:schedule=', $ss_schedule])]

        $by_tag_params = {
          match_all: 'true',
          resource_type: 'instances',
          tags: $search_tags
        }

        $tagged_resources = rs_cm.tags.by_tag($by_tag_params)
        call debug_audit_log('$tagged_resources', to_json($tagged_resources))

        if type($tagged_resources[0][0]) == 'object'
          call audit_log(to_s(size($tagged_resources[0][0]['links'])) + ' candidate instance(s) found matching ' + to_s($search_tags), to_s($tagged_resources))
          foreach $tagged_resource in $tagged_resources[0][0]['links'] do
            $instance_href = $tagged_resource['href']
            $resource_tags = rs_cm.tags.by_resource(resource_hrefs: [$instance_href])

            $instance_tags = first(first($resource_tags))['tags']
            call debug_audit_log('Tags: ' + $instance_href, to_s($instance_tags))

            $tags_excluded = split($scheduler_tags_exclude, ',')

            # if we find a tag that makes the instance excluded, flag for exlusion
            $excluded = false
            foreach $tag_excluded in $tags_excluded do
              if contains?($instance_tags, [{ name: $tag_excluded }])
                $excluded = true
              end
            end

            @instance = rs_cm.get(href: $instance_href)
            call debug_audit_log('Fetching instance ' + $instance_href, to_s(to_object(@instance)))

            # continue if no exclusion by tag
            if $excluded != true

              $stoppable = /^(running|operational|stranded)$/
              $startable = /^(stopped|provisioned)$/

              # determine if instance should be stopped or started based on:
              # 1. inside or outside schedule
              # 2. current operational state
              if (! $window_active)

                if (@instance.state =~ $stoppable) && (instance.locked == false)
                # stop the instance
                  if $scheduler_dry_mode != 'true'
                    call audit_log('> ' + @instance.name + ': Stopping ...', to_s(@instance))
                    sub on_error: error_server_stop() do
                      @instance.stop()
                      $stop_count = $stop_count + 1
                      $instances_stopped << { href: @instance.href, name: @instance.name }
                    end
                  else
                    call audit_log('> Dry mode: Skipping stop of ' + @instance.name, to_s(@instance.href))
                  end
                else
                  call audit_log('> ' + @instance.name + ': No action - Instance state is ' + to_s(@instance.state), '')
                end
              else
                if (@instance.state =~ $startable)
                # start the instance
                  if $scheduler_dry_mode != 'true'
                    call audit_log('> ' + @instance.name + ': Starting ...', to_s(@instance))
                    @instance.start()
                    $start_count = $start_count + 1
                    $instances_started << { href: @instance.href, name: @instance.name }
                  else
                    call audit_log('> Dry mode: Skipping start of ' + @instance.name, to_s(@instance))
                  end
                else
                  call audit_log('> ' + @instance.name + ': No action - Instance state is ' + to_s(@instance.state), '')
                end
              end  #if (! $window_active)
            else #if excluded
              call audit_log('> ' + @instance.name + ' is excluded by tag', to_s(@instance))
            end #if excluded
          end #for each tagged_resource
        else  #if tagged instances found
          call audit_log('No instances found with tags matching ' + to_s($search_tags), to_s($results))
        end #if tagged instances found
      end #if schedule
  end  #end foreach ss_schedule

      # email report
  if ($stop_count > 0 || $start_count > 0) && (size($email_recipients) > 0)
        call audit_log('Sending report to ' + $email_recipients, $email_recipients)
        call send_report($start_count, $stop_count, $email_recipients, $ss_schedule_name, $instances_started, $instances_stopped)
  end

  call audit_log('Instance Scheduler scan finished', '')
end

define get_user_preference_infos() return @user_preference_infos do
  @user_preference_infos = rs_ss.user_preference_infos.get(filter: ['user_id==me'])
end

define get_my_timezone() return $timezone do
  @user_preference_infos = rs_ss.user_preference_infos.get(filter: ['user_id==me'])
  @user_prefs = rs_ss.user_preferences.get(filter: ['user_id==me', 'user_preference_info_id==' + @user_preference_infos.id])
  if @user_prefs.value
    $timezone = @user_prefs.value
  else
    $timezone = @user_preference_infos.default_value
  end
end

define setup_scheduled_scan($polling_frequency, $timezone) do
  sub task_label: "Setting up scan scheduled task" do
    # use http://coderstoolbox.net/unixtimestamp/ to calculate
    # we assume setting in past works ok because calculating the first
    # real schedule would be non-trivial
    $recurrence = 'FREQ=MINUTELY;INTERVAL=' + $polling_frequency
    # RFC-2822 Mon, 25 Jul 2016 03:00:00 +10:00
    $first_occurrence = "2016-07-25T03:00:00+10:00"

    call audit_log("Scan schedule: " + join([$recurrence, " with first on ", $first_occurrence]), join([$recurrence, " with first on ", $first_occurrence]))

    rs_ss.scheduled_actions.create(
                                    execution_id:     @@execution.id,
                                    name:             "Run instance scan",
                                    action:           "run",
                                    operation:        { "name": "run_scan" },
                                    recurrence:       $recurrence,
                                    timezone:         $timezone,
                                    first_occurrence: $first_occurrence
                                  )
  end
end

###
# Launch Definition
###
define launch_scheduler($ss_schedule_name, $scheduler_tags_exclude, $scheduler_dry_mode, $polling_frequency, $debug_mode, $timezone_override, $email_recipients) do
  call audit_log('Instance scheduler started for ' + $ss_schedule_name + ' schedule(s).', $ss_schedule_name)

  if size($timezone_override) > 0
    $timezone = $timezone_override
  else
    call get_my_timezone() retrieve $timezone
  end
  call audit_log('Using timezone: ' + $timezone, $timezone)

  call setup_scheduled_scan($polling_frequency, $timezone)

  # uncomment to run a scan on cloudapp start
  # call run_scan($cm_instance_schedule_map, $ss_schedule_name, $scheduler_tags_exclude, $scheduler_dry_mode, $polling_frequency, $debug_mode, $timezone_override, $email_recipients)
end

###
# Terminate Definition
###
define terminate_scheduler() do
  call audit_log('Scheduler terminated', '')
end

###
# Operations
###
operation 'launch' do
  description 'Launch the scheduler.'
  definition 'launch_scheduler'
  label 'Launch'
end

operation 'run_scan' do
  description 'Run the instance scan manually.'
  definition 'run_scan'
  label 'Run Instance Scan'
end

operation 'terminate' do
  description 'Terminate the scheduler.'
  definition 'terminate_scheduler'
end

# create linkable href for email report
define get_server_access_link($instance_href) return $server_access_link_root do

    call find_shard() retrieve $shard
    call find_account_number() retrieve $account_number
    $rs_endpoint = "https://us-"+$shard+".rightscale.com"

    $instance_id = last(split($instance_href, "/"))
    $response = http_get(
      url: $rs_endpoint+"/api/instances?ids="+$instance_id,
      headers: {
      "X-Api-Version": "1.6",
      "X-Account": $account_number
      }
     )
     $instances = $response["body"]
     $instance_of_interest = select($instances, { "href" : $instance_href })[0]

     if $instance_of_interest["legacy_id"] == 'null'
       $legacy_id = "unknown"
     else
       $legacy_id = $instance_of_interest["legacy_id"]
     end

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
