### Azure Superseded Instance Types

**What it does**

The Azure Superseded Instance Types Policy will scan all instances in an ARM Subscription, targeting disallowed instance types for reporting and/or automated resizing.  All API calls are made directly to the Azure APIs, and therefore RightLink is not a prerequisite.

The Policy will schedule the first scan to occur 10min after launch, and will target all instances that have one of the disallowed instance types.  This scan will then run every day at the same time. Instances that have the specified Exclusion Tag (Azure-native instance tag, defined in a CAT parameter) will not be included in the instances report.

Instances that have a valid tag value (Azure-native instance tag, defined in a CAT parameter) for the Schedule Tag Namespace tag, will be scheduled to be resized at the specified date/time.

Parameter notes:

- *Instance Type Mapping:* This parameter should be a JSON string of Disallowed:Replacement instance types.  The parameter can also be a publicly accessible URL of your JSON.  Example value:
```json
    {
      "Standard_D3": "Standard_D3_v2",
      "Standard_D2": "Standard_D2_v2",
      "Standard_D1": "Standard_D2_v2"
    }
```

- *Schedule Tag Namespace:* This parameter defines the Azure-native tag namespace used when determining when to schedule the resizing of the instance. **NOTE:** When setting the tag value in Azure, it must match the following format: `yyyy-mm-ddThh:mm:ss`.  For example: `2018-01-01T14:30:00`.  All times should be set in UTC.

- *Exclusion Tag:* Azure-native tag namespace:value that identifies instances that should not appear in reports and should therefore not be considered for automated resizing. Example value:
```json
  {"exclude_resize": "true"}
```

Note that if a Resize Schedule tag value is updated in Azure, the scheduled action in RightScale will not be automatically updated.  In order to accommodate this use case, manually execute the `clear_scheduled_actions` operation from the running CloudApp. At the next scheduled action for the `scan_instances` operation, all scheduled actions will be recreated based on the current Resize Schedule tag values.

Required RightScale Credentials:
  - AZURE_TENANT_ID
  - AZURE_APPLICATION_ID
  - AZURE_APPLICATION_KEY

**Dependencies**
  - [sys_log](https://github.com/rightscale/rightscale-plugins/blob/master/libraries/sys_log.rb)
  - [mailer](https://github.com/rightscale/policies/blob/master/libraries/mailer.rb)
  - [rs_azure_compute plugin](https://github.com/rightscale/rightscale-plugins/blob/master/azure/rs_azure_compute/azure_compute_plugin.rb)

**Notifications (Email)**

The emails in the sample CAT are sent using a shared RightScale account of a free email service. We have used a proxy, however, you may want to modify the CAT to use your own email service.

**Scheduling when the policy runs**

The CloudApp for this policy should always be Running.  The functionality is based on Self-Service Scheduled Actions, as opposed to a runtime schedule.

**Cost**

This policy CAT does not launch any instances, and so does not incur any cloud costs.  It does make API calls to the Azure API, and therefore those calls will count against API limits.
