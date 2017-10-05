# RightScale Policy CAT Files

## Overview

You can use Cloud Application Templates (CATs) in RightScale Self Service to automate policies. We have created sample policy CATs that you can use as a starting point. These are provided solely as samples under an Apache 2.0 open source license with no warranties.

**Important: You should test these CATs to ensure they work for your needs.**


## Released CAT Files

### Alerts
 * [Quench Alert Policy](alerts/quench_alert_policy) 

### Instances
 * [Instance Runtime Policy](instances/instance_runtime_policy)
 * [Shutdown Scheduler](instances/shutdown_scheduler)

### Security Groups
 * [Fastly Security Group Policy](security_groups/fastly_security_group_policy)
 * [Pingdom Security Group Policy](security_groups/pingdom_security_group_policy)

### Tags
 * [Tag Checker Policy](tags/tag_checker_policy)
 * [Volume Tag Sync Policy](tags/volume_tag_sync_policy)

### Volumes
 * [Unattached Volume Policy](volumes/unattached_volume_policy)

## How to Use these CATs

1. [Download the policy CAT file from GitHub.](https://github.com/rightscale/policy-cats)
1. Make any desired changes to the policy CAT.
3. Upload and test the policy CAT. Use the Alert only option during testing. **Do not choose Alert and Delete until you are confident you know what will be deleted.**
4. [Create a schedule and associate it with the CAT.](http://docs.rightscale.com/ss/guides/ss_creating_schedules.html)
5. Launch the CAT in Test mode from the Designer screen of RightScale Self-Service using your desired schedule. Running in Test mode from the Designer screen means that only other users with the Designer role can see or run the policy CATs and it will not show in the Self-Service Catalog for other users. **Do not choose Alert and Delete until you are confident you know what will be deleted.**
