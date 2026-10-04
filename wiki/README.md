# Panorama & Oracle Performance – LLM Wiki

Eine sofort nutzbare Vorlage für ein **LLM-gepflegtes Wiki** nach der Idee von
Andrej Karpathy – auf Englisch, für Claude Code, mit Obsidian bzw. Silverbullet
als Oberfläche.

## Worum geht es?

Die meisten Menschen nutzen LLMs mit Dokumenten wie eine Suchmaschine (RAG): Das
Modell sucht bei jeder Frage neu passende Textstellen zusammen. Nichts sammelt
sich an.

Ein **LLM-Wiki** funktioniert anders: Das LLM **baut schrittweise ein
dauerhaftes, verlinktes Wiki aus Markdown-Dateien auf und pflegt es**. Jede neue
Quelle wird einmal gelesen, zusammengefasst und in die bestehenden Seiten
eingearbeitet – mit Querverweisen, markierten Widersprüchen und einer
Übersicht, die immer auf dem aktuellen Stand ist. Das Wissen wird einmal
aufbereitet und dann aktuell gehalten.

- **Du** wählst Quellen aus, stellst Fragen und steuerst die Analyse.
- **Das LLM** übernimmt Zusammenfassen, Verlinken, Ablegen und Buchführung.
- **Obsidian** (oder Silverbullet) ist die IDE, das LLM der Programmierer, das
  Wiki die Codebasis.

Das vollständige Konzept steht in [LLM-Wiki-Idee.md](LLM-Wiki-Idee.md).

---

## Installation

### 1. Claude Code (Pflicht)

Claude Code ist der LLM-Agent, der das Wiki pflegt. Benötigt wird ein
kostenpflichtiges Claude-Konto (Pro, Max, Team oder Enterprise) oder ein
Anthropic-Console-Konto mit API-Guthaben. Der kostenlose Tarif enthält Claude
Code nicht.

| System | Befehl |
|---|---|
| macOS, Linux, WSL | `curl -fsSL https://claude.ai/install.sh \| bash` |
| Windows PowerShell | `irm https://claude.ai/install.ps1 \| iex` |
| macOS mit Homebrew | `brew install --cask claude-code` |
| Windows mit WinGet | `winget install Anthropic.ClaudeCode` |

Danach ein **neues** Terminal öffnen und prüfen:

```bash
claude --version
```

Beim ersten Start von `claude` öffnet sich der Browser für die Anmeldung.
Wer lieber ohne Terminal arbeitet: Es gibt auch eine Desktop-App
(<https://claude.com/download>). Details und Fehlerbehebung:
<https://code.claude.com/docs/en/setup>.

### 2. Obsidian (empfohlen)

Obsidian ist ein kostenloser Markdown-Editor, mit dem du das Wiki liest: Links
folgen, Graphansicht, Suche. Download: <https://obsidian.md>.

Empfohlene Community-Plugins (optional, in Obsidian unter *Einstellungen →
Community-Plugins*):

- **Dataview** – Tabellen und Listen aus dem Frontmatter der Seiten
- **Marp Slides** – Präsentationen direkt aus Markdown

### 3. Silverbullet (Alternative zu Obsidian)

[Silverbullet](https://silverbullet.md) ist ein Markdown-Wiki, das im Browser
läuft – praktisch, wenn das Wiki auf einem Server liegt oder mehrere Leute
darauf zugreifen. Die Vorlage bringt eine Konfiguration (`CONFIG.md`) und
Plugins in `Library/` mit (Mermaid-Diagramme, Excalidraw, PDF-Anzeige,
Volltextsuche).

Start mit Docker, im Wiki-Ordner ausgeführt:

```bash
docker run -d --restart unless-stopped --name silverbullet \
  -p 3000:3000 -v "$PWD":/data \
  ghcr.io/silverbulletmd/silverbullet:latest
```

Dann <http://localhost:3000> öffnen. Andere Installationswege (Binary,
Desktop): <https://docs.silverbullet.md/Install>.

> Hinweis: Silverbullet rät davon ab, den Server auf Dateisystemen ohne
> Unterscheidung von Groß-/Kleinschreibung zu betreiben (Standard bei macOS und
> Windows). Für den Einstieg auf dem eigenen Rechner funktioniert es in der
> Regel; für den Dauerbetrieb ist Linux empfohlen.

### 4. Werkzeuge für PDFs (empfohlen)

Damit das LLM auch PDFs zuverlässig lesen kann, `poppler` installieren
(liefert `pdftotext`, `pdftoppm`, `pdfinfo`):

| System | Befehl |
|---|---|
| macOS | `brew install poppler` |
| Debian/Ubuntu/WSL | `sudo apt install poppler-utils` |
| Windows | am einfachsten innerhalb von WSL wie oben |

Optional für PowerPoint- und Word-Dateien: **LibreOffice**
(`brew install --cask libreoffice` bzw. <https://de.libreoffice.org>). Dann kann
das LLM `.pptx`/`.docx` selbst in PDF umwandeln. Ohne LibreOffice solche
Dateien vorher selbst als PDF exportieren.

### 5. Git (empfohlen)

Das Wiki ist ein Ordner mit Markdown-Dateien. Mit Git bekommst du eine
vollständige Versionsgeschichte und siehst jede Änderung des LLM als Diff.
Download: <https://git-scm.com> (unter macOS ist Git mit den Xcode Command Line
Tools meist schon vorhanden).

---

## Erste Schritte

1. **Vorlage entpacken und umbenennen**, z. B. in `mein-wiki`.

2. **Git einrichten** (optional, empfohlen):

   ```bash
   cd mein-wiki
   git init
   git add -A
   git commit -m "Wiki aus Vorlage angelegt"
   ```

3. **Wiki öffnen**: in Obsidian *Ordner als Vault öffnen* und `mein-wiki`
   wählen – oder Silverbullet wie oben starten.

4. **Claude Code im Wiki-Ordner starten**:

   ```bash
   cd mein-wiki
   claude
   ```

   Claude Code liest automatisch die `CLAUDE.md` und kennt damit alle Regeln.

5. **Wiki einrichten** – in Claude Code eingeben:

   ```
   /wiki-setup
   ```

   Claude fragt nach Thema, Zweck, Zielgruppe und typischen Quellen und passt
   die Vorlage daran an. Du kannst die Angaben auch gleich mitgeben, z. B.
   `/wiki-setup Thema: Hausbau 2026, Zweck: Entscheidungen mit dem Architekten
   vorbereiten`.

6. **Erste Quelle einarbeiten**: eine Datei (Artikel, PDF, Protokoll …) nach
   `raw/` legen und eingeben:

   ```
   /wiki-ingest
   ```

   Claude liest die Quelle, bespricht die Kernaussagen mit dir und legt dann
   Quellen-, Entitäts- und Konzeptseiten an. Schau dir das Ergebnis parallel in
   Obsidian an.

7. **Fragen stellen**:

   ```
   /wiki-query Welche Optionen gibt es für die Heizung und was spricht jeweils dafür?
   ```

   Gute Antworten kann Claude als Synthese-Seite im Wiki ablegen.

8. **Ab und zu aufräumen**:

   ```
   /wiki-lint
   ```

   Claude sucht nach Widersprüchen, verwaisten Seiten und Lücken und schlägt
   Korrekturen vor.

9. **Änderungen sichern**: nach jeder Sitzung `git add -A && git commit`.

> **Zum Üben:** Kopiere `LLM-Wiki-Idee.md` nach `raw/` und arbeite sie mit
> `/wiki-ingest` ein. So siehst du an einem bekannten Text, wie Quellen-,
> Konzept- und Entitätsseiten entstehen. Die Übungsseiten kannst du danach
> wieder löschen (oder behalten, wenn dein Wiki ohnehin von Wissensmanagement
> handelt).

---

## Aufbau

```
mein-wiki/
├── README.md            ← diese Datei
├── CLAUDE.md            ← das Schema: Regeln für das LLM (wird jede Sitzung gelesen)
├── LLM-Wiki-Idee.md     ← das Konzept nach Karpathy
├── index.md             ← Inhaltskatalog: was steht im Wiki?
├── log.md               ← chronologisches Protokoll aller Operationen
├── CONFIG.md            ← Silverbullet-Konfiguration
├── Library/             ← Silverbullet-Plugins
├── raw/                 ← deine Quellen (unveränderlich, das LLM liest nur)
│   ├── assets/          ← Bilder
│   └── README.md        ← welche Formate, wie ablegen
├── wiki/                ← gehört dem LLM
│   ├── overview.md      ← Einstiegsseite
│   ├── usage/           ← Panorama nutzen: Funktionen, Vorgehen, Oracle-Wissen
│   ├── development/     ← wie Panorama gebaut ist: Architektur, Designentscheidungen
│   ├── sources/         ← eine Zusammenfassung pro Quelle
│   └── syntheses/       ← aufbewahrte Antworten, Vergleiche, Analysen
├── .claude/skills/      ← die Skills für Claude Code
├── .github/skills/      ← dieselben Skills für GitHub Copilot
└── .obsidian/           ← Obsidian-Grundkonfiguration
```

### Die drei Schichten

- **`raw/`** – deine Quellen. Das LLM liest sie, verändert sie aber nie.
- **`wiki/`** – das wachsende, verlinkte Wissen. Hier schreibt nur das LLM.
- **Schema** – `CLAUDE.md` mit `index.md` und `log.md`. Die `CLAUDE.md`
  entwickelst du mit dem LLM weiter, wenn sich Konventionen ändern.

### Die Skills

| Befehl | Zweck |
|---|---|
| `/wiki-setup` | Einmalig: Wiki auf dein Thema zuschneiden |
| `/wiki-ingest` | Quelle aus `raw/` lesen und ins Wiki einarbeiten |
| `/wiki-query` | Frage aus dem Wiki beantworten, mit Belegen |
| `/wiki-lint` | Gesundheitscheck: Widersprüche, Waisen, Lücken, Status-Drift |

Du musst die Befehle nicht verwenden: „Arbeite bitte die neue Datei in raw/
ein“ funktioniert genauso.

---

## Konventionen (Kurzfassung)

Die vollständigen Regeln stehen in [CLAUDE.md](CLAUDE.md).

- Wiki-Inhalte auf **Englisch**; Fachbegriffe bleiben im Original.
- Jede Seite hat **YAML-Frontmatter** (`type`, `status`, `tags`,
  `created`/`updated`, `sources`) – nutzbar mit Dataview.
- Interne Links als **Wikilinks** mit reinem Dateinamen: `[[projekt-alpha]]`.
- Dateinamen in `kebab-case`, ohne Umlaute und Leerzeichen.
- **Widersprüche** werden markiert, nicht überschrieben; **Schlussfolgerungen**
  werden von belegten Fakten getrennt.
- Entscheidungen tragen einen `decision_status`
  (`proposed | adopted | resolved | rejected | superseded`).
- Log-Einträge beginnen mit `## [JJJJ-MM-TT] <op> | <Betreff>` und sind per
  `grep "^## \[" log.md | tail -5` auswertbar.

---

## Tipps

- **Obsidian Web Clipper** (Browsererweiterung) speichert Webartikel als
  Markdown – ideal, um Quellen schnell nach `raw/` zu bekommen.
- Der Anhang-Ordner in Obsidian ist bereits auf `raw/assets/` eingestellt.
  Unter *Einstellungen → Tastenkürzel* „Anhänge der aktuellen Datei
  herunterladen“ belegen, um Bilder geklippter Artikel lokal zu speichern.
- Die **Graphansicht** zeigt, welche Seiten Knotenpunkte und welche verwaist sind.
- Quellen lieber **einzeln** einarbeiten und dabei bleiben – das Ergebnis wird
  deutlich besser als bei großen Stapeln.
- Gute Antworten **ablegen lassen**: Sie summieren sich im Wiki auf, statt im
  Chat zu verschwinden.
- Ab etwa 100 Quellen lohnt sich eine lokale Suche wie
  [qmd](https://github.com/tobi/qmd).

## Andere Agenten

- **GitHub Copilot**: Die Skills liegen zusätzlich unter `.github/skills/`.
  Halte beide Ordner gleich, wenn du Skills änderst.
- **OpenAI Codex und andere Agenten**, die `AGENTS.md` lesen: `CLAUDE.md` nach
  `AGENTS.md` kopieren (oder verlinken: `ln -s CLAUDE.md AGENTS.md`).

---

## Häufige Fragen

**Muss ich selbst Wiki-Seiten schreiben?**
Nein. Du kuratierst Quellen und stellst Fragen; das LLM schreibt. Korrigieren
darfst du natürlich jederzeit – sag dem LLM am besten, was falsch war, damit es
alle betroffenen Seiten nachzieht.

**Was passiert mit meinen Daten?**
Die Dateien bleiben auf deinem Rechner. Zum Verarbeiten sendet Claude Code
Inhalte an die Anthropic-API. Prüfe vor dem Einarbeiten vertraulicher Unterlagen,
ob das mit deinen bzw. den Vorgaben deines Unternehmens vereinbar ist.

**Das LLM kann eine PDF nicht lesen.**
`poppler` installieren (siehe oben). Bei eingescannten PDFs ohne Textebene hilft
nur OCR vorab oder das Ansehen der Seiten als Bild.

**Wie groß darf das Wiki werden?**
Mit `index.md` als Einstieg funktioniert es gut bis etwa 100 Quellen und einige
Hundert Seiten. Darüber lohnt sich eine zusätzliche Suche.

**Kann ich die Struktur ändern?**
Ja. Besprich die Änderung mit dem LLM, lass sie zuerst in `CLAUDE.md` eintragen
und danach das Wiki anpassen.

---

Konzept: Andrej Karpathy, [„LLM Wiki“](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f).
