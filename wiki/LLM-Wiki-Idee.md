# LLM-Wiki

> Deutsche Übersetzung von Andrej Karpathys Gist „LLM Wiki“ (April 2026).
> Original: <https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f>

Ein Muster, um mit LLMs persönliche Wissensdatenbanken aufzubauen.

Dies ist eine Ideendatei. Sie ist dafür gedacht, in den eigenen LLM-Agenten
kopiert zu werden (z. B. OpenAI Codex, Claude Code, OpenCode / Pi o. Ä.). Ihr Ziel
ist es, die Grundidee zu vermitteln; die Einzelheiten erarbeitet dein Agent
gemeinsam mit dir.

## Die Kernidee

Die meisten Erfahrungen mit LLMs und Dokumenten sehen aus wie RAG: Man lädt eine
Sammlung von Dateien hoch, das LLM holt sich zur Fragezeit passende Abschnitte
heraus und erzeugt eine Antwort. Das funktioniert, aber das LLM entdeckt das
Wissen bei jeder Frage neu. Es sammelt sich nichts an. Stellt man eine knifflige
Frage, für die fünf Dokumente zusammengeführt werden müssen, muss das LLM die
relevanten Bruchstücke jedes Mal neu finden und zusammensetzen. Nichts wird
aufgebaut. NotebookLM, Datei-Uploads in ChatGPT und die meisten RAG-Systeme
arbeiten so.

Die Idee hier ist eine andere. Statt zur Fragezeit nur aus Rohdokumenten
abzurufen, **baut das LLM schrittweise ein dauerhaftes Wiki auf und pflegt es** –
eine strukturierte, untereinander verlinkte Sammlung von Markdown-Dateien, die
zwischen dir und den Rohquellen steht. Kommt eine neue Quelle hinzu, indiziert
das LLM sie nicht bloß für später. Es liest sie, zieht die wichtigsten
Informationen heraus und fügt sie in das bestehende Wiki ein: Es aktualisiert
Entitätsseiten, überarbeitet Themenzusammenfassungen, vermerkt, wo neue Daten
alten Aussagen widersprechen, und stärkt oder hinterfragt die sich
entwickelnde Synthese. Das Wissen wird einmal aufbereitet und dann *aktuell
gehalten*, nicht bei jeder Frage neu hergeleitet.

Das ist der entscheidende Unterschied: **Das Wiki ist ein dauerhaftes, sich
aufsummierendes Artefakt.** Die Querverweise sind schon da. Die Widersprüche
sind schon markiert. Die Synthese spiegelt bereits alles wider, was du gelesen
hast. Das Wiki wird mit jeder Quelle, die du hinzufügst, und jeder Frage, die du
stellst, reicher.

Du schreibst das Wiki nie (oder selten) selbst – das LLM schreibt und pflegt
alles. Du kümmerst dich um die Auswahl der Quellen, die Erkundung und die
richtigen Fragen. Das LLM erledigt die Kleinarbeit – Zusammenfassen,
Querverweisen, Ablegen und Buchführung –, die eine Wissensdatenbank auf Dauer
erst nützlich macht. In der Praxis habe ich auf der einen Seite den LLM-Agenten
offen und auf der anderen Obsidian. Das LLM nimmt Änderungen auf Grundlage
unseres Gesprächs vor, und ich sehe mir die Ergebnisse in Echtzeit an – folge
Links, schaue in die Graphansicht, lese die aktualisierten Seiten. Obsidian ist
die IDE, das LLM ist der Programmierer, das Wiki ist die Codebasis.

Das lässt sich auf viele Bereiche anwenden. Einige Beispiele:

- **Persönlich**: eigene Ziele, Gesundheit, Psychologie und Selbstverbesserung
  verfolgen – Tagebucheinträge, Artikel und Podcast-Notizen ablegen und nach und
  nach ein strukturiertes Bild von sich selbst aufbauen.
- **Recherche**: sich über Wochen oder Monate in ein Thema vertiefen – Paper,
  Artikel und Berichte lesen und schrittweise ein umfassendes Wiki mit einer sich
  entwickelnden These aufbauen.
- **Ein Buch lesen**: jedes Kapitel beim Lesen ablegen und Seiten zu Figuren,
  Themen und Handlungssträngen samt ihren Verbindungen anlegen. Am Ende hat man
  ein reichhaltiges Begleit-Wiki. Man denke an Fan-Wikis wie
  [Tolkien Gateway](https://tolkiengateway.net/wiki/Main_Page) – Tausende
  verlinkte Seiten zu Figuren, Orten, Ereignissen und Sprachen, über Jahre von
  einer Gemeinschaft Freiwilliger aufgebaut. So etwas könnte man beim Lesen
  persönlich aufbauen, während das LLM alle Querverweise und die Pflege übernimmt.
- **Unternehmen/Team**: ein internes Wiki, das von LLMs gepflegt wird und aus
  Slack-Threads, Besprechungstranskripten, Projektdokumenten und Kundengesprächen
  gespeist wird – eventuell mit Menschen, die Änderungen prüfen. Das Wiki bleibt
  aktuell, weil das LLM die Pflege übernimmt, die im Team niemand machen will.
- **Wettbewerbsanalyse, Due Diligence, Reiseplanung, Kursnotizen,
  Hobby-Vertiefungen** – alles, wobei man über längere Zeit Wissen sammelt und es
  geordnet statt verstreut haben möchte.

## Architektur

Es gibt drei Schichten:

**Rohquellen** – deine kuratierte Sammlung von Quelldokumenten: Artikel, Paper,
Bilder, Datendateien. Sie sind unveränderlich – das LLM liest sie, verändert sie
aber nie. Sie sind die maßgebliche Quelle.

**Das Wiki** – ein Verzeichnis mit vom LLM erzeugten Markdown-Dateien:
Zusammenfassungen, Entitätsseiten, Konzeptseiten, Vergleiche, eine Übersicht,
eine Synthese. Diese Schicht gehört ganz dem LLM. Es legt Seiten an, aktualisiert
sie, wenn neue Quellen eintreffen, pflegt Querverweise und hält alles
konsistent. Du liest es; das LLM schreibt es.

**Das Schema** – ein Dokument (z. B. `CLAUDE.md` für Claude Code oder
`AGENTS.md` für Codex), das dem LLM erklärt, wie das Wiki aufgebaut ist, welche
Konventionen gelten und welchen Abläufen es beim Einarbeiten von Quellen, beim
Beantworten von Fragen oder bei der Pflege folgt. Das ist die zentrale
Konfigurationsdatei – sie macht aus dem LLM einen disziplinierten Wiki-Pfleger
statt eines allgemeinen Chatbots. Du und das LLM entwickelt sie gemeinsam weiter,
während ihr herausfindet, was für euer Thema funktioniert.

## Operationen

**Einarbeiten (Ingest).** Du legst eine neue Quelle in die Rohsammlung und
bittest das LLM, sie zu verarbeiten. Ein möglicher Ablauf: Das LLM liest die
Quelle, bespricht die Kernaussagen mit dir, schreibt eine Zusammenfassungsseite
ins Wiki, aktualisiert den Index, aktualisiert die betroffenen Entitäts- und
Konzeptseiten im ganzen Wiki und hängt einen Eintrag ans Log an. Eine einzelne
Quelle kann 10–15 Wiki-Seiten berühren. Ich persönlich arbeite Quellen lieber
einzeln ein und bleibe dabei – ich lese die Zusammenfassungen, prüfe die
Änderungen und sage dem LLM, was es betonen soll. Man kann aber auch viele
Quellen auf einmal mit weniger Aufsicht einarbeiten. Es liegt an dir, den Ablauf
zu entwickeln, der zu deinem Stil passt, und ihn für künftige Sitzungen im Schema
festzuhalten.

**Fragen (Query).** Du stellst Fragen an das Wiki. Das LLM sucht passende Seiten,
liest sie und formuliert eine Antwort mit Belegen. Je nach Frage kann die Antwort
verschiedene Formen haben – eine Markdown-Seite, eine Vergleichstabelle, ein
Foliensatz (Marp), ein Diagramm (matplotlib), ein Canvas. Die wichtige Einsicht:
**Gute Antworten können als neue Seiten zurück ins Wiki abgelegt werden.** Ein
Vergleich, den du angefragt hast, eine Analyse, ein Zusammenhang, den du entdeckt
hast – all das ist wertvoll und sollte nicht im Chatverlauf verschwinden. So
summieren sich deine Erkundungen in der Wissensdatenbank genauso auf wie
eingearbeitete Quellen.

**Prüfen (Lint).** Bitte das LLM regelmäßig um einen Gesundheitscheck des Wikis.
Gesucht wird nach: Widersprüchen zwischen Seiten, veralteten Aussagen, die neuere
Quellen überholt haben, verwaisten Seiten ohne eingehende Links, wichtigen
Konzepten, die erwähnt werden, aber keine eigene Seite haben, fehlenden
Querverweisen und Datenlücken, die eine Websuche füllen könnte. Das LLM ist gut
darin, neue Fragen zum Untersuchen und neue Quellen zum Suchen vorzuschlagen. So
bleibt das Wiki beim Wachsen gesund.

## Index und Log

Zwei besondere Dateien helfen dem LLM (und dir), sich im wachsenden Wiki
zurechtzufinden. Sie dienen unterschiedlichen Zwecken:

**index.md** ist inhaltsorientiert. Es ist ein Katalog von allem, was im Wiki
steht – jede Seite mit Link, Einzeiler und optional Metadaten wie Datum oder
Anzahl der Quellen. Gegliedert nach Kategorien (Entitäten, Konzepte, Quellen
usw.). Das LLM aktualisiert ihn bei jedem Ingest. Bei einer Frage liest das LLM
zuerst den Index, um passende Seiten zu finden, und geht dann in die Tiefe. Das
funktioniert in mittlerer Größenordnung (~100 Quellen, einige Hundert Seiten)
erstaunlich gut und erspart eine embedding-basierte RAG-Infrastruktur.

**log.md** ist chronologisch. Es ist ein nur ergänztes Protokoll dessen, was wann
passiert ist – Ingests, Fragen, Lint-Durchläufe. Ein nützlicher Tipp: Beginnt
jeder Eintrag mit demselben Präfix (z. B. `## [2026-04-02] ingest | Titel des
Artikels`), lässt sich das Log mit einfachen Unix-Werkzeugen auswerten –
`grep "^## \[" log.md | tail -5` liefert die letzten fünf Einträge. Das Log zeigt
die Entwicklung des Wikis über die Zeit und hilft dem LLM zu verstehen, was
zuletzt getan wurde.

## Optional: CLI-Werkzeuge

Irgendwann möchtest du vielleicht kleine Werkzeuge bauen, mit denen das LLM
effizienter am Wiki arbeitet. Das naheliegendste ist eine Suchmaschine über die
Wiki-Seiten – bei kleiner Größe reicht die Indexdatei, aber wenn das Wiki wächst,
braucht man eine richtige Suche. [qmd](https://github.com/tobi/qmd) ist eine gute
Option: eine lokale Suchmaschine für Markdown-Dateien mit hybrider
BM25-/Vektorsuche und LLM-Re-Ranking, alles auf dem eigenen Gerät. Sie hat eine
CLI (das LLM kann sie also per Shell aufrufen) und einen MCP-Server (das LLM kann
sie als natives Werkzeug nutzen). Du kannst auch selbst etwas Einfacheres bauen –
das LLM hilft dir, bei Bedarf ein simples Suchskript zu schreiben.

## Tipps und Tricks

- **Obsidian Web Clipper** ist eine Browsererweiterung, die Webartikel in
  Markdown umwandelt. Sehr nützlich, um Quellen schnell in die Rohsammlung zu
  bekommen.
- **Bilder lokal herunterladen.** In Obsidian unter *Einstellungen → Dateien und
  Links* den „Ordner für Anhänge“ auf ein festes Verzeichnis setzen (z. B.
  `raw/assets/`). Dann unter *Einstellungen → Tastenkürzel* nach „Download“
  suchen, um „Anhänge der aktuellen Datei herunterladen“ zu finden, und ein
  Tastenkürzel vergeben (z. B. Strg+Umschalt+D). Nach dem Clippen eines Artikels
  das Tastenkürzel drücken, und alle Bilder landen auf der lokalen Platte. Das
  ist optional, aber nützlich – so kann das LLM Bilder direkt ansehen und
  referenzieren, statt sich auf URLs zu verlassen, die kaputtgehen können.
  Hinweis: LLMs können Markdown mit eingebetteten Bildern nicht in einem Durchgang
  lesen – die Lösung ist, das LLM erst den Text lesen zu lassen und dann einige
  oder alle referenzierten Bilder separat, um zusätzlichen Kontext zu bekommen.
  Etwas umständlich, funktioniert aber gut genug.
- **Die Graphansicht in Obsidian** ist der beste Weg, die Gestalt des Wikis zu
  sehen – was womit verbunden ist, welche Seiten Knotenpunkte sind und welche
  verwaist.
- **Marp** ist ein Markdown-basiertes Format für Foliensätze. Für Obsidian gibt
  es ein Plugin dafür. Nützlich, um Präsentationen direkt aus Wiki-Inhalten zu
  erzeugen.
- **Dataview** ist ein Obsidian-Plugin, das Abfragen über das Frontmatter von
  Seiten ausführt. Fügt dein LLM YAML-Frontmatter zu den Wiki-Seiten hinzu (Tags,
  Datumsangaben, Anzahl der Quellen), kann Dataview daraus dynamische Tabellen und
  Listen erzeugen.
- Das Wiki ist einfach ein Git-Repository aus Markdown-Dateien. Versionshistorie,
  Branches und Zusammenarbeit gibt es gratis dazu.

## Warum das funktioniert

Das Mühsame an der Pflege einer Wissensdatenbank ist nicht das Lesen oder das
Nachdenken – es ist die Buchführung. Querverweise aktualisieren,
Zusammenfassungen aktuell halten, vermerken, wenn neue Daten alten Aussagen
widersprechen, Konsistenz über Dutzende Seiten wahren. Menschen geben Wikis auf,
weil der Pflegeaufwand schneller wächst als der Nutzen. LLMs langweilen sich
nicht, vergessen keinen Querverweis und können in einem Durchgang 15 Dateien
anfassen. Das Wiki bleibt gepflegt, weil die Pflege fast nichts kostet.

Die Aufgabe des Menschen ist es, Quellen auszuwählen, die Analyse zu steuern,
gute Fragen zu stellen und darüber nachzudenken, was das alles bedeutet. Die
Aufgabe des LLM ist alles andere.

Die Idee ist im Geiste verwandt mit Vannevar Bushs Memex (1945) – einem
persönlichen, kuratierten Wissensspeicher mit assoziativen Pfaden zwischen
Dokumenten. Bushs Vision lag näher an diesem Ansatz als an dem, was aus dem Web
wurde: privat, aktiv kuratiert, und die Verbindungen zwischen Dokumenten genauso
wertvoll wie die Dokumente selbst. Was er nicht lösen konnte, war die Frage, wer
die Pflege übernimmt. Das erledigt das LLM.

## Hinweis

Dieses Dokument ist bewusst abstrakt gehalten. Es beschreibt die Idee, nicht eine
bestimmte Umsetzung. Die genaue Verzeichnisstruktur, die Schema-Konventionen, die
Seitenformate, die Werkzeuge – all das hängt von deinem Thema, deinen Vorlieben
und deinem LLM ab. Alles oben Genannte ist optional und modular – nimm, was
nützlich ist, und lass den Rest weg. Zum Beispiel: Deine Quellen sind vielleicht
reiner Text, dann brauchst du keine Bildverarbeitung. Dein Wiki ist vielleicht
klein genug, dass die Indexdatei reicht und keine Suchmaschine nötig ist.
Vielleicht sind dir Foliensätze egal und du willst nur Markdown-Seiten.
Vielleicht willst du ganz andere Ausgabeformate. Der richtige Weg ist, dieses
Dokument mit deinem LLM-Agenten zu teilen und gemeinsam eine Variante zu bauen,
die zu deinen Bedürfnissen passt. Die einzige Aufgabe des Dokuments ist es, das
Muster zu vermitteln. Den Rest kann dein LLM herausfinden.
