---
name: wiki-setup
description: Das Wiki einmalig für ein Thema einrichten – Thema, Zweck, Zielgruppe und typische Quellen abfragen und damit CLAUDE.md, wiki/overview.md, index.md, CONFIG.md und README.md personalisieren. Verwenden direkt nach dem Entpacken der Vorlage oder wenn der Nutzer das Wiki einrichten, initialisieren oder auf ein Thema zuschneiden will.
---

# Skill: wiki-setup

Macht aus der themenneutralen Vorlage ein Wiki für ein konkretes Thema. Lies
zuerst `CLAUDE.md` und `LLM-Wiki-Idee.md`, damit du Aufbau und Konzept kennst.

## Vorprüfung

- Suche in `CLAUDE.md` nach dem Marker `SETUP-PLATZHALTER`.
- **Fehlt er**, ist das Wiki bereits eingerichtet. Sage das dem Nutzer, zeige
  den aktuellen Abschnitt „Worum es in diesem Wiki geht“ und frage, ob er ihn
  überarbeiten will. Ändere ohne Zustimmung nichts.

## Fragen an den Nutzer

Stelle die Fragen gebündelt (nicht einzeln nacheinander) und biete zu jeder
Frage Beispiele an. Hat der Nutzer beim Aufruf schon Angaben gemacht, frage nur
nach, was fehlt.

1. **Thema und Titel** – Worum geht es? Wie soll das Wiki heißen?
   (z. B. „Projekt Alpha“, „Hausbau 2026“, „Machine-Learning-Grundlagen“)
2. **Zweck** – Wofür wird das Wissen gebraucht? (Projektarbeit, Recherche,
   Lernen, Entscheidungsvorbereitung …)
3. **Zielgruppe** – Nur der Nutzer selbst oder ein Team?
4. **Typische Quellen** – Was wird in `raw/` landen? (Protokolle, Fachartikel,
   PDFs, Webclips, Transkripte, E-Mails …)
5. **Typische Entitäten und Konzepte** – Welche Dinge (Personen, Organisationen,
   Produkte, Systeme, Orte) und Ideen (Methoden, Begriffe) sind zentral?
6. **Startseiten** – Sollen schon 1–3 Konzept- oder Entitätsseiten als Stubs
   angelegt werden? Wenn ja, welche?

## Anpassungen

Nach den Antworten, jeweils zielgenau (übriger Text bleibt unverändert):

1. **`CLAUDE.md`**
   - Den Abschnitt „Worum es in diesem Wiki geht“ inklusive Marker-Kommentar und
     Platzhalterliste durch eine kurze Beschreibung ersetzen: Thema, Zweck,
     Zielgruppe, typische Quellen, zentrale Entitäten und Konzepte, Hinweise zur
     Einordnung.
   - Den Titel in Zeile 1 auf `# <Titel> – LLM-Wiki: Schema & Betriebsanleitung`
     ändern.
   - Passen die Entity-Subtypes (`person | organisation | product | system |
     component | place | external`) nicht zum Thema, sie mit dem Nutzer
     abstimmen und im Abschnitt „Seitenformat“ sowie unter „Wohin gehört eine
     Seite?“ anpassen.
2. **`wiki/overview.md`** – den Platzhalter durch eine erste Übersicht ersetzen:
   Einleitung (was, wofür, für wen), `## Kernthemen` mit den zentralen Themen
   (als Wikilinks, falls Stubs angelegt werden) und `## Offene Fragen` mit dem,
   was das Wiki noch lernen muss. `status: stub` bleibt, `updated` auf heute.
3. **`index.md`** – den Titel auf `# <Titel> – Index` ändern und `updated` auf
   heute setzen.
4. **`CONFIG.md`** – die Silverbullet-Kopfzeile `# LLM-Wiki` durch `# <Titel>`
   ersetzen.
5. **`README.md`** – die Überschrift in Zeile 1 auf `# <Titel> – LLM-Wiki`
   ändern. Den restlichen Inhalt (Installation, erste Schritte) nicht anfassen.
6. **Stubs (optional)** – die gewünschten Seiten in `wiki/usage/` bzw.
   `wiki/development/` mit vollständigem Frontmatter (`status: stub`,
   `sources: []`) anlegen, jeweils mit Einzeiler-Definition und
   `## Offene Fragen`. In `index.md` unter der passenden Kategorie eintragen
   (den Eintrag „(noch keine)“ dort entfernen) und von `overview.md` verlinken.
7. **`log.md`** – anhängen:
   `## [JJJJ-MM-TT] setup | <Titel>` mit Thema, Zweck und der Liste der
   geänderten bzw. angelegten Dateien.

## Abschluss

- Berichte, welche Dateien geändert bzw. angelegt wurden.
- Nenne die nächsten Schritte: erste Quelle nach `raw/` legen, dann
  `/wiki-ingest` ausführen; Fragen mit `/wiki-query`; ab und zu `/wiki-lint`.
- Weise darauf hin, dass der Abschnitt in `CLAUDE.md` jederzeit gemeinsam
  weiterentwickelt werden kann.
