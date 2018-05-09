parameter "instance_tags" do
	type "list"
	label "List of tags used to filter instances that policy applies to. Instances must have all listed tages to be considered."
	pattern ".+=.+"
end

parameter "allowed_port_ranges" do
	type "list"
	label `List of authorized public open port ranges. Items in the list must be of the form "port" or "from-to". Example: "22", "443-444".`
	pattern "[0-9]+(-[0-9]+)?"
end

auth "aws_us_east_1", type: "aws" do
	version 4
	service 'ec2'
	region "us-east-1"
	access_key cred('AWS_ACCESS_KEY_ID')
	secret_key cred('AWS_SECRET_ACCESS_KEY')
end

pagination "aws_pagination", type: "aws"

escalation "alert" do
   template <<-EOS
Unexpected Open Ports

The following instances have unexpecterd open ports on public interfaces:

{ range data.sources }
* Instance ID: {$.instance.id}
* Instance Tags: {$.instance.tag_set}
* IP Ranges: {$.perm.ip_ranges}
* From port: {$.perm.from}
* To port: {$.perm.to}
{ end }
EOS

   email $escalate_to
end

script "get_open_ports", type: "javascript" do
	parameters "instances", "groups", "allowed"
	result "perms"
# can be
# result do
#   field "a", "js_var_1"
#   field "b", "js_var_2"
# end
	code <<-EOS
var perms = [];
for (i = 0; i < instances.length; i++) {
	inst = instances[i];
	if inst.ip_address == "" {
		break;
	}
	if inst.state != "running" {
		break;
	}
	if inst.groups.length == 0 {
		break;
	}
	for (j = 0; j < inst.groups.length; j++) {
		igrp = inst.groups[j];
		for (k = 0; k < groups; k++) {
			group = groups[k];
			if group.id != igrp.id {
				continue;
			}
			for (l = 0; l < group.permissions.length; l++) {
				perm = group.permissions[l];
				if perm.ip_ranges.length == 0 {
					continue; // group based permissions
				}
				pfrom = perm.from;
				if pfrom == "" {
					pfrom = "1"
				}
				pto = perm.to;
				if pto == "" {
					pto = "65535"
				}
				ok = false;
				if allowed.length > 0 {
					for (m = 0; m < allowed.length; m++) {
						elems := allowed.split("-");
						to = elems[0];
						from = elems[1];
						if from == undefined {
							from = to;
						}
						if from >= pfrom && to <= pto {
							ok = true;
						  break;
						}
					}
				}
				if ok {
					continue;
				}
				perms.push({"perm": perm, "instance": inst})
			}
		}
	}
}
	EOS
end

data_source "sgs_us_east" do
	auth $aws_us_east_1
  pagination $aws_pagination
	request do
		host "ec2.amazonaws.com"
		query "Action", "DescribeSecurityGroups"
	end
	result do
    collect xpath(data, "/DescribeSecurityGroupsResponse/securityGroupInfo/item") do # data refers to response
			field "id", xpath(item, "groupId")
			field "permissions" do
				collect xpath(item, "ipPermissions/item") do 
					field "protocol", xpath(item, "ipProtocol")
					field "from", xpath(item, "fromPort")
					field "to", xpath(item, "toPort")
					field "ip_ranges" do
						collect xpath(item, "ipRanges/item") do
							field "cidr", xpath("cidrIp")
						end
					end
				end
			end
		end
	end
end

data_source "instances_us_east" do
	auth $aws_us_east_1
  pagination $aws_pagination
	request do
		host "ec2.amazonaws.com"
		query "Action", "DescribeInstances"
		collect $instance_tags do
			query "Filter.{index}.Name", get(split(item, "="), 0)
			query "Filter.{index}.Value.1", get(split(item, "="), 1) 
		end
	end
	result do
    collect xpath(data, "/DescribeInstancesResponse/reservationSet/item/instancesSet/item") do # data refers to response
			field "id", xpath(item, "instanceId")
			field "tag_set", xpath(item, "tagSet/item")
			field "ip_address", xpath(item, "ipAddress")
			field "state", xpath(item, "instanceState/name")
			field "groups" do
				collect xpath(item, "groupSet/item") do
					field "id", xpath(item, "groupId")
				end
			end
		end
	end
end

data_source "open_ports_us_east" do
	run_script $get_open_ports, $instances_us_east, $sgs_us_east, $allowed_port_ranges
end

policy "open_ports_checker" do
	validate $open_ports_us_east do
		escalate $alert
		check gt(count(data, 0))
	end
end