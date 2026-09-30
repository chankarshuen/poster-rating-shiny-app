# Symposium Poster Rating Shiny App

## Overview

This repository contains a mobile-friendly **R/Shiny poster-rating
application** developed for a symposium with **20 posters**.

Each poster is assigned a numbered QR code. Attendees scan the QR code
with a phone, rate that specific poster in two domains, and submit the
rating. Ratings are stored persistently in a Supabase database. A
password-protected administrator page provides live summary results,
raw-data export, database clearing, and generation of the 20 poster QR
codes.

## Live URLs

**Public application**

https://01a0f2a8-a443-e9d9-d3ed-4c4677502232.share.connect.posit.cloud/

The public base URL by itself does not identify a poster. Individual
poster links add a `poster` query parameter:

-   Poster 1:
    `https://01a0f2a8-a443-e9d9-d3ed-4c4677502232.share.connect.posit.cloud/?poster=1`
-   Poster 2:
    `https://01a0f2a8-a443-e9d9-d3ed-4c4677502232.share.connect.posit.cloud/?poster=2`
-   ...
-   Poster 20:
    `https://01a0f2a8-a443-e9d9-d3ed-4c4677502232.share.connect.posit.cloud/?poster=20`

**Administrator login**

https://01a0f2a8-a443-e9d9-d3ed-4c4677502232.share.connect.posit.cloud/?admin=1

The administrator password is stored securely as a Posit Connect Cloud
secret and is intentionally **not included in this repository**.

## Rating System

Each poster is scored in two equally weighted domains:

1.  **Content:** 1--7
2.  **Presentation:** 1--7

A score of 7 is best.

The overall score is:

`Overall = (Content + Presentation) / 2`

Current averages are not shown to attendees while they are rating.

## Attendee Workflow

1.  Scan the QR code displayed with a poster.
2.  The QR code opens the app with the correct poster number.
3.  Select a **Content** score from 1--7.
4.  Select a **Presentation** score from 1--7.
5.  Tap **Submit Rating**.
6.  The rating is written to Supabase.
7.  The app displays a submission confirmation.

## Duplicate-Rating Protection

The app creates a random anonymous browser identifier and stores it in
the browser's local storage. The database permits only one submission
for a given combination of:

`rater_id + poster_number`

This prevents accidental duplicate ratings of the same poster from the
same browser.

This is not identity authentication. Clearing browser storage or using a
different browser/device can generate a new identifier. The app does not
require an attendee name or email address.

## Administrator Dashboard

Open:

https://01a0f2a8-a443-e9d9-d3ed-4c4677502232.share.connect.posit.cloud/?admin=1

Enter the administrator password configured in Posit Connect Cloud.

The administrator dashboard provides:

-   **Refresh results** --- retrieves the latest ratings from Supabase.
-   **Summary table** --- displays the number of ratings and mean
    Content, Presentation, and Overall scores for each poster.
-   **Download raw ratings (.csv)** --- exports all individual rating
    records and calculated overall scores.
-   **Clear database** --- permanently deletes all submitted ratings
    after a confirmation dialog. This is useful for removing test
    ratings immediately before the symposium.
-   **Download 20 QR codes (.pdf)** --- generates a printable PDF
    containing numbered QR codes for Posters 1--20.

### Clearing the database

Use **Clear database** only when all existing ratings should be deleted.
The app requires a second confirmation before deletion.

For the symposium, a sensible workflow is:

1.  Test several poster QR codes.
2.  Verify the ratings appear correctly in the administrator dashboard.
3.  Download a test CSV if desired.
4.  Immediately before live rating begins, click **Clear database** and
    confirm.
5.  Verify that all 20 posters show `n_ratings = 0`.

## QR-Code Generation

On the administrator page, enter the public base URL:

`https://01a0f2a8-a443-e9d9-d3ed-4c4677502232.share.connect.posit.cloud/`

Do **not** add `?admin=1` or a poster number.

Click **Download 20 QR codes (.pdf)**. The app generates QR codes
pointing to:

`?poster=1` through `?poster=20`

The PDF is formatted with four numbered QR codes per US-letter page.

Before printing or distributing the QR codes, scan several codes with a
phone and verify that each opens the expected poster number.

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

## Application Architecture

The application consists of three main components:

**R/Shiny** - Provides the mobile rating interface and administrator
dashboard. - Uses the `shiny`, `httr2`, and `qrcode` R packages.

**Posit Connect Cloud** - Hosts the Shiny application. - Deploys the
application from this GitHub repository. - Stores database credentials
and the administrator password as secret environment variables.

**Supabase** - Provides the persistent PostgreSQL database. - Stores
individual ratings. - Enforces the one-browser-per-poster uniqueness
rule.

## Required Posit Connect Cloud Variables

The deployment requires these environment variables:

-   `SUPABASE_URL`
-   `SUPABASE_SERVICE_KEY`
-   `ADMIN_PASSWORD`

An optional variable is:

-   `APP_BASE_URL`

`APP_BASE_URL` can be set to the public application URL so that the
QR-code generator is pre-populated automatically.

**Never commit the Supabase secret key or administrator password to
GitHub.**

## Supabase Setup

The database setup is contained in:

`setup_supabase.sql`

The table includes validation requiring:

-   poster numbers between 1 and 20
-   Content scores between 1 and 7
-   Presentation scores between 1 and 7

A unique database index prevents duplicate combinations of `rater_id`
and `poster_number`.

Row Level Security is enabled. Database access by the Shiny application
uses the server-side Supabase secret key stored in Posit Connect Cloud.

## Repository Files

-   `app.R` --- complete Shiny application
-   `manifest.json` --- R dependency manifest used for deployment
-   `setup_supabase.sql` --- SQL used to create/configure the Supabase
    ratings table
-   `README.md` --- this documentation

## Deployment and Updating

The application is deployed from the GitHub repository to Posit Connect
Cloud.

To update the application:

1.  Modify and save `app.R` locally.
2.  Upload the updated `app.R` to the GitHub repository, replacing the
    existing file.
3.  Commit the change to the `main` branch.
4.  Posit Connect Cloud is configured to automatically republish after a
    GitHub push.
5.  Wait for deployment to complete.
6.  Reload the public application and test it.

If R package dependencies change, regenerate `manifest.json` in R with:

``` r
rsconnect::writeManifest()
```

Then commit the updated `manifest.json` as well.

## Development History

The application was developed in September 2026 with the following
sequence:

1.  Created the R/Shiny mobile rating interface for 20 posters.
2.  Implemented separate 1--7 Content and Presentation scores with equal
    weighting.
3.  Added anonymous browser identifiers and duplicate-submission
    prevention.
4.  Created the Supabase `ratings` database and uniqueness constraint.
5.  Added a password-protected administrator dashboard with summary
    statistics and raw CSV download.
6.  Added automatic generation of a printable 20-poster QR-code PDF.
7.  Created a public GitHub repository and generated an R dependency
    `manifest.json`.
8.  Deployed the GitHub repository to Posit Connect Cloud.
9.  Configured Supabase credentials and the administrator password as
    Connect Cloud secrets.
10. Corrected the initial Shiny URL-query handling so that `?poster=N`
    and `?admin=1` are processed reactively.
11. Verified an end-to-end test submission from the public app into
    Supabase and confirmed the correct summary calculation in the
    administrator dashboard.
12. Added a password-protected **Clear database** workflow with a
    confirmation dialog and automatic summary refresh.

## Troubleshooting

### App says "Disconnected from the server"

Open the application's **Logs** in Posit Connect Cloud and inspect the
most recent R/Shiny error. Do not assume this is a database problem;
startup errors in `app.R` can also cause immediate disconnection.

### App says the link does not specify a valid poster

The public URL needs a valid poster parameter, for example:

`https://01a0f2a8-a443-e9d9-d3ed-4c4677502232.share.connect.posit.cloud/?poster=1`

Valid poster numbers are 1 through 20.

### Rating will not save

Check that `SUPABASE_URL` and `SUPABASE_SERVICE_KEY` are configured in
Posit Connect Cloud and that the Supabase project is available.

### Administrator login does not work

Check that `ADMIN_PASSWORD` is configured in Posit Connect Cloud. Do not
add the password directly to `app.R`.

### Results appear stale

Click **Refresh results** on the administrator dashboard.

## Important Operational Notes

-   Keep the Supabase secret key and administrator password private.
-   Do not place secrets in GitHub, `app.R`, or this README.
-   Download a copy of the raw CSV before clearing the database if the
    existing ratings need to be preserved.
-   Test the QR codes on a phone before the symposium.
-   Clear all test ratings immediately before live scoring begins.
-   Keep the public Connect Cloud URL stable after generating/printing
    the QR codes. Changing the public URL would invalidate previously
    generated QR codes.

------------------------------------------------------------------------

**Current public application:**
https://01a0f2a8-a443-e9d9-d3ed-4c4677502232.share.connect.posit.cloud/

**Current administrator page:**
https://01a0f2a8-a443-e9d9-d3ed-4c4677502232.share.connect.posit.cloud/?admin=1
