# SIDEDOCK marketing site

Private static site for [SIDEDOCK](https://github.com/MrEGAMERZ/MacSideDock). This repo is **private**; the product source is a separate public repo.

`index.html` is at the repo root so Vercel can serve `/` as the landing page.

## Local

Open `index.html` in a browser, or from this directory:

```bash
python3 -m http.server 8000
```

Then visit `http://localhost:8000`. Asset paths are relative. The page is a zero-build static site: HTML, CSS, and JS only.

## Deploy on Vercel

1. In [Vercel](https://vercel.com), **Add New… → Project → Import Git Repository**.
2. Import this private GitHub repo (`MrEGAMERZ/sidedock-site`). Grant Vercel access if GitHub asks.
3. **Framework Preset:** Other. Leave **Build Command** empty. Leave **Output Directory** empty (root).
4. Deploy. After you have a production URL, replace the canonical / OG placeholders in `index.html`.
