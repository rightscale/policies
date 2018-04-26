### Azure Superseded Instance Types

**What it does**



**Dependencies**
  - [sys_log](https://github.com/rightscale/rightscale-plugins/blob/master/libraries/sys_log.rb)
  - [mailer](https://github.com/rightscale/policies/blob/master/libraries/mailer.rb)
  - [rs_azure_compute plugin](https://github.com/rightscale/rightscale-plugins/blob/master/azure/rs_azure_compute/azure_compute_plugin.rb)

**Notifications (Email)**

The emails in the sample CAT are sent using a shared RightScale account of a free email service. We have used a proxy, however, you may want to modify the CAT to use your own email service.

**Scheduling when the policy runs**

**Cost**

This policy CAT does not launch any instances, and so does not incur any cloud costs.  It does make API calls to the Azure API, and therefore those calls will count against API limits.
