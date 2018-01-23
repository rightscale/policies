Stop/Start Scheduler

**What it does**

Starts or stops instances based on a given schedule."
long_description "This automated policy CloudApp will find instances specifically tagged
for start or stop/terminate based on a specific schedule.

It is recommended to run this CloudApp with the 'Always On' schedule
unless you want to explicitly exclude times that instance(s) could be started or stopped.

For an instance to be a candidate for scheduling actions managed by this CloudApp,
a tag matching the chosen *Schedule Name* parameter (`ss_schedule_name`) should exist on the instance.
Both RightScale-managed servers and plain instances are supported (including all clouds).

The tag value needs to match an existing schedule within the RightScale Self-Service Schedule manager.
The format of the tag is as follows:

    instance:schedule=<name of ss schedule>

For example, within schedule manager, create a new schedule for CloudApps to
run between 7am and 11pm on all weekdays (M,T,W,T,F).
On the desired instance(s), add the tag:

    instance:schedule=7am-11pm Weekdays

The CloudApp will poll the RightScale Cloud Management API frequently, stopping
any instances running after 11pm or on weekends; and start instances that are
currently stopped between 7am and 11pm on any weekday.


Cost

This policy CAT does not launch any instances, and so does not incur any cloud costs.
