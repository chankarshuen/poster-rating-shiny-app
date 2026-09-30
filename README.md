# Symposium Poster Rating — Shiny App

A phone-friendly Shiny app for rating 20 symposium posters.

## What it does

Each poster has its own QR-code URL:

- `https://YOUR-APP-URL?poster=1`
- ...
- `https://YOUR-APP-URL?poster=20`

A viewer scans a QR code and rates that poster on:

- **Content:** 1–7
- **Presentation:** 1–7

Both domains are weighted equally:

`Overall score = (Content + Presentation) / 2`

The app does **not** show current scores to raters. A browser can submit only one
rating per poster (implemented with an anonymous browser identifier plus a
database uniqueness constraint).

The administrator page is:

`https://YOUR-APP-URL?admin=1`

It shows summary results, downloads raw ratings as CSV, and generates a printable
PDF containing all 20 numbered QR codes.

## 1. Install the R packages locally

In RStudio:

```r
install.packages(c("shiny", "httr2", "qrcode", "rsconnect"))
```

## 2. Create the database

This app uses **Supabase** for persistent storage. Connect Cloud runtime files are
not durable, so ratings should not be stored in a local CSV.

1. Create a Supabase project.
2. Open the SQL Editor.
3. Run the contents of `setup_supabase.sql`.
4. In Supabase project settings, copy:
   - Project URL
   - service-role key

**Never put the service-role key in GitHub.**

## 3. Configure secrets in Posit Connect Cloud

Add these environment/secret variables to the content:

- `SUPABASE_URL` = your Supabase project URL
- `SUPABASE_SERVICE_KEY` = your Supabase service-role key
- `ADMIN_PASSWORD` = a password you choose for the admin page
- `APP_BASE_URL` = the public URL of the deployed Shiny app

Connect Cloud supports encrypted secret variables in Content Settings.

## 4. Test locally

For local testing only, set environment variables in the R session:

```r
Sys.setenv(
  SUPABASE_URL = "https://YOURPROJECT.supabase.co",
  SUPABASE_SERVICE_KEY = "YOUR-SERVICE-ROLE-KEY",
  ADMIN_PASSWORD = "choose-a-password",
  APP_BASE_URL = "http://127.0.0.1:PORT"
)
```

Then run `app.R`.

Do not save real secrets in `app.R`, `.Rhistory`, or any file committed to GitHub.

## 5. Create the deployment manifest

From the app directory in RStudio:

```r
rsconnect::writeManifest()
```

Commit `manifest.json` to GitHub along with `app.R`.

## 6. Publish

Publish the GitHub repository as a **Shiny** app on Posit Connect Cloud.
Set `app.R` as the primary file and keep automatic republishing on push enabled.

After deployment, set `APP_BASE_URL` to the final public share URL and restart/
republish if needed.

## 7. Generate the QR codes

Open:

`https://YOUR-APP-URL?admin=1`

Sign in with `ADMIN_PASSWORD`, verify the public app URL, and click:

**Download 20 QR codes (.pdf)**

The PDF contains Posters 1–20, four QR codes per letter-size page.

## Privacy / duplicate-vote behavior

No name, email, or account is requested from raters. The app creates a random
identifier in the phone browser's local storage. The database stores that random
identifier solely to prevent that browser from rating the same poster twice.

This prevents accidental duplicates but is not intended as high-security voter
authentication. Clearing browser storage or using another browser/device can
create another identifier.
