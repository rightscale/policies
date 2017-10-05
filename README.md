<img src="https://image.freepik.com/free-icon/white-house-building_318-37808.jpg" align="left" height="48" width="48">

# RightScale Policy CAT Files
## Overview

You can use Cloud Application Templates (CATs) in RightScale Self Service to automate policies. We have created sample policy CATs that you can use as a starting point. These are provided solely as samples under an Apache 2.0 open source license with no warranties.

**Important: You should test these CATs to ensure they work for your needs.**













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






### EC2 Volume Tag Sync Policy
**What it does**

This policy CAT will find EC2 volumes and synchronize the AWS tags to RightScale tags. Synchronization is unidirectional from EC2 to RightScale, and is non destructive. If a tag is removed from the EC2 volume, it will persist in RightScale

This policy CAT will only operate on EC2 regions you have registered in the RightScale dashboard.

**Scheduling when the policy runs**

To control the frequency that the policy CAT runs, you should [create a schedule and associate it with the CAT](http://docs.rightscale.com/ss/guides/ss_creating_schedules.html) in RightScale Self-Service.

Specify the days of the week that you want the CAT to run. For example, if you want the policy CAT to run once a week on Monday, specify a schedule of only Monday. For the hours you should specify approximately a 30 minute time window for the policy CAT to complete. (It should take less than 15 minutes to run).

<img src="https://github.com/rs-services/policy-cats/blob/master/readme_images/create_a_new_schedule.png">

**Cost**

This policy CAT does not launch any instances, and so does not incur any cloud costs.






## How to Use these CATs

1. [Download the policy CAT file from GitHub.](https://github.com/rs-services/policy-cats)
1. Make any desired changes to the policy CAT.
3. Upload and test the policy CAT. Use the Alert only option during testing. **Do not choose Alert and Delete until you are confident you know what will be deleted.**
4. [Create a schedule and associate it with the CAT.](http://docs.rightscale.com/ss/guides/ss_creating_schedules.html)
5. Launch the CAT in Test mode from the Designer screen of RightScale Self-Service using your desired schedule. Running in Test mode from the Designer screen means that only other users with the Designer role can see or run the policy CATs and it will not show in the Self-Service Catalog for other users. **Do not choose Alert and Delete until you are confident you know what will be deleted.**
