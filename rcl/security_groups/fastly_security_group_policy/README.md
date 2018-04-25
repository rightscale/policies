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
