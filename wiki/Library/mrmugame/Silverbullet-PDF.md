---
name: Library/mrmugame/Silverbullet-PDF
tags: meta/library
files:
- silverbullet-pdf.plug.js
share.uri: "ghr:MrMugame/silverbullet-pdf/PLUG.md"
share.hash: 3498d9f9
share.mode: pull
---
# Silverbullet PDF
This plug adds the ability to [Silverbullet](https://github.com/silverbulletmd/silverbullet) to view and annotate pdfs using a slightly modified version of the [pdfjs](https://github.com/mozilla/pdf.js) viewer. If used with [Silversearch](https://github.com/MrMugame/silversearch), Silverbullet PDF can extract text content from PDFs to help you search through them.

![screenshot](https://raw.githubusercontent.com/mrmugame/silverbullet-pdf/main/docs/preview.png)

## Installation
Silverbullet PDF is part of the [`Std`](https://silverbullet.md/Repositories/Std) repostitory and can by installed using the [Library Manager](https://silverbullet.md/Library%20Manager). You will have to navigate to `Library/Std/Pages/Library Manager` in *your* space and look for Silverbullet PDF under the available libraries and press `Install`.

## Internals
The build process of this plug is rather weird. The steps are as follows

1. Uing `deno task download` the pdfjs repo will be cloned and the `pdfjs.patch` patch will be applied. I opted for this approach, because I wanted to avoid an extra repo for the few changes
2. Using `deno task install` all npm install commands are run
3. Using `deno task build` the build process will be run. This will firstly build pdfjs, copy all the important files over and then do the ~~typical~~ vite (ui) + deno (worker) build.
