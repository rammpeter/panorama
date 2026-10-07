---
name: wiki-query
description: Eine Frage anhand des Wikis beantworten – passende Seiten über index.md und grep finden, eine belegte Antwort formulieren und dauerhaft wertvolle Antworten optional in wiki/syntheses/ ablegen. Verwenden, wenn der Nutzer eine Frage zum Thema des Wikis stellt und sie aus dem Wiki beantwortet haben will.
---

# Skill: wiki-query

Beantwortet Fragen mit dem angesammelten Wiki, statt sie aus den Rohquellen neu
herzuleiten. Lies zuerst `CLAUDE.md` für Struktur und Belegregeln.

## Ablauf

1. **Finden.** `index.md` lesen, um passende Seiten zu finden. Für Stichwörter,
   die nicht im Index stehen, mit `grep` über `wiki/` suchen. Dann die relevanten
   Seiten lesen.
2. **Zusammenführen.** Eine Antwort formulieren, die mehrere Seiten verbindet.
   Jede nicht offensichtliche Aussage mit einem Markdown-Link (relativer Pfad,
   kein Wikilink) auf die Seite bzw.
   Quelle **belegen**, aus der sie stammt. Belegte Fakten von Schlussfolgerungen
   trennen und Lücken ehrlich benennen („Das Wiki deckt X noch nicht ab – eine
   Quelle dazu einzuarbeiten würde helfen“).
3. **Form wählen**, die zur Frage passt: Fließtext, Vergleichstabelle, Liste
   oder (auf Wunsch) Diagramm bzw. Folien. Standard ist eine knappe
   Markdown-Antwort.
4. **Aufsummieren.** Ist die Antwort von bleibendem Wert (Vergleich, Analyse,
   entdeckter Zusammenhang), anbieten, sie als Seite in `wiki/syntheses/` mit
   korrektem Frontmatter und Querverweisen abzulegen und in `index.md`
   einzutragen. So verschwinden Erkundungen nicht im Chatverlauf.
5. **Protokollieren**: bemerkenswerte Fragen als
   `## [JJJJ-MM-TT] query | <Frage>` in `log.md` festhalten.

## Prinzipien

- Der Index ist der Einstieg; nicht blind jede Seite lesen.
- Keine unbelegten Aussagen zu Details des Themas – auf eine Quelle bzw. Seite
  zurückführen oder als Schlussfolgerung kennzeichnen.
- Kennt das Wiki die Antwort nicht, das offen sagen und vorschlagen, was
  eingearbeitet oder recherchiert werden sollte.
