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


