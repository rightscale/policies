# Change Log

## [Week-of-01-29-2018](https://github.com/rightscale/policies/tree/Week-of-01-29-2018) (2018-02-01)
[Full Changelog](https://github.com/rightscale/policies/compare/Week-of-01-22-2018...Week-of-01-29-2018)

**Implemented enhancements:**

- Tag Checker Policy: Enhance Email Fields [\#46](https://github.com/rightscale/policies/issues/46)

**Merged pull requests:**

- Tag Checker: Adding additional columns to CSV File [\#70](https://github.com/rightscale/policies/pull/70) ([cdwilhelm](https://github.com/cdwilhelm))

## [Week-of-01-22-2018](https://github.com/rightscale/policies/tree/Week-of-01-22-2018) (2018-01-24)
[Full Changelog](https://github.com/rightscale/policies/compare/Week-of-01-15-2018...Week-of-01-22-2018)

**Implemented enhancements:**

- Tag Checker Policy: Add "Delete Resource" option if missing tags [\#43](https://github.com/rightscale/policies/issues/43)
- Tag Checker Policy: Extend Tag Checker to support Volume resources [\#40](https://github.com/rightscale/policies/issues/40)
- Policy Library: create a policies cat package that enables a universal email definitions and common parameters  for all policy cats [\#29](https://github.com/rightscale/policies/issues/29)

**Fixed bugs:**

- Start/Stop Scheduler: Exclude non stoppable instances and put error in desc [\#11](https://github.com/rightscale/policies/issues/11)

**Closed issues:**

- Tag\_Checker\_Policy: Error on add\_delete\_date\_tag [\#63](https://github.com/rightscale/policies/issues/63)

**Merged pull requests:**

- Stop/Start Scheduler Policy: updating to ignore locked servers and eph store [\#67](https://github.com/rightscale/policies/pull/67) ([rshade](https://github.com/rshade))
- Stop/Start Scheduler: Updating email template location [\#66](https://github.com/rightscale/policies/pull/66) ([cdwilhelm](https://github.com/cdwilhelm))
- Stop/Start Scheduler Policy: Initial Release [\#64](https://github.com/rightscale/policies/pull/64) ([cdwilhelm](https://github.com/cdwilhelm))
- Tag Checker Policy: Apply tag policy to Volumes [\#62](https://github.com/rightscale/policies/pull/62) ([cdwilhelm](https://github.com/cdwilhelm))
- Tag Checker Policy: Attach CSV File [\#61](https://github.com/rightscale/policies/pull/61) ([rshade](https://github.com/rshade))
- Tag Checker Policy: Add Delete Resource parameter option if tags missing [\#56](https://github.com/rightscale/policies/pull/56) ([cdwilhelm](https://github.com/cdwilhelm))

## [Week-of-01-15-2018](https://github.com/rightscale/policies/tree/Week-of-01-15-2018) (2018-01-18)
[Full Changelog](https://github.com/rightscale/policies/compare/Week-of-12-07-2017...Week-of-01-15-2018)

**Implemented enhancements:**

- Tag Checker Policy: Allow for multiple default tag values across multiple tag keys [\#45](https://github.com/rightscale/policies/issues/45)
- Tag Checker Policy: Adjust Tag Key if Tag Value fails validation [\#44](https://github.com/rightscale/policies/issues/44)
- Tag Checker Policy: Add Tag Value Validation [\#42](https://github.com/rightscale/policies/issues/42)

**Fixed bugs:**

- Tag Checker Policy: Resource report isn't showing Name [\#58](https://github.com/rightscale/policies/issues/58)

**Merged pull requests:**

- Tag Checker Policy: use resource name in report if it's available [\#57](https://github.com/rightscale/policies/pull/57) ([cdwilhelm](https://github.com/cdwilhelm))
- Tag Checker - Allow the user to provide a prefix value for invalid tags values [\#55](https://github.com/rightscale/policies/pull/55) ([cdwilhelm](https://github.com/cdwilhelm))
- Tag Checker - update advanced tags to create missing tag [\#54](https://github.com/rightscale/policies/pull/54) ([cdwilhelm](https://github.com/cdwilhelm))
- Tag Checker - adding advanced tag matching [\#51](https://github.com/rightscale/policies/pull/51) ([cdwilhelm](https://github.com/cdwilhelm))

## [Week-of-12-07-2017](https://github.com/rightscale/policies/tree/Week-of-12-07-2017) (2017-12-07)
[Full Changelog](https://github.com/rightscale/policies/compare/Week-of-11-20-2017...Week-of-12-07-2017)

**Merged pull requests:**

- S3 Buckets ACL Policy [\#38](https://github.com/rightscale/policies/pull/38) ([dfrankel33](https://github.com/dfrankel33))

## [Week-of-11-20-2017](https://github.com/rightscale/policies/tree/Week-of-11-20-2017) (2017-11-22)
[Full Changelog](https://github.com/rightscale/policies/compare/Week-of-11-13-2017...Week-of-11-20-2017)

**Fixed bugs:**

- Tag Checker Policy: Policy tag checker runs very long and abort when there are many resources and tags [\#31](https://github.com/rightscale/policies/issues/31)

**Merged pull requests:**

- Tag Checker - Add validation to Email parameter  [\#36](https://github.com/rightscale/policies/pull/36) ([kramfs](https://github.com/kramfs))
- Tag Checker - Bug Fix for Issue \#31  [\#34](https://github.com/rightscale/policies/pull/34) ([dfrankel33](https://github.com/dfrankel33))

## [Week-of-11-13-2017](https://github.com/rightscale/policies/tree/Week-of-11-13-2017) (2017-11-15)
**Fixed bugs:**

- Long Running Instances Policy: Special character &amp in Account name aborts e-mail content [\#28](https://github.com/rightscale/policies/issues/28)
- Unattached Volumes in ASM [\#9](https://github.com/rightscale/policies/issues/9)

**Merged pull requests:**

- Long Running Instances - Bug Fixes [\#30](https://github.com/rightscale/policies/pull/30) ([rshade](https://github.com/rshade))
- Unencrypted Volume Checker - Initial Release [\#27](https://github.com/rightscale/policies/pull/27) ([stefhen](https://github.com/stefhen))
- Tag Checker - Fix null returns for instance details [\#26](https://github.com/rightscale/policies/pull/26) ([srpomeroy](https://github.com/srpomeroy))
- Fastly Security Group Rules Policy - Initial Release [\#14](https://github.com/rightscale/policies/pull/14) ([bryankaraffa](https://github.com/bryankaraffa))
- AWS Volume Tag Sync Policy - Initial Release [\#13](https://github.com/rightscale/policies/pull/13) ([rgeyer](https://github.com/rgeyer))
- Quench Alerts Policy - Initial Release [\#12](https://github.com/rightscale/policies/pull/12) ([bryankaraffa](https://github.com/bryankaraffa))
- Pingdom Security Group Policy - Initial Release [\#10](https://github.com/rightscale/policies/pull/10) ([bryankaraffa](https://github.com/bryankaraffa))
- Shutdown Scheduler - Initial Release [\#8](https://github.com/rightscale/policies/pull/8) ([flaccid](https://github.com/flaccid))
- Instance Runtime - Add Terminate Option [\#3](https://github.com/rightscale/policies/pull/3) ([gonzalez](https://github.com/gonzalez))
- Instance Runtime - Update Email Fields [\#2](https://github.com/rightscale/policies/pull/2) ([rshade](https://github.com/rshade))
- Tag Checker, Instance Runtime, Unattached Volume Finder - Initial Release [\#1](https://github.com/rightscale/policies/pull/1) ([gonzalez](https://github.com/gonzalez))



\* *This Change Log was automatically generated by [github_changelog_generator](https://github.com/skywinder/Github-Changelog-Generator)*