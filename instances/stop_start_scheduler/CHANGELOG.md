Stop/Start Scheduler Policy Changelog


v1.2
-----
- Fixed bug when instance name not assigned in Rightscale (IE: name is `-changeme-`) Causing cloudapp to fail
- Adding option to put in tag that will support cloud tags.  'Explicitly include any instances with this tag (only one). After the `=` your schedule name will be used'

v1.1
-----
- Do not try to stop locked instances
- Ignore errors on servers with ephemeral stores

v1.0
-----
- initial release
