---
name: wiki-lint
description: Gesundheitscheck des Wikis – Widersprüche, veraltete Aussagen, verwaiste Seiten, fehlende Konzeptseiten, fehlende Querverweise und Wissenslücken finden; einen Bericht erstellen und Korrekturen vorschlagen. Verwenden, wenn der Nutzer das Wiki aufräumen, prüfen oder pflegen will.
---

# Skill: wiki-lint

Regelmäßiger Gesundheitscheck, der das Wiki beim Wachsen konsistent hält. Lies
zuerst `CLAUDE.md` für die Konventionen, gegen die du prüfst.

## Prüfungen

1. **Widersprüche** – Aussagen auf verschiedenen Seiten, die sich widersprechen.
   Beide aufzeigen und angeben, welche Quelle neuer bzw. maßgeblicher ist.
2. **Veraltete Aussagen** – Aussagen, die eine neuere Quelle überholt hat.
   Kennzeichnen und Aktualisierungen vorschlagen.
3. **Verwaiste Seiten** – Seiten ohne eingehende Wikilinks. Vorschlagen, wo sie
   verlinkt werden sollten oder ob sie zusammengeführt bzw. entfernt werden.
4. **Fehlende Seiten** – Konzepte oder Entitäten, die auf mehreren Seiten
   erwähnt werden, aber keine eigene Seite haben. Anlegen vorschlagen.
5. **Fehlende Querverweise** – verwandte Seiten, die aufeinander verlinken
   sollten, es aber nicht tun.
6. **Index- und Log-Drift** – Seiten, die nicht in `index.md` stehen, oder
   veraltete Einzeiler; fehlende Log-Einträge.
7. **Frontmatter-Konformität** – fehlende oder falsche Angaben zu `type`,
   `status`, Datumsfeldern und `sources`. Auf Seiten mit `type: decision` ist
   `decision_status` **Pflicht**.
8. **Wissenslücken** – wichtige Fragen unter `## Offene Fragen`, die eine Quelle
   oder eine Websuche schließen könnte. Quellen bzw. Suchanfragen vorschlagen.
9. **Status-Drift** – der `decision_status` einer Entscheidung widerspricht der
   Darstellung an anderer Stelle im Wiki. Diese Prüfung findet Entscheidungen,
   die das Wiki als erledigt „kennt“, aber weiterhin als offen darstellt. Für
   jede Seite mit `type: decision`
   (in `wiki/usage/` und `wiki/development/`):
   - `decision_status` lesen, dann den **reinen Dateinamen** per `grep` über
     `wiki/` und `index.md` suchen, um eingehende Erwähnungen zu finden.
   - Jede Erwähnung markieren, deren Darstellung nicht passt: Formulierungen im
     Präsens wie `umstritten / offen / noch offen / ausstehend / vorgeschlagen /
     Dissens` (oder englisch `contested / pending / still open / proposed`) bei
     einer Seite mit `adopted`/`resolved` – oder umgekehrt.
   - Besonders den Einzeiler in `index.md` prüfen; er ist der Einstieg jeder
     Frage und driftet am leichtesten.
   - Abschnitte wie `## Offene Risiken` / `## Offene Fragen` in **Synthesen**
     prüfen – eine entschiedene Frage, die dort als aktuelles Risiko steht, ist
     die folgenreichste Form dieser Drift.
   - **Ausgenommen:** Seiten in `wiki/sources/` und `log.md`. Sie geben den Stand
     zum Zeitpunkt ihrer Quelle wieder und müssen ihn behalten. Ist eine
     Kernaussage einer Quellenseite inzwischen falsch, markiere sie als
     *überholt* mit Verweis – schreibe die Aussage nicht um.
   - Beim Beheben von Drift eine **verbleibende** offene Frage erhalten, statt
     alles auf „entschieden“ zu glätten (z. B. eine insgesamt getroffene
     Entscheidung, bei der eine Teilfrage noch offen ist).

## Ablauf

1. `index.md` lesen, dann `wiki/` durchgehen (mit `grep` nach Wikilinks und
   Überschriften suchen).
2. Einen **Bericht** erstellen, gegliedert nach Prüfung, jeder Punkt mit den
   betroffenen Seiten und einem Korrekturvorschlag.
3. Korrekturen **erst nach Freigabe** durch den Nutzer umsetzen (oder gesammelt,
   wenn er das so wünscht).
4. Bei geänderten Seiten `index.md` aktualisieren und
   `## [JJJJ-MM-TT] lint | <Zusammenfassung>` an `log.md` anhängen.

## Prinzipien

- Erst berichten, dann ändern. Keine umfassenden Änderungen ohne Auftrag.
- Neue Fragen zum Untersuchen und neue Quellen zum Suchen vorschlagen – das
  gehört dazu, das Wiki gesund zu halten.
