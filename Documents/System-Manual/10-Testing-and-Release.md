# Testing and Release

- Title: Testing and Release
- Audience: Developers and installers (internal)
- Shipped: No
- Applies to: user-ud1a
- Last updated by: WF2b1, based on 3dd0eec
- Status: Draft
- Verified against: none yet (leads from the old Architecture notes added in WF2b1)
- To confirm: chapter not written yet (WF2b2); leads from the old Architecture notes to verify

## Test database

[[CONFIRM: not written yet (WF2b2)]]
[[CONFIRM: lead from old Architecture notes: database tests run on a test copy (BMMS_Test or BMMS_bak1), never first on BMMS]]

## Test scripts and how to run them

[[CONFIRM: not written yet (WF2b2)]]
[[CONFIRM: lead from old Architecture notes: every step has a test script that runs inside a transaction and rolls back]]

## Reviewer stage

[[CONFIRM: not written yet (WF2b2)]]

## Documentation stage

[[CONFIRM: not written yet (WF2b2)]]

## Release tags and versions

[[CONFIRM: not written yet (WF2b2)]]
[[CONFIRM: lead from old Architecture notes: build with Visual Studio, Rebuild Solution (BMMS.sln), 0 errors]]
[[CONFIRM: lead from old Architecture notes: release order is back up BMMS, run the step's script, then deploy the matching build straight away (the scripts say when the order matters)]]
[[CONFIRM: lead from old Architecture notes: branch modernization; one tag per release; files staged by explicit path; rebuilt binaries stay out of commits]]

## Exporting the documents

[[CONFIRM: not written yet (WF2b2)]]
