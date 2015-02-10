name "ABC Three Tier POC Windows V4"
rs_ca_ver 20131202
short_description '![Disney](https://s3.amazonaws.com/disney-demo-images/disney_logo.jpg)
![Win](https://s3.amazonaws.com/selfservice-logos/logo_w12.png)  

ABC Three Tier POC Windows'
long_description 'Launch a 3 Tier Windows IIS Application'

#----------------------------------------------
#PARAMETERS
#----------------------------------------------
parameter "cloud_param" do
  type "string"
  label "Cloud"
  category "Cloud"
  allowed_values "vmWare (Private)", "AWS (Public)"
  operations "launch"
end

parameter "dns_app_domain" do
  type "string"
  label "DNS Domain"
  category "DNS"
  description "Application DNS Domain"
  operations "launch"
end

parameter "dns_app_name" do
  type "string"
  label "Application DNS Name"
  category "DNS"
  description "Application DNS Name"
  operations "launch"
end

parameter "dns_app_record_id" do
  type "string"
  label "Application DNS Record ID"
  category "DNS"
  description "Application DNS Record ID"
  operations "launch"
end

parameter "dns_db_record_id" do
  type "string"
  label "DB DNS Record ID"
  category "DNS"
  description "DB DNS Record ID"
  operations "launch"
end

parameter "dns_app_fqdn" do
  type "string"
  label "Application DNS FQDN"
  category "DNS"
  description "Application DNS FQDN"
  operations "launch"
end

parameter "dns_db_fqdn" do
  type "string"
  label "DB DNS FQDN"
  category "DNS"
  description "DB DNS FQDN"
  operations "launch"
end

parameter "db_name" do
  type "string"
  label "DB Name"
  category "DB"
  description "DB Name"
  operations "launch"
end

parameter "app_package_file_name" do
  type "string"
  label "MSDeploy Package Name"
  category "Application"
  description "MSDeploy Application Name"
  operations "launch"
end

parameter "db_bak_file_name" do
  type "string"
  label "SQL Backup File Name"
  category "Application"
  description "SQL Backup File Name"
  operations "launch"
end

#----------------------------------------------

#----------------------------------------------
#MAPPINGS
#----------------------------------------------
mapping "cloud_to_stuff_mapping" do {
  "vmWare (Private)" => {
    "cloud_name" => "RS-PS VM Test Env",
    "ssh_key_name" => "MRP-VMTESTENV",
    "datacenter_names" => "RCAV3",
    "multi_cloud_image_name" => "VMTest-RightImage_CentOS_6.6_x64_v14.2_Dev2_c5ff86f7d6d2cc",
    #"security_group_name" => "",
    "instance_type_name" => "small"
  },
  "AWS (Public)" => {
    "cloud_name" => "EC2 us-east-1",
    "ssh_key_name" => "MRP-US-Key",
    "datacenter_names" => "us-east-1d,us-east-1d",
    #"multi_cloud_image_name" => "VMTest-RightImage_CentOS_6.6_x64_v14.2_Dev2_c5ff86f7d6d2cc",
    "security_group_name" => "PS-REFARCH-WIN-3T",
    "instance_type_name" => "c3.large"
  }
} end
#----------------------------------------------


#----------------------------------------------
#RESOURCES
#----------------------------------------------


resource "lb1_server", type: "server" do
  name "T1-LB-HAPROXY-01"
  cloud map($cloud_to_stuff_mapping, $cloud_param, "cloud_name")
  ssh_key map($cloud_to_stuff_mapping, $cloud_param, "ssh_key_name")
  security_groups map($cloud_to_stuff_mapping, $cloud_param, "security_group_name")
  multi_cloud_image map($cloud_to_stuff_mapping, $cloud_param, "multi_cloud_image_name")
  datacenter first(split(map($cloud_to_stuff_mapping, $cloud_param, "datacenter_names"),","))
  server_template find("RSPS - POC Load Balancer with HAProxy (v14.1.0)", revision: 0)
  instance_type map($cloud_to_stuff_mapping, $cloud_param, "instance_type_name")
  inputs do {
    'DNSMADEEASY_PASSWORD' => 'cred:DNSMADEEASY_PASSWORD',
	'DNSMADEEASY_USER' => 'cred:DNSMADEEASY_USER',
	'DNS_ID_EXTERNAL' => join(["text:",$dns_app_record_id]),
	'rs-haproxy/health_check_uri' => 'text:/default.aspx HTTP/1.1\r\nHost:rspocdisneywvapp.rightscale-services.com'
  } end
end

resource 'iis_01_server', type: 'server' do
  name 'T2-IIS-WIN2012STD-01'
  cloud map($cloud_to_stuff_mapping, $cloud_param, "cloud_name")
  server_template find("RSPS - POC Microsoft IIS App Server (v14.2)", revision: 0)
  ssh_key map($cloud_to_stuff_mapping, $cloud_param, "ssh_key_name")
  security_groups map($cloud_to_stuff_mapping, $cloud_param, "security_group_name")
  multi_cloud_image map($cloud_to_stuff_mapping, $cloud_param, "multi_cloud_image_name")
  datacenter first(split(map($cloud_to_stuff_mapping, $cloud_param, "datacenter_names"),","))
  inputs do {
      'DB_USER_PASSWORD' => 'text:RightScale2013',
	  'IIS_SITE_HOST_HEADER' => join(["text:",$dns_app_fqdn]),
	  'DB_NAME' => 'text:RSPOCUMB',
	  'IIS_SITE_NAME' => 'text:rsumbpoc',
	  'IIS_SITE_PORT' => 'text:8000',
	  'SYS_WINDOWS_TZINFO' => 'text:(UTC) UTC',
	  'DB_USER' => 'text:rspocumb',
	  'APP_DB_FQDN' => join(["text:",$dns_db_fqdn]),
	  'ADMIN_PASSWORD' => 'text:RightScale2013',
	  'REMOTE_STORAGE_CONTAINER_APP' => 'text:rightscale-services',
      'STORAGE_FILE_NAME' => join(["text:",$app_package_file_name])
  } end
end

resource 'db_01_server', type: 'server' do
  name 'T2-SQL-WIN2012STD-01'
  cloud map($cloud_to_stuff_mapping, $cloud_param, "cloud_name")
  server_template find("RSPS - POC Database Manager for Microsoft SQL Server", revision: 0)
  ssh_key map($cloud_to_stuff_mapping, $cloud_param, "ssh_key_name")
  security_groups map($cloud_to_stuff_mapping, $cloud_param, "security_group_name")
  #multi_cloud_image map($cloud_to_stuff_mapping, $cloud_param, "multi_cloud_image_name")
  datacenter first(split(map($cloud_to_stuff_mapping, $cloud_param, "datacenter_names"),","))
  inputs do {
    'DNS_DOMAIN_NAME' => join(["text:",$dns_app_domain]),
	'ADMIN_PASSWORD' => 'text:RightScale2013',
    'DB_NAME' => 'text:RSPOCUMB',
	'BACKUP_FILE_NAME' => join(["text:",$db_bak_file_name]),
    'DATA_VOLUME_SIZE' => 'text:100',
	'LOGS_VOLUME_SIZE' => 'text:100',
    'DNS_PASSWORD' => 'cred:DNSMADEEASY_PASSWORD',
    'DNS_ID' => join(["text:",$dns_db_record_id]),
    'DNS_SERVICE' => 'text:DNS Made Easy',
    'DNS_USER' => 'cred:DNSMADEEASY_USER',
    'DB_NEW_LOGIN_PASSWORD' => 'text:RightScale2013',
    'SYS_WINDOWS_TZINFO' => 'text:(UTC) UTC',
    'DB_NEW_LOGIN_NAME' => 'text:rspocumb',
    'DB_LINEAGE_NAME' => 'text:RSPOCUMB'
  } end
end
#----------------------------------------------

#----------------------------------------------
#DEFINITIONS
#----------------------------------------------
define create_env(@db_01_server, @lb1_server, @iis_01_server) task_label: "Launch Servers" do
  provision(@db_01_server)
  provision(@lb1_server)
  provision(@iis_01_server)
end

define deploy_code_update() do
  $t = ""
end
#----------------------------------------------

#----------------------------------------------
#OPERATIONS
#----------------------------------------------
operation 'launch' do
  description 'Launch the application'
  definition 'create_env'
end

operation 'Deploy Code Update' do
  description "Deploy Code Update"
  definition "deploy_code_update"
end

#----------------------------------------------

#----------------------------------------------
#OUTPUTS
#----------------------------------------------
output "out_app_fqdn" do
  label "Application FQDN"
  category "Application"
  default_value $dns_app_fqdn
  description "Application FQDN"
end

output "lb1_haproxy_output" do
  label "Load Balancer 1 haproxy-status"
  category "LB"
  default_value join(["http://",@lb1_server.public_ip_address,"/haproxy-status"])
  description "Application URL"
end

output "iis_server_ip_output" do
  label "Server IP"
  category "IIS"
  default_value join(["IP address: ", tag_value(@lb1_server, "server:private_ip_0")]) 
  description "IP Address"
end

output "db_server_ip_output" do
  label "Server IP"
  category "Database"
  default_value join(["IP address: ", tag_value(@db_01_server, "server:private_ip_0")]) 
  description "SQL IP Address"
end

#----------------------------------------------
