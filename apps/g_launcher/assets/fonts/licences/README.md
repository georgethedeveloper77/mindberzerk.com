# Licence texts for fetched font families

`main.dart` registers these with `LicenseRegistry`, keyed by the `licence` field
on each entry in `../catalogue.json`.

Two files are needed and are NOT in this repo yet, because both are long
verbatim legal texts and neither should be typed from memory:

| file         | what to put in it                                              |
|--------------|----------------------------------------------------------------|
| `ofl.txt`    | SIL Open Font Licence 1.1, full text (scripts.sil.org/OFL)      |
| `apache.txt` | Apache Licence 2.0, full text (apache.org/licenses/LICENSE-2.0) |

The Ubuntu Font Licence is already at `../UBUNTU-FONT-LICENCE-1.0.txt` and is
registered separately.

A missing file here is caught and logged rather than thrown: the licence page
still opens, with that group absent. That is a shipping blocker, not a runtime
one, and `flutter analyze` will not catch it. Check `showLicensePage` before a
release.
