/// Hosting recipe strings (P4-10/W-17).
library;

const hostingFirebase = r'''
# Firebase Hosting — hydraline SSG deploy

## 1. Build
flutter pub run hydraline_flutter:build

## 2. firebase.json
{
  "hosting": {
    "public": "dist",
    "cleanUrls": true,
    "trailingSlash": false,
    "rewrites": [
      {"source": "**", "destination": "/index.html"}
    ]
  }
}

## 3. Deploy
firebase deploy --only hosting
''';

const hostingNetlify = r'''
# Netlify — hydraline SSG deploy

## 1. Build
flutter pub run hydraline_flutter:build

## 2. netlify.toml
[build]
  publish = "dist/"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
''';

const hostingCloudflare = r'''
# Cloudflare Pages — hydraline SSG deploy

## 1. Build command
flutter pub run hydraline_flutter:build

## 2. Output directory: dist

## 3. _redirects (in dist/)
/*  /index.html  200
''';

const hostingGitHubPages = r'''
# GitHub Pages — hydraline SSG deploy

## 1. Build
flutter pub run hydraline_flutter:build

## 2. Deploy dist/ to gh-pages branch
git subtree push --prefix dist origin gh-pages

## 3. 404.html (SPA fallback)
cp dist/index.html dist/404.html
''';
