# G Editor — PHASE 7

`com.mindhunter.g_editor` — photo editing, also largely absorbed by the OS.

**Do not start building this until it has been repositioned.** Run the same
exercise we ran for the other two: what did Android absorb, what does it still
do badly, what's the durable niche? Build after that answer exists — not before.

It will reuse `g_media` (MediaStore scanning, hashing, thumbnails) from
G Recovery. That reuse is the reason `g_media` is designed as a shared package
rather than living inside G Recovery.
