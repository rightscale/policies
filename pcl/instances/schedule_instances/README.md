***Schedule Instances Policy***

**What it does**

Starts or stops instances based on a given schedule.

This automated policy  will find instances specifically tagged
for start or stop based on a specific schedule.

For an instance to be a candidate for scheduling actions managed by this Policy,
a tag matching the chosen *Schedule Name* parameter (`ss_schedule_name`) should exist on the instance.
Both RightScale-managed servers and plain instances are supported (including all clouds).

The tag value needs to match an existing schedule within the RightScale Self-Service Schedule manager.
The format of the tag is as follows:

    instance:schedule=<name of ss schedule>

For example, within schedule manager, create a new schedule for CloudApps to
run between 7am and 11pm on all weekdays (M,T,W,T,F).
On the desired instance(s), add the tag:

    instance:schedule=7am-11pm Weekdays

The Policy will poll the RightScale Cloud Management API frequently, stopping
any instances running after 11pm or on weekends; and start instances that are
currently stopped between 7am and 11pm on any weekday.  The time in the schedule is based on the
users timezone.  You can override the timezone with the Timezone Override parameter.

**Parameters**

| Name | Description |
|------|-------------|
| Schedule | One or more Self-Service Schedules separated by comma. |
| Timezone Override | Select the timezone to override the users timezone |
| Action | The action to take on the instances found.  Stop or Stop and Start |
| Exclude Tags | Comma separated list of tags to exclude from action. |
| Email Addresses| Comma separated list of email addresses to notify of actions taken.|

**Cost**

This policy CAT does not launch any instances, and so does not incur any cloud costs.
