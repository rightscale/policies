<img src="https://image.freepik.com/free-icon/white-house-building_318-37808.jpg" align="left" height="48" width="48">

# RightScale Policy CAT Files
## Overview

You can use Cloud Application Templates (CATs) in RightScale Self Service to automate policies. We have created sample policy CATs that you can use as a starting point. These are provided solely as samples under an Apache 2.0 open source license with no warranties.

**Important: You should test these CATs to ensure they work for your needs.**

## Sample Policy CATs

### Unattached Volume Finder
**What it does**

This policy CAT will search all your cloud accounts that are connected to the RightScale account where you are running the CAT. It will find unattached volumes that are have been unattached for longer than a specified number of days.

You can choose to **Alert only** or **Alert and Delete** the volumes. **_Warning: Deleted volumes cannot be recovered_**.  We strongly recommend that you **start with Alert only** so that you can review the list and ensure that the volumes should actually be deleted. You can specify multiple email addresses that should be alerted and each email will receive a report with a list of unattached volumes.

<img src="https://github.com/rs-services/policy-cats/blob/master/readme_images/volume_email_screenshot.png" width="600">

The emails in the sample CAT are sent using a shared RightScale account of a free email service (mailgun). We have used a proxy, however, you may want to modify the CAT to use your own email service.

**Scheduling when the policy runs**

To control the frequency that the policy CAT runs, you should [create a schedule and associate it with the CAT](http://docs.rightscale.com/ss/guides/ss_creating_schedules.html) in RightScale Self-Service.

Specify the days of the week that you want the CAT to run. For example, if you want the policy CAT to run once a week on Monday, specify a schedule of only Monday. For the hours you should specify approximately a 30 minute time window for the policy CAT to complete. (It should take less than 15 minutes to run).

<img src="https://github.com/rs-services/policy-cats/blob/master/readme_images/create_a_new_schedule.png">

**Cost**

This policy CAT does not launch any instances, and so does not incur any cloud costs.






### Instance Runtime Policy

**What it does**

This policy CAT will search all your cloud accounts that are connected to the RightScale account where you are running the CAT. It will find instances that have been running for longer than a specified number of days.

This policy might be useful in demo, training, development, or test accounts where instances should not be running for a long period of time.

You can choose to **Alert only** or **Alert and Terminate** the instances. We strongly recommend that you start with **Alert only** so that you can review the list and ensure that the instances should actually be terminated. **_Warning: Terminated instances cannot be recovered._** You can specify multiple email addresses that should be alerted and each email will receive a report with a list of long-running instances.


**Notifications (Email)**

The emails in the sample CAT are sent using a shared RightScale account of a free email service (mailgun). We have used a proxy, however, you may want to modify the CAT to use your own email service.

<img src="https://github.com/rs-services/policy-cats/blob/master/readme_images/long_running_instance_screenshot.png" width="600">

**Scheduling when the policy runs**

To control the frequency that the policy CAT runs, you should [create a schedule and associate it with the CAT](http://docs.rightscale.com/ss/guides/ss_creating_schedules.html) in RightScale Self-Service.

Specify the days of the week that you want the CAT to run. For example, if you want the policy CAT to run once a week on Monday, specify a schedule of only Monday. For the hours you should specify approximately a 30 minute time window for the policy CAT to complete. (It should take less than 15 minutes to run).

<img src="https://github.com/rs-services/policy-cats/blob/master/readme_images/create_a_new_schedule.png">

**Cost**

This policy CAT does not launch any instances, and so does not incur any cloud costs.




### Shutdown Scheduler

**What it does**

This policy CAT will find instances specifically tagged for shutdown or termination and applies that action once the shutdown date in the tag value is reached or exceeded.

**Scheduling when the policy runs**

It is recommended to run the CloudApp using the "Always On" schedule unless you want to explicitly exclude times that instances could be shutdown.


**Usage**

To be a candidate for actions managed by this CAT:
- instances must have a tag matching `instance:shutdown_datetime` or `instance:terminate_datetime` with a datestamp set as the value
- Optionally, A UTC/GMT offset (e.g. +1000) can be supplied to ensure the action occurs at UTC + the offset

The tag format is as follows:

For shutdown (stop):
```
instance:shutdown_datetime=<YYYY/MM/DD hh:mm AM|PM +0000>
```

For terminate:
```
instance:terminate_datetime=<YYYY/MM/DD hh:mm AM|PM +0000>
```

Time is in the format: YYYY/MM/DD hh:mm AM or PM +0000 (e.g. 2017/07/16 07:20 PM +0100).

An example tag requiring the instance to shutdown (stop) on the 2nd March 2017 at 8am Australian Eastern Daylight Time which is UTC +11hrs:
```
instance:shutdown_datetime=2017/03/02 08:00 AM +1100

```

An example tag to terminate the instance on the 3rd March 2017 at 8pm Pacific Standard Time:

```    
instance:terminate_datetime=2017/03/03 08:00 PM -0800
```

**Cost**

This policy CAT does not launch any instances, and so does not incur any cloud costs.






### Pingdom Security Group Policy

**What it does**

This policy CAT will maintain security group rules based on the current active probes published by Pingdom's public feed [ https://my.pingdom.com/probes/feed ]. This policy can be used to enable monitoring on resources that otherwise are restricted to internal / non-public access.

It checks periodically and validates only the IPs published have rules created for them in the Security Groups specified on launch.  There is a total of 4 Security Groups that are maintained, one for each region [North America, Europe, Asia-Pacific], and a "Misc" for overflow if a security group reaches it's max rule limit [AWS].

**Scheduling when the policy runs**

It is recommended to run the CloudApp using the "Always On" schedule unless you want to explicitly exclude times that instances could be shutdown.  You can adjust how frequently the CloudApp checks and attempts to update the Security Groups, but we recommend the default of 1 minute which is the minimum.

**Usage**

You must first create the 4 Security Groups that will be managed by the Policy CAT [i.e. pingdom_https_NA, pingdom_https_EU, pingdom_https_APAC, pingdom_https_Misc].  Ideally these would be new, empty security groups specific for allowing Pingdom probes to the desired start:end port(s).  You will need to save the Security Group HREF for each Security Group which will be used when Launching the Policy CAT.  The Security Group Href can be retrieved from the RightScale Platform's UI or API [i.e. `/api/clouds/123/security_groups/ABCD123456`]

Once the security groups are created, they should be attached to the cloud resources you wish to expose to Pingdom.  Rules will be added and removed over time by the Policy CAT and as long as the security group is attached to your resource Pingdom should be able to access the resource for monitoring.

If you wish to open more than one non-consecutive port to Pingdom [i.e. `HTTP 80` & `HTTPS 443`], you will need to launch 2 separate Policy CATs, each managing there own set of 4 Security Groups [8 SGs total].  For Example:

Example Security Group Names for HTTP Policy [startPort:80, endPort:80]
```
pingdom_http_NA
pingdom_http_EU
pingdom_http_APAC
pingdom_http_Misc
```
Example Security Group Names for HTTPS Policy [startPort:443, endPort:443]
```
pingdom_https_NA
pingdom_https_EU
pingdom_https_APAC
pingdom_https_EU
```

**Cost**

This policy CAT does not launch any instances, and so does not incur any cloud costs.






### Fastly Security Group Policy

**What it does**

This policy CAT will maintain security group rules based on the current active probes published by Fastly's public feed [ https://api.fastly.com/public-ip-list ]. This policy can be used to automatically maintain the security group on the CDN origin resources and allow access specifically to Fastly.  The CloudApp checks periodically and validates only the IPs currently published are present in the Security Group specified at launch.  

**Scheduling when the policy runs**

It is recommended to run the CloudApp using the "Always On" schedule unless you want to explicitly exclude times that instances could be shutdown.  You can adjust how frequently the CloudApp checks and attempts to update the Security Groups, but we recommend leaving this at the default value.

**Usage**

You must first create the Security Group that will be managed by the CloudApp [ i.e. fastly_https ].  Ideally this would be new, empty security group, specific for allowing Fastly CDN to the desired start:end port(s) on your CDN origin service(s).  You will need to get the Security Group HREF, which will be used when Launching the Policy CAT.  The Security Group Href can be retrieved from the RightScale Platform's UI or API [i.e. `/api/clouds/123/security_groups/ABCD123456`]

Once the security group is created, it should be attached to the cloud resources you wish to expose to Fastly.  Rules will be added and removed over time by the CloudApp.  As long as the security group is attached to your server(s), Fastly should be able to access the resources as needed.

If you wish to open more than one non-consecutive port to Fastly [i.e. `HTTP 80` & `HTTPS 443`], you will need to launch 2 separate CloudApps, each managing there own specific Security Group [2 SGs total].  For Example:

Example Security Group Name for HTTP Policy [startPort:80, endPort:80]
```
fastly_http
```
Example Security Group Name for HTTPS Policy [startPort:443, endPort:443]
```
fastly_https
```

**Cost**

This policy CAT does not launch any instances, and so does not incur any cloud costs.









### Quench Alert Policy
**What it does**

This policy CAT will quench alerts defined under a RightScale resource [deployment, server_array, server, instance] for a specified amount of time.  The CloudApp has the ability to quench all alerts, or only those alerts that match a certain name [i.e. *cpu*]

<img src="https://github.com/rs-services/policy-cats/blob/master/readme_images/quench_alerts_launchCloudApp.png" width="600">

**Scheduling when the policy runs**

To control the frequency that the policy CAT runs, you should [create a schedule and associate it with the CAT](http://docs.rightscale.com/ss/guides/ss_creating_schedules.html) in RightScale Self-Service.

Specify the days of the week/hours that you want the alerts to be quenched. For example, if you want the policy CAT to quench alerts every day at 3AM, specify a schedule similar to the one below. We recommend having the CloudApp launch a few minutes before the alerts need to be quenched to give the CloudApp time to audit and take the necessary action on discovered alerts.

<img src="https://github.com/rs-services/policy-cats/blob/master/readme_images/quench_alerts_createSchedule.png">

**Cost**

This policy CAT does not launch any instances, and so does not incur any cloud costs.






## How to Use these CATs

1. [Download the policy CAT file from GitHub.](https://github.com/rs-services/policy-cats)
1. Make any desired changes to the policy CAT.
3. Upload and test the policy CAT. Use the Alert only option during testing. **Do not choose Alert and Delete until you are confident you know what will be deleted.**
4. [Create a schedule and associate it with the CAT.](http://docs.rightscale.com/ss/guides/ss_creating_schedules.html)
5. Launch the CAT in Test mode from the Designer screen of RightScale Self-Service using your desired schedule. Running in Test mode from the Designer screen means that only other users with the Designer role can see or run the policy CATs and it will not show in the Self-Service Catalog for other users. **Do not choose Alert and Delete until you are confident you know what will be deleted.**
