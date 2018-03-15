### Unattached Volume Finder

**What it does**

This policy CAT will search all your cloud accounts that are connected to the RightScale account where you are running the CAT. It will find unattached volumes that are have been unattached for longer than a specified number of days.

You can choose to **Alert only** or **Alert and Delete** the volumes. **_Warning: Deleted volumes cannot be recovered_**.  We strongly recommend that you **start with Alert only** so that you can review the list and ensure that the volumes should actually be deleted. You can specify multiple email addresses that should be alerted and each email will receive a report with a list of unattached volumes. **Note:** you will NOT receive an email if no unattached volumes are discovered. 


## Supported Clouds
The following clouds are supported:
- AWS
- Azure Classic
- Azure Resource Manager
- Google
- Openstack
- Rackspace
- Softlayer
- VMware
<img src="imgs/volume_email_screenshot.png" width="600">

**Cost**

This policy CAT does not launch any instances, and so does not incur any cloud costs.
