# raw/ – die maßgeblichen Quellen

Dieser Ordner enthält die **unveränderlichen** Quelldokumente des Wikis. Das LLM
liest hier, **verändert aber nie** etwas in diesem Ordner.

Lege Quellen hier ab und bitte das LLM dann, sie einzuarbeiten (Skill
`/wiki-ingest`).

## Was hierher gehört

- Konzepte, Spezifikationen, Berichte, Fachartikel, Paper
- Besprechungsnotizen, Protokolle, Transkripte, Entscheidungsvorlagen
- Webartikel (z. B. mit dem Obsidian Web Clipper als Markdown gespeichert)
- E-Mail- oder Chat-Verläufe, als Markdown oder Text exportiert
- Tabellen und Exporte (als CSV oder Text)
- Screenshots, Diagramme, Fotos → Bilder nach `raw/assets/`

## Unterstützte Formate

Direkt lesbar:

- **Markdown / Text** (`.md`, `.txt`, `.csv`) – ideal.
- **PDF** (`.pdf`) – Text *und* Grafiken (Diagramme, Folien, Screenshots).
  **Bevorzugt für Foliensätze.** Falls das direkte Lesen scheitert, nutzt das LLM
  `pdftotext`/`pdftoppm` aus dem Paket `poppler` (siehe README im Hauptordner).
- **Bilder** (`.png`, `.jpg`, …) – werden direkt angesehen. Ablage in `raw/assets/`.

Nicht direkt lesbar (vorher konvertieren):

- **PowerPoint** (`.pptx`) – vor dem Ablegen als **PDF** exportieren
  (PowerPoint/Keynote: *Datei → Exportieren → PDF*). So bleiben Diagramme und
  Layout erhalten. Alternativ einen Konverter installieren; dann konvertiert das
  LLM beim Einarbeiten: `brew install --cask libreoffice` (volle Treue über
  `soffice --headless --convert-to pdf`) oder `pip install python-pptx` (nur Text
  und Sprechernotizen, ohne Grafiken).
- **Word / Excel / andere Office-Formate** – ebenso: als PDF bzw. Text/CSV
  exportieren.

Tipp: Die Original-`.pptx` kann als Archivquelle in `raw/` bleiben; daneben
liegt ein PDF-Export, den das LLM liest.

## Regeln

- Eine Quelle = eine Datei, wo es sich anbietet. Aussagekräftige Dateinamen.
- Markdown oder Text bevorzugen; PDFs und Bilder sind ebenfalls gut.
- Bilder, auf die eine Quelle verweist, gehören nach `raw/assets/`.
- Eine Quelle nach dem Einarbeiten nie mehr bearbeiten. Gibt es eine neue
  Fassung, als neue, datierte Datei ablegen statt zu überschreiben – das Wiki
  zeichnet nach, wie sich das Wissen verändert hat.

> Noch nichts eingearbeitet. Der Ordner ist leer und bereit für Quellen.
