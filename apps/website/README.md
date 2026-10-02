# GozVision website

The public landing page — clinic-first positioning (the practice platform),
with the Goz copilot as the flagship differentiator module.

- `index.html` — single self-contained page, no build step, no framework.
  Accessibility is the brand: semantic landmarks, skip link, focus styles,
  AA contrast, and `prefers-reduced-motion` support.

## Local preview

Open `index.html` directly in a browser, or serve it:

```bash
python -m http.server 8080   # from this directory
```

## Deploy (Firebase Hosting)

```bash
firebase init hosting   # public directory: apps/website, single-page app: no
firebase deploy --only hosting
```

The contact address (`hello@gozvision.app`) is a placeholder until the
production domain is registered — swap it in `index.html` (2 occurrences).
