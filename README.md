# RightScale Policies

## Overview

You can use Cloud Application Templates (CATs) in RightScale Self Service to automate policies. These are provided solely as samples under an Apache 2.0 open source license with no warranties.

**Important: You should test these CATs to ensure they work for your needs.**

## How To Use These Policies

1. [Download the policy CAT file from GitHub.](https://github.com/rightscale/policy-cats)
1. Make any desired changes to the policy CAT.
3. Upload and test the policy CAT. Use the Alert only option during testing. **Do not choose Alert and Delete until you are confident you know what will be deleted.**
4. [Create a schedule and associate it with the CAT.](http://docs.rightscale.com/ss/guides/ss_creating_schedules.html)
5. Launch the CAT in Test mode from the Designer screen of RightScale Self-Service using your desired schedule. Running in Test mode from the Designer screen means that only other users with the Designer role can see or run the policy CATs and it will not show in the Self-Service Catalog for other users. **Do not choose Alert and Delete until you are confident you know what will be deleted.**

## Released Policies

### Alerts
 * [Quench Alert Policy](alerts/quench_alert_policy) 

### Instances
 * [Instance Runtime Policy](instances/instance_runtime_policy)
 * [Shutdown Scheduler Policy](instances/shutdown_scheduler)

### Security Groups
 * [Fastly Security Group Policy](security_groups/fastly_security_group_policy)
 * [Pingdom Security Group Policy](security_groups/pingdom_security_group_policy)

### Tags
 * [Tag Checker Policy](tags/tag_checker_policy)
 * [Volume Tag Sync Policy](tags/volume_tag_sync_policy)

### Volumes
 * [Unattached Volume Policy](volumes/unattached_volume_policy)
 * [Unencrypted Volume Checker Policy](volumes/unencrypted_volume_checker_policy)

## RightScale Cloud Workflow Documentation
- [Cloud Workflow Language](http://docs.rightscale.com/ss/reference/rcl/v2/index.html)
- [Cloud Workflow Functions](http://docs.rightscale.com/ss/reference/rcl/v2/ss_RCL_functions.html)
- [Cloud Workflow Operators](http://docs.rightscale.com/ss/reference/rcl/v2/ss_RCL_operators.html)

## Getting Help
Support for these Policies will be provided though GitHub Issues and the RightScale public slack channel #policies.
Visit http://chat.rightscale.com/ to join!

### Opening an Issue
Github issues contain a template for three types of requests (Bugs, New Features to an existing Policy, New Policy Request)

- Bugs: Any issue you are having with an existing Policy not functioning correctly, this does not include missing features, or actions.
- New Feature Request: Any feature that are to be added to an existing Policy. 
- New Policy Request: Request for a new Policy