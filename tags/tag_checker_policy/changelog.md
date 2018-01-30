Tag Checker Policy changelog

v2.1
- adding additonal colums to the CSV file attached to email.

v2.0
----
- converting from mailgun to policies_mailer
- adding csv attachment

v1.6
----
- applying the tag policy to volumes. See [README](for details)

v1.5
----
- remove `param_email` requirement and use launched by tag to send emails, and append to `param_email` list.
- Add Delete Resource parameter option if tags missing. See [README](for details)

v1.4
----
- adding advanced tag matching.  See [README](for details)

v1.3
-----
- add regex validation to "email addresses" parameter

v1.2
-----
- bugfix issue [#31](https://github.com/rightscale/policies/issues/31)

v1.1
-----
- update rs_ca_ver to 20161221
- fix null returns for instance details

v1.0
-----
- initial release
