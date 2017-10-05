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
