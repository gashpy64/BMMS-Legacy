# Page assets pack (step UN6e)

The pack proves on every run that each local stylesheet link of the pages visited carries the version stamp of its
file (`?v=` and the first 8 hex characters, lower case, of the SHA-256 of the file; BMMS\AssetVersion.cs, owner
decision UN6e R30), and that the Dashboard of the Controller keeps its ViewState small (R29: the lists are not kept
in ViewState). Database\README.md, section "Step UN6e", has the rules.

## Files

| File | What | Who changes it |
|---|---|---|
| `expected.json` | `pages`: the role, the address and the local stylesheets of each page, in the order of the page (MainMaster.css is linked twice by both master pages, so it is listed twice). `viewState`: the role, the address and the largest `__VIEWSTATE` allowed, in characters of the field as first loaded. | The owner, or Claude on the owner's instruction (the build report lists it under "expectations changed"). Never the tester. |
| `pack.js` | The checks. | Claude, in a reviewed step. |

## The checks

1. One check per page of `pages` (ten): the page opens, and its local stylesheet links (`<link rel="stylesheet">`
   on this site whose path ends in `.css`) are exactly the files listed, in order, each with `?v=` and the stamp of
   that file in `Tests\_site`. The expected stamps are computed by the pack from the site copy, so a changed
   stylesheet needs no change of `expected.json`; a stylesheet added to or removed from a page does. The AJAX
   toolkit's calendar stylesheet (`WebResource.axd?d=...&t=...`, on pages with a date box) is a handler with its own
   stamp, not a file, and is not counted. A link to another host is not counted (there is none).
2. One check per row of `viewState` (one): the Dashboard of the Controller (qa_ctrl) as first loaded has a
   `__VIEWSTATE` of at most `maxBytes` characters.

## The limit

`maxBytes` is 12,900 (owner decision 2026-11-18): the fixture value the tester saw for qa_ctrl with step UN6e, 10,312
characters (run 2026-11-18_121946, after the other packs), plus about 25 percent. The first limit, 9,800, came from a
copy of BMMS_Test (7,788 plus 25 percent) and was too low for the fixture, whose Dashboard is larger.

The limit catches the stored Action Items table coming back: the code before UN6e (commit dbc48ca), measured on a
scratch build against a copy of the tester's baseline with the fixture dates set, gives 24,288 characters for the same
page and account; this step's build on that copy gives 10,712. (Stage B, the row state of the grids, is not built:
owner decision.) For scale: on a copy of BMMS_Test filled to about one year of use the Controller's Dashboard was
899,196 characters before UN6e and 21,908 after.

## The data

The fixture (Tests\fixture). The pack changes no data: it only opens pages. The first-sign-in password page
(ChangePasswordFirst.aspx) is opened, not submitted; it is the one page of the second master page (MainNoMenu.Master).
