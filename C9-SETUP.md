# C9 setup — turning on the analytics export

The analytics page renders "Not connected" until three things are done. None are
code changes; the panel already handles both states.

## 1. Enable the BigQuery export in Firebase

Firebase console → Project settings → Integrations → BigQuery → Link, and pick
**daily** export for each app's Analytics property. Free at this volume. The
first `events_YYYYMMDD` table lands within 24 hours, and until it does the panel
shows "enabled but no data yet" rather than an error.

## 2. Add the dependency

```
cd admin && npm i @google-cloud/bigquery
```

The panel imports it dynamically, so a deploy without it still builds — the page
just reports the client is missing. Installing it is what flips that.

## 3. Set the env, in apphosting.yaml

```yaml
env:
  - variable: GCP_PROJECT
    value: mindberzerk           # the Firebase project id
  - variable: BQ_DATASET_G_LAUNCHER
    value: analytics_XXXXXXXXX   # the property's dataset, from the BigQuery link
  - variable: BQ_DATASET_G_RECOVERY
    value: analytics_YYYYYYYYY
```

The dataset name is `analytics_<propertyId>`, shown on the BigQuery link screen.
One per app, because each app is its own Analytics property. The App Hosting
service account needs **BigQuery Data Viewer** and **Job User** on the project;
credentials are picked up automatically, there is no key file.

## Two launcher changes that unlock the segments

The panel queries three things. One works with what the launcher already logs;
two need a small change, and until then those panels stay "Not connected"
honestly rather than wrong.

- **Setup funnel** — works now if the launcher logs `first_open`,
  `setup_home_role`, `setup_distro`, `setup_drawer`, `setup_complete`. The names
  in `lib/core/analytics.dart` are the source of truth; if they differ, change
  the `IN (...)` list in `setupFunnel`.

- **Retention by distro** — needs `active_theme` set as a USER PROPERTY, not just
  an event parameter. A property attaches to the user and can be joined against
  their later return days; a parameter cannot. This is the one already noted for
  the launcher.

- **Package frequency (the C10 blocker)** — needs an `app_present` event, one per
  installed package the launcher can see, logged periodically. This is what lets
  the coverage queue rank hero art by what the base actually runs. Without it,
  C10 ranks by the static core set, which is a reasonable but blind fallback.

## Why the panel does not just call the GA4 Data API instead

The Data API returns the same aggregated, sampled data the console shows, with
the same 500-event and no-per-user limits. The whole point of C9 is the two
questions that need row-level joins, and only the raw export has rows. So the
export is not an optimisation here, it is the only source that can answer them.
