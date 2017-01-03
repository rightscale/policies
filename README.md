<a href="url"><img src="https://image.freepik.com/free-icon/white-house-building_318-37808.jpg" "RightScale Policy" align="left" height="48" width="48" ></a>
#RightScale Policy CAT Files
##Overview

You can use Cloud Application Templates (CATs) in RightScale Self Service to automate policies. We have created sample policy CATs that you can use as a starting point. These are provided solely as samples under an Apache 2.0 open source license with no warranties.

**Important: You should test these CATs to ensure they work for your needs.**

##Sample Policy CATs

###Unattached Volume Finder
**What it does**

This policy CAT will search all your cloud accounts that are connected to the RightScale account where you are running the CAT. It will find unattached volumes that are have been unattached for longer than a specified number of days.

You can choose to **Alert only** or **Alert and Delete** the volumes. **_Warning: Deleted volumes cannot be recovered_**.  We strongly recommend that you **start with Alert only** so that you can review the list and ensure that the volumes should actually be deleted. You can specify multiple email addresses that should be alerted and each email will receive a report with a list of unattached volumes.

The emails in the sample CAT are sent using a shared RightScale account of a free email service (mailgun). We have used a proxy, however, you may want to modify the CAT to use your own email service.

**Scheduling when the policy runs**
To control the frequency that the policy CAT runs, you should [create a schedule and associate it with the CAT](http://docs.rightscale.com/ss/guides/ss_creating_schedules.html) in RightScale Self-Service.


###Long Running Instances


##Usage
