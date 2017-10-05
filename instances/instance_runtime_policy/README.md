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



