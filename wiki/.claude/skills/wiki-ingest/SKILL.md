---
name: wiki-ingest
description: Eine oder mehrere Quellen aus raw/ ins Wiki einarbeiten – Quelle lesen, zusammenfassen, Entitäts- und Konzeptseiten aktualisieren, Querverweise pflegen, index.md aktualisieren und einen Eintrag an log.md anhängen. Verwenden, wenn der Nutzer eine Datei in raw/ ablegt und sie einarbeiten, verarbeiten oder ablegen lassen will.
---

# Skill: wiki-ingest

Arbeitet eine neue Quelle so ins Wiki ein, dass ihr Wissen einmal aufbereitet und
danach aktuell gehalten wird – statt es bei jeder Frage neu herzuleiten. Lies
zuerst `CLAUDE.md` für das Schema (Seitenformate, Frontmatter, Einordnung,
Namensregeln).

## Voraussetzung

Steht in `CLAUDE.md` noch der Marker `SETUP-PLATZHALTER`, ist das Wiki nicht
eingerichtet. Weise den Nutzer darauf hin und empfiehl, zuerst `/wiki-setup`
auszuführen. Fahre nur fort, wenn er das ausdrücklich nicht möchte.

## Eingaben

- Eine Quelle (oder mehrere) in `raw/`. Hat der Nutzer keine genannt, liste die
  zuletzt hinzugekommenen Dateien in `raw/` auf und frage, welche eingearbeitet
  werden soll (oder bestätige die Stapelverarbeitung aller neuen Dateien).
  Welche Quellen schon verarbeitet sind, zeigen `log.md` und das Feld `sources`
  der Seiten in `wiki/sources/`.

## Ablauf

1. **Quelle vollständig lesen.** Zuerst den Text. Verweist sie auf Bilder in
   `raw/assets/`, sieh sie dir separat an. Für PDFs und Office-Formate gelten die
   Hinweise in `CLAUDE.md` („Unterstützte Quellformate“).
2. **Kernaussagen besprechen**, bevor viele Seiten geändert werden – außer der
   Nutzer hat eine unbeaufsichtigte Stapelverarbeitung verlangt. Kläre, was
   betont werden soll.
3. **Quellenseite anlegen** in `wiki/sources/` (kebab-case, bei Bedarf mit
   Datum). Mit Frontmatter (`type: source`), Zusammenfassung,
   **`## Kernaussagen`**, **`## Auswirkungen auf das Wiki`** und einem Verweis
   auf den Dateinamen in `raw/`.
4. **Entitäts- und Konzeptseiten aktualisieren.** Für neu auftauchende Dinge und
   Ideen neue Seiten anlegen, bestehende stärken. Querverweise in beide
   Richtungen setzen. Eine Quelle berührt oft 5–15 Seiten. Die Einordnung folgt
   `CLAUDE.md`: Das Verzeichnis ist die Kategorie (`wiki/usage/` = Panorama
   nutzen, `wiki/development/` = wie Panorama gebaut ist), die Art der Seite
   steht im Frontmatter-Feld `type` (Entitäten = konkrete Dinge,
   Konzepte = Ideen, Entscheidungen = Wahl + Begründung).
5. **Widersprüche kennzeichnen.** Widerspricht die Quelle einer bestehenden
   Aussage, beide festhalten, die ältere markieren und unter `## Offene Fragen`
   sowie im Log vermerken. Nichts stillschweigend überschreiben.
6. **Schlussfolgerungen** von belegten Fakten trennen. Aussagen mit
   Markdown-Links auf die Quellenseite belegen (relativer Pfad, z. B.
   `[Blog zu Locks](../sources/blog-locks.md)`; keine Wikilinks – Regeln in
   `CLAUDE.md`, Abschnitt „Links“).
7. **`index.md` aktualisieren** – neue Seiten aufnehmen, Einzeiler auffrischen,
   Einträge aus „(noch keine)“-Abschnitten herausnehmen.
8. **Eintrag an `log.md` anhängen**: `## [JJJJ-MM-TT] ingest | <Titel der Quelle>`
   mit einer kurzen Notiz, was sich geändert hat und welche Seiten berührt wurden.
9. **Berichten**: alle angelegten und geänderten Seiten auflisten, dazu
   Widersprüche und offene Fragen, die aufgetaucht sind.

## Prinzipien

- Lieber wenige, gehaltvolle Seiten als viele dünne; verlinken statt duplizieren.
- Das Wiki konsistent halten: Ändert sich eine Seite, alles aktualisieren, was
  auf sie verweist.
- Das heutige Datum (absolut) in Frontmatter und Log verwenden.
- Dateien in `raw/` werden nie verändert.
