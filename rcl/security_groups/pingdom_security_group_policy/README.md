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


