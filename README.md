# Symposium Poster Rating --- Shiny App

## Overview

This repository contains a mobile-friendly **R/Shiny poster-rating
application** for a symposium with **20 posters**.

Each poster has a numbered QR code. Attendees scan the code, rate that
poster in two domains, and submit the rating from a phone. Ratings are
stored persistently in **Supabase**. The app is hosted on **Posit
Connect Cloud** and deployed from GitHub.

A password-protected administrator page provides summary results,
raw-data export, database clearing, QR-code generation, and
administrator password management.

## Live URLs

**Public application**

https://01a0f2a8-a443-e9d9-d3ed-4c4677502232.share.connect.posit.cloud/

Individual poster links use the poster number as a query parameter:

-   Poster 1:
    `https://01a0f2a8-a443-e9d9-d3ed-4c4677502232.share.connect.posit.cloud/?poster=1`
-   Poster 2:
    `https://01a0f2a8-a443-e9d9-d3ed-4c4677502232.share.connect.posit.cloud/?poster=2`
-   ...
-   Poster 20:
    `https://01a0f2a8-a443-e9d9-d3ed-4c4677502232.share.connect.posit.cloud/?poster=20`

**Administrator page**

https://01a0f2a8-a443-e9d9-d3ed-4c4677502232.share.connect.posit.cloud/?admin=1

The administrator password is not stored in this README or in the GitHub
repository.

## Rating System

Each poster is rated in two domains:

1.  **Content:** 1--7
2.  **Presentation:** 1--7

A score of 7 is best. The domains are weighted equally:

`Overall score = (Content + Presentation) / 2`

Current averages are not shown to attendees while they are rating.

## Attendee Workflow

1.  Scan the QR code displayed with a poster.
2.  The QR code opens the app with the correct `?poster=N` parameter.
3.  Select a **Content** score from 1--7.
4.  Select a **Presentation** score from 1--7.
5.  Tap **Submit Rating**.
6.  The rating is written to Supabase.
7.  The app displays a confirmation.

## Repeat Ratings and Rating Replacement

The app assigns each browser a random anonymous identifier stored in
local storage.

The database permits only one record for a given:

`rater_id + poster_number`

If the same browser attempts to rate the same poster again, the app now
displays a confirmation dialog explaining that a prior rating exists.
The attendee can:

-   **Keep previous rating** --- the existing rating remains unchanged.
-   **Replace previous rating** --- the existing Content and
    Presentation scores are updated with the newly selected scores.

Replacing a rating does **not** create a second vote.

This mechanism prevents accidental duplicate ratings but is not identity
authentication. Clearing browser storage or using a different
browser/device can generate a new identifier. The app does not require
attendee names or email addresses.

## Administrator Dashboard

Open:

https://01a0f2a8-a443-e9d9-d3ed-4c4677502232.share.connect.posit.cloud/?admin=1

Log in with the current administrator password.

The dashboard provides:

-   **Refresh results** --- retrieves the latest ratings from Supabase.
-   **Summary table** --- shows the number of ratings and mean Content,
    Presentation, and Overall scores for each poster.
-   **Download raw ratings (.csv)** --- exports individual rating
    records and calculated overall scores.
-   **Clear database** --- permanently deletes all submitted ratings
    after a confirmation dialog.
-   **Change administrator password** --- changes the password used to
    enter the administrator dashboard.
-   **Download 20 QR codes (.pdf)** --- generates a printable PDF of
    numbered QR codes for Posters 1--20.

## Changing the Administrator Password

On the administrator dashboard, click **Change administrator password**.

The dialog requests:

1.  Current password
2.  New password
3.  Confirmation of the new password

The new password must be at least 8 characters.

After a successful change, the new password is stored persistently in
the Supabase `app_settings` table and becomes the password for
subsequent administrator logins.

The original `ADMIN_PASSWORD` environment variable in Posit Connect
Cloud remains the initial/fallback password when no persistent password
has yet been stored.

Do not put the administrator password in GitHub, `app.R`, or this
README.

## Clearing the Database

Use **Clear database** only when all existing ratings should be removed.

The app presents a second confirmation before deletion and refreshes the
summary afterward.

Recommended pre-event workflow:

1.  Test several poster QR codes.
2.  Confirm the test ratings appear correctly.
3.  Test rating replacement from the same browser.
4.  Download a test CSV if desired.
5.  Immediately before live scoring begins, click **Clear database** and
    confirm.
6.  Verify that all 20 posters show zero ratings.

If existing ratings need to be preserved, download the raw CSV before
clearing the database.

## QR-Code Generation

The administrator page automatically fills the **Public app URL** with:

`https://01a0f2a8-a443-e9d9-d3ed-4c4677502232.share.connect.posit.cloud/`

The administrator therefore normally only needs to click **Download 20
QR codes (.pdf)**.

The generator adds `?poster=1` through `?poster=20` automatically.

The QR PDF is formatted with four numbered QR codes per US-letter page.

QR matrices are drawn directly with base R graphics rather than relying
on a package-specific plotting method, improving reliability on Posit
Connect Cloud.

Before printing or distributing the QR codes, scan several codes with a
phone and verify that each opens the correct poster number.

## Raw Data Structure

The Supabase `ratings` table stores:

-   `id` --- database record ID
-   `created_at` --- submission timestamp
-   `poster_number` --- poster number, 1--20
-   `content_score` --- Content score, 1--7
-   `presentation_score` --- Presentation score, 1--7
-   `rater_id` --- anonymous browser identifier

The downloaded CSV additionally calculates:

`overall_score = (content_score + presentation_score) / 2`

## Supabase Database

### ratings table

The original `ratings` table enforces:

-   poster numbers from 1--20
-   Content scores from 1--7
-   Presentation scores from 1--7
-   one record per `rater_id + poster_number`

Row Level Security is enabled.

### app_settings table

Password-changing functionality requires a second small table:

``` sql
create table if not exists public.app_settings (
  key text primary key,
  value text not null
);

alter table public.app_settings enable row level security;
```

This SQL only needs to be run once in the Supabase SQL Editor.

The table stores the administrator-selected password under the
`admin_password` setting. The Shiny server accesses it using the
server-side Supabase secret/service key.

## Application Architecture

The application has four main pieces:

**R/Shiny** - Mobile attendee rating interface - Administrator
dashboard - Rating replacement workflow - QR-code PDF generation - CSV
export and database management

**Supabase** - Persistent PostgreSQL storage - `ratings` table -
`app_settings` table - Duplicate-rating uniqueness constraint

**GitHub** - Source-code repository - Stores `app.R`, deployment
manifest, SQL setup files, and documentation - Must never contain
passwords or Supabase secret keys

**Posit Connect Cloud** - Hosts the live Shiny application - Deploys
from the GitHub repository - Stores server-side secret environment
variables

## Required Posit Connect Cloud Variables

The deployment uses:

-   `SUPABASE_URL`
-   `SUPABASE_SERVICE_KEY`
-   `ADMIN_PASSWORD`

The application also supports:

-   `APP_BASE_URL`

The current `app.R` contains the live public URL as the fallback/default
QR-generator URL, so the Public app URL field is automatically populated
even if `APP_BASE_URL` is not configured.

**Never commit `SUPABASE_SERVICE_KEY` or an administrator password to
GitHub.**

## Repository Files

Core files include:

-   `app.R` --- complete Shiny application
-   `manifest.json` --- R dependency manifest for deployment
-   `setup_supabase.sql` --- original ratings-table setup
-   `add_admin_password_setting.sql` --- creates the `app_settings`
    table
-   `README.md` --- repository documentation

## Updating and Deploying the App

The live app is deployed from GitHub to Posit Connect Cloud.

To update it:

1.  Download or save the revised file as `app.R`.
2.  Open the GitHub repository.
3.  Upload the revised `app.R`, replacing the existing file.
4.  Commit the change to the `main` branch.
5.  Posit Connect Cloud should automatically republish.
6.  Wait for deployment to finish.
7.  Reload and test both a poster page and the administrator page.

If R package dependencies change, regenerate the deployment manifest in
R:

``` r
rsconnect::writeManifest()
```

Then commit the updated `manifest.json`.

## Development History

The application was developed and refined in September 2026:

1.  Built a mobile R/Shiny rating interface for 20 posters.
2.  Added 1--7 Content and Presentation ratings with equal weighting.
3.  Added anonymous browser identifiers.
4.  Created the Supabase ratings database and uniqueness constraint.
5.  Added a password-protected administrator dashboard.
6.  Added summary statistics and raw CSV export.
7.  Added generation of a printable 20-poster QR-code PDF.
8.  Created the GitHub repository and R deployment manifest.
9.  Deployed the application to Posit Connect Cloud.
10. Configured Supabase credentials and the administrator password as
    Connect Cloud secrets.
11. Corrected reactive URL handling for `?poster=N` and `?admin=1`.
12. Verified end-to-end rating submission and summary calculations.
13. Added a **Clear database** button with confirmation and automatic
    summary refresh.
14. Improved QR rendering by drawing QR matrices directly with base R
    graphics.
15. Set the live Public app URL as the automatic default in the QR
    generator.
16. Changed duplicate-rating behavior so attendees can choose whether to
    replace a previous rating from the same browser.
17. Added persistent administrator password changing through the
    Supabase `app_settings` table.

## Troubleshooting

### QR PDF does not download

Confirm that the **Public app URL** field is populated. In the current
version it should fill automatically.

If a download still fails, inspect the Posit Connect Cloud application
logs immediately after reproducing the error.

### App says "Disconnected from the server"

Open the application's logs in Posit Connect Cloud and inspect the most
recent R/Shiny error.

### App says the link does not specify a valid poster

The URL must include a valid poster parameter, for example:

`https://01a0f2a8-a443-e9d9-d3ed-4c4677502232.share.connect.posit.cloud/?poster=1`

Valid poster numbers are 1 through 20.

### Rating will not save

Check that `SUPABASE_URL` and `SUPABASE_SERVICE_KEY` are configured in
Posit Connect Cloud and that the Supabase project is available.

### Administrator password change does not work

Confirm that the `public.app_settings` table has been created in
Supabase using the SQL shown above.

### Administrator login does not work

Confirm that `ADMIN_PASSWORD` is configured in Posit Connect Cloud if no
password has yet been stored in `app_settings`. If a password has
already been changed through the app, use that newer password.

### Results appear stale

Click **Refresh results** on the administrator dashboard.

## Important Operational Notes

-   Keep the Supabase secret key and administrator password private.
-   Never place secrets in GitHub or documentation.
-   Test poster submission, repeat-rating replacement, QR generation,
    CSV download, database clearing, and admin login before the event.
-   Download the raw CSV before clearing ratings that need to be
    retained.
-   Clear test ratings immediately before live scoring.
-   Keep the public Connect Cloud URL stable after generating and
    printing QR codes; changing it would invalidate previously generated
    QR codes.

------------------------------------------------------------------------

**Public application:**
https://01a0f2a8-a443-e9d9-d3ed-4c4677502232.share.connect.posit.cloud/

**Administrator page:**
https://01a0f2a8-a443-e9d9-d3ed-4c4677502232.share.connect.posit.cloud/?admin=1
