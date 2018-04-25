### Unattached Volume Checker

**What it does**

This policy CAT will search all your cloud accounts that are connected to the RightScale account where you are running the CAT. It will find volumes that are unencrypted. You can specify multiple email addresses that should be alerted and each email will receive a report with a list of unencrypted volumes.

The emails in the sample CAT are sent using a shared RightScale account of a free email service (mailgun). We have used a proxy, however, you may want to modify the CAT to use your own email service.

**Cost**

This policy CAT does not launch any instances, and so does not incur any cloud costs.