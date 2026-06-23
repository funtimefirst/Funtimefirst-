# Z-Tracker

Z-Tracker is a mobile-friendly zombie survival dashboard built with vanilla HTML/CSS/JS.

## Features

- Zombie sightings tracker (location, threat, count, notes, zombie type, timestamp)
- GPS-assisted location capture for sightings (when browser geolocation is allowed)
- Tactical sightings list with filtering by threat/date/location
- Safe zone management (name, supplies, capacity, notes)
- Supply tracker with low-supply warnings
- Survival stats dashboard (total sightings, highest threat, days survived, supply health)
- High/Critical threat alert banner
- Offline/local persistence using `localStorage`
- Data export/import in JSON

## Project Structure

- `index.html` - app structure and forms
- `styles.css` - dark tactical black/red mobile-responsive UI
- `script.js` - app logic, storage, rendering, alerts, filters, import/export

## Run Locally

### Option 1: Open directly
1. Download/clone the project.
2. Open `index.html` in your browser.

### Option 2: Local HTTP server (recommended)
From project root:

```bash
python3 -m http.server 8080
```

Then visit: `http://localhost:8080`

## Deploy

You can deploy this as a static site on:

- GitHub Pages
- Netlify
- Vercel (static project)
- Cloudflare Pages

Deployment steps are straightforward:
1. Upload all files in this repository.
2. Set publish/root directory to the project root.
3. No build command is required.

## Notes

- Browser geolocation requires user permission and may require HTTPS on some devices.
- Map API integration is intentionally optional; a coordinate-based tactical map placeholder is included by default.
