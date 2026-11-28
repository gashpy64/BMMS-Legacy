# Document Exports

- Title: Document Exports
- Audience: Gashpy Software (internal)
- Shipped: No
- Applies to: user-ud1a
- Last updated by: WF2a, based on 021e946
- Status: Draft
- Verified against: none yet
- To confirm:

Exports are made per release with `pwsh -File Documents/_build/Export-Documents.ps1` and land in
`Documents/Export/<label>/`. Everything in this folder except this file is ignored by git.
