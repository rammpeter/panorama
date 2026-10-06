---
title: Panorama menu overview
type: overview
status: draft
tags: [panorama, menu, core]
created: 2026-10-05
updated: 2026-10-05
sources: [rammpeter.github.io.md, rammpeter.github.io/panorama_content_generated.html, rammpeter.github.io/2026-10-05-1303/panorama_content_generated.html]
---

# Panorama menu overview

Every menu entry of [[panorama]] with its purpose and the wiki page that
describes its use and the Oracle concept behind it.

## Summary

The menu has **seven top-level entries** and **124 functions** below them
([[rammpeter-github-io]]). The tables reproduce the page "Panorama: function
overview by top level menu entries", which is **generated from the source code**
(state: 2026-10-05 13:02 UTC) — the purpose column is the description text the
application itself carries for each entry, quoted unchanged. Bold rows are
submenus; `↳` marks an entry inside one.

The *Page* column is this wiki's addition. 66 of the 124 entries point to a
page; "—" means none exists yet (see *Open questions*).

How the three pillars of an analysis map onto these entries is described in
[[panorama-analysis-workflows]].

**What is shown depends on the situation.** The generated list is the full
catalogue. In a running Panorama, entries are hidden when they do not apply:
"Blocking locks historic from Panorama-Sampler" and "DB-cache usage historic"
appear only if the corresponding sampler recording is active for the database
(usage guide); the "Admin" menu appears only after "Admin login" with the master
password ([[panorama-client-state-and-security]]). That the menu is data
evaluated against the connected database is described in
[[panorama-request-and-rendering]].

## "DBA general"

| Entry | Purpose | Page |
|---|---|---|
| Start page | Show global information for chosen database | — |
| Dashboard | Show dashboard with current performance aspects | [[panorama]] |
| **DB-Locks** | | |
| ↳ Current | shows current locking state incl. blocking sessions | [[blocking-locks]] |
| ↳ Blocking locks historic from ASH | Show historic blocking locks information from Active Session History | [[blocking-locks]] |
| ↳ Blocking locks historic from Panorama-Sampler | Show historic blocking locks information from Panorama-Sampler | [[blocking-locks]] |
| **Redo-Logs** | | |
| ↳ Current | Show current redo log info from gv$Log | [[redo-logs]] |
| ↳ Historic from gv$Log_History | Show detailed historic redo log info from gv$Log_History | [[redo-logs]] |
| ↳ Historic from AWR | Show historic redo log info from Active Workload Repository (AWR) | [[redo-logs]] |
| Sessions | Show info of current DB-sessions | [[session-list]] |
| **Database configuration** | | |
| ↳ Init-Parameter | Show init-parameters of instance(s) | [[database-configuration]] |
| ↳ Resource limits | Show resource limits from gv$Resource_Limit | [[database-configuration]] |
| ↳ Optimizer hints | Show supported optimizer hints for this database | [[database-configuration]], [[optimizer-hints]] |
| ↳ DB options | Show DB options from V$Option | [[database-configuration]] |
| ↳ TNS services | Show TNS services from DBA_Services | [[database-configuration]] |
| ↳ Statistics level | Show system defaults for statistics level from gv$Statistics_Level | [[database-configuration]] |
| ↳ Diagnostic paths | Show info/paths from gv$Diag_Info | [[database-configuration]] |
| ↳ Database properties | Show info from Database_Properties | [[database-configuration]] |
| ↳ Active SQL traces | Show activation rules for SQL traces and tracing sessions | [[database-configuration]], [[sql-trace]] |
| ↳ **DB vault configuration** | | |
| ↳ ↳ DB vault realms | Show configuration info for DB vault realms | — |
| **User management** | | |
| ↳ Database users | Show database users (DBA_Users) | — |
| ↳ Roles | Show database roles (DBA_Roles) | — |
| ↳ System privileges | Show system privileges (DBA_Sys_Privs) | — |
| ↳ Object privileges | Show object privileges (DBA_Tab_Privs) | — |
| ↳ User profiles | Show user profile settings (DBA_Profiles) | — |
| ↳ Gradual password rollover | Show users in password rollover interval May last longer because it scans Unified_Audit_Trail | [[gradual-password-rollover]] |
| **Audit Trail** | | |
| ↳ Auditing config | Show configuration options for standard and unified auditing | [[audit-trail]] |
| ↳ Auditing rules | Show rules for standard and fine grain auditing | [[audit-trail]] |
| ↳ Standard audit trail + FGA | Show activities logged by standard audit trail and fine grain auditing (DBA_Common_Audit_Trail) | [[audit-trail]] |
| ↳ Unified audit trail | Show activities logged by unified audit trail | [[audit-trail]], [[unified-audit-trail-operations]] |
| **Server Files** | | |
| ↳ Server Log Files | Show content of server logs (alert.log, listener.log, ASM-log) | — |
| ↳ Server Trace Files | Show trace files of DB server | [[panorama]], [[optimizer-diagnostics]] |
| ↳ Client errors (ADB) | Show client errors for autonomous DB | — |
| Database Triggers | Show global database triggers (like LOGON etc.) | [[logon-trigger]] |
| **DB links** | | |
| ↳ DB links outgoing | Show DB link config outgoing from this DB | — |
| ↳ DB links incoming | Show DB link usage incoming to this DB | — |
| **Scheduled Jobs** | | |
| ↳ Autotask jobs | Show jobs from DBA_Autotask_Client | — |
| ↳ Scheduler jobs | Show jobs from DBA_Scheduler_Jobs | — |
| Feature usage | Statistics about usage of features and packs of Oracle-DB | — |
| Upgrade/patch history | History of upgrades / downgrades / patches | — |

## "Analyses / statistics"

| Entry | Purpose | Page |
|---|---|---|
| **Session-Waits** | | |
| ↳ Current | All current session waits | [[session-waits]] |
| ↳ Historic | Prepared active session history from DBA_Hist_Active_Sess_History | [[session-waits]], [[ash]] |
| ↳ CPU-Usage / DB-Time | Historic CPU-Usage and DB-Time from DBA_Hist_Active_Sess_History. Shows you the difference between real CPU-usage and waiting for CPU if you don't have Resource Manager activated. Difference means you have more sessions waiting for CPU than your system's number of CPU-cores. | [[session-waits]] |
| ↳ Long-term trend | Long-term trend recording of session waits | [[long-term-trend-analysis]] |
| **Segment Statistics** | | |
| ↳ Current | Current waits by DB-objects | [[segment-statistics]] |
| ↳ Historic | Historic values (waits etc.) by DB-objects | [[segment-statistics]] |
| **System-Events** | | |
| ↳ Current | Current system events | — |
| ↳ Historic | Historic system events | — |
| **System statistics** | | |
| ↳ Historic | Historic system statistics | — |
| **System metric** | | |
| ↳ Historic | Historic system metric from DBA_Hist_Sysmetric_History | — |
| **Time model** | | |
| ↳ System time model historic | Historic system time model info from DBA_Hist_Sys_Time_Model | — |
| **Latch statistics** | | |
| ↳ Historic | Calculated historic info from DBA_Hist_Latch | — |
| **Mutex statistics** | | |
| ↳ Historic | Prepared historic information based on GV$Mutex_Sleep_History (since last start of instance) | [[library-cache-contention]] |
| **Enqueue statistics** | | |
| ↳ Historic | Calculated historic info from DBA_Hist_Enqueue_Stat | — |
| ↳ RAC Blocking Enqueue | Blocking enqueue locks known by RAC lock-manager | — |
| **OS statistics** | | |
| ↳ Current | Current statistics of operating system from gv$OSStat | — |
| ↳ Historic | Historic statistics of operating system from DBA_Hist_OSStat | — |
| **Genuine Oracle reports** | | |
| ↳ Performance Hub | Genuine Oracle performance hub report by time period and instance | [[genuine-oracle-reports]] |
| ↳ AWR report | Genuine Oracle active workload repository report by time period and instance | [[genuine-oracle-reports]] |
| ↳ AWR global report (RAC) | Genuine Oracle active workload repository global report for RAC by time period and instance (optional) | [[genuine-oracle-reports]] |
| ↳ ASH report | Genuine Oracle active session history report by time period and instance | [[genuine-oracle-reports]] |
| ↳ ASH global report (RAC) | Genuine Oracle active session history global report for RAC by time period and instance (optional) | [[genuine-oracle-reports]] |
| **RAC related analysis** | | |
| ↳ GC Request Latency historic | Analysis of global cache activity | — |
| ↳ Dynamic Remastering (DRM) events historic | History of master role changes for DB-objects between RAC-instances | [[dynamic-remastering]] |
| **Special event analysis** | | |
| ↳ Latch: cache buffer chains | Current reasons for 'cache buffer chains' latch-waits | — |
| ↳ db file sequential read | Current reasons for 'db file sequential read' waits (Attention: large response time at large systems) | — |

## "Schema / Storage"

| Entry | Purpose | Page |
|---|---|---|
| Disk-storage summary | Overview over disk space/tablespace usage by schema | — |
| Datafile-usage | Show data-files of DB | — |
| **UNDO-TS** | | |
| ↳ Undo segments summary | Current usage of undo space by segments | — |
| ↳ Active transactions | Current active transactions | — |
| ↳ Undo usage historic | Historic usage of UNDO space | — |
| Tablespace-Objects | DB-objects by size, utilization and wastage | [[storage-reorganisation]] |
| Object size evolution | Evolution of object sizes in considered time period | [[panorama-sampler]] |
| Describe object | Describe database object (table, index, materialized view ...) | [[describe-object]] |
| Invalid objects | List invalid objects (from DBA_Objects and DBA_Indexes) | — |
| Recycle bin | Show content of recycle bin | [[storage-reorganisation]] |
| Materialized view structures | Show structure of materialzed views and MV-logs | — |
| Table-dependencies | Direct and indirect referential dependencies of tables | — |
| **Temp usage** | | |
| ↳ Current | Current usage of TEMP-tablespace | [[temp-usage]] |
| ↳ Historic from SysMetric | Historic usage of TEMP tablespace from system metrics of AWR snapshots (down to sampling once per minute) | [[temp-usage]] |
| ↳ Historic from ASH | Historic usage of TEMP tablespace by active sessions from Active Session History (down to sampling once per second) | [[temp-usage]] |
| **EXADATA-specific** | | |
| ↳ Cell server config | Configuration of exadata cell server | — |
| ↳ **Cell server disk config** | | |
| ↳ ↳ Cell server physical disks | List physical disks of exadata cell server | — |
| ↳ ↳ Cell server cell disks | List configured cell disks of exadata cell server | — |
| ↳ ↳ Cell server grid disks | List configured grid disks of exadata cell server | — |
| ↳ **Cell server load analysis** | | |
| ↳ ↳ Past I/O by cells and DBs | List I/O load of exadata cell servers in the past by cell and DB | — |
| ↳ I/O resource mgr. config | List I/O resource manager config | — |
| ↳ Cell server open alerts | List open alerts of exadata cell server | — |
| **ASM grid infrastructure** | | |
| ↳ ASM disk groups | Disk groups of ASM grid infrastructure | — |
| ↳ ASM disks | Disks of ASM grid infrastructure | — |
| Object by file and block no. | Determine object-name by file- and block-no. | — |

## "I/O analysis"

| Entry | Purpose | Page |
|---|---|---|
| I/O-Stat detail history | I/O history based on DBA_Hist_IOStat_Detail | — |
| I/O-Stat filetype history | I/O history based on DBA_Hist_IOStat_FileType | — |
| I/O history by files | I/O history by files based on DBA_Hist_FileStatxs | — |

## "SGA/PGA-Details"

| Entry | Purpose | Page |
|---|---|---|
| **SQL-Area** | | |
| ↳ Current SQLs (SQL-ID) | Analysis of current SQL in SGA at level SQL-ID (cumulated across child-cursors) | [[sql-area]] |
| ↳ Current SQLs (SQL-ID / child-no.) | Analysis of current SQL in SGA at level SQL-ID, child-no. | [[sql-area]] |
| ↳ Historic SQLs | Analysis of historic SQL from DBA_Hist_SQLStat | [[sql-area]] |
| ↳ SQL-Monitor reports | Show recorded SQL-Monitor reports from gv$SQL_Monitor and DBA_HIST_Reports | [[sql-monitor]] |
| ↳ Long operations | Show long running operations from GV$Session_LongOps | [[long-operations]] |
| SQL-Area day comparison | Comparison of SQL-statements from two different days | — |
| **SGA Memory** | | |
| ↳ SGA-components current | Show components of current SGA | [[sga-memory-management]] |
| ↳ SGA-components historic | Show history of components of SGA | [[sga-memory-management]] |
| ↳ SGA resize operations historic | Show historic evolution of SGA resize operations | [[sga-memory-management]] |
| **DB-Cache** | | |
| ↳ DB-cache usage current | Current content of DB-cache | [[db-cache-usage]] |
| ↳ DB-cache advice | Historic view on what-happens-if-analysis for change of cache size | [[db-cache-usage]] |
| ↳ DB-cache usage historic | Historic view on DB-cache usage by Panorama_Cache_Objects | [[db-cache-usage]] |
| **Object usage by SQL** | | |
| ↳ Current | Usage of given objects in explain plan of current SQLs in SGA | — |
| ↳ Historic | Usage of given objects in explain plan of historic SQLs | — |
| **PGA-statistics** | | |
| ↳ Current | Show current PGA-usage | — |
| ↳ Historic from DBA_Hist_PGAStat | Historic usage of PGA memory from DBA_Hist_PGAStat | — |
| ↳ Historic from ASH | Historic usage of PGA memory by active sessions from Active Session History (down to sampling once per second) | — |
| **Result Cache** | | |
| ↳ Current | Show current usage of result cache | [[result-cache]] |
| SQL plan management | Show all SQL plan management directives of database: - SQL profiles - SQL plan baselines - Stored outlines - SQL translations - SQL patches | [[sql-plan-management]] |
| **Compare execution plans** | | |
| ↳ in current SGA | Compare execution plan of two different cursors in SGA | [[execution-plans]] |
| ↳ in historic AWR data | Compare two execution plans from AWR history | [[execution-plans]] |

## "Spec. additions"

| Entry | Purpose | Page |
|---|---|---|
| Dragnet investigation | Dragnet investigation for performance bottlenecks | [[dragnet]] |
| Execute with given parameters | Execute one of Panoramas functions directly with given parameters | [[panorama]] |
| SQL worksheet | SQL worksheet for executing and explaining SQL statements | — |
| Admin login | Login with master password to activate additional admin functions | [[panorama-client-state-and-security]] |

## "Admin"

| Entry | Purpose | Page |
|---|---|---|
| Panorama-Sampler config | Configure target databases for Panorama-Sampler | [[panorama-sampler]] |
| Set log level | Set the log level of Panorama server process | [[panorama-configuration]] |
| DB connection pool | Show current DB connections in connection pool and server threads of Panorama | [[panorama-connection]] |
| Usage history | Show history of Panorama usage by users | — |
| Server cache store sizes | Show sizes of server-side cache store in folder client_info.store | [[panorama-client-state-and-security]] |
| Admin logout | Logout from admin functions | — |

## Relationships

- The tool: [[panorama]]; how to move through it:
  [[panorama-analysis-workflows]].
- Grants some entries need: [[panorama-privileges]]; licences some entries need:
  [[management-pack-licensing]].
- Where the menu comes from in the code: [[panorama-request-and-rendering]].

## Open questions

- **58 entries have no page.** The website gives only their one-line purpose,
  which is not enough for a page that describes use and Oracle background. Whole
  groups are affected: user management, DB links, scheduled jobs, system events
  and statistics, latch and enqueue statistics, OS statistics, UNDO, Exadata,
  ASM, I/O analysis, PGA statistics, object usage by SQL, SQL worksheet. The
  source that could fill them is the repository ([[panorama-source-code]]).
- Several pages in the *Page* column are concept pages written from the blog and
  the talks; they explain the Oracle behaviour but do not all describe the menu
  entry itself in detail.
- Which entries are hidden under which condition (release, edition, licence,
  RAC, Exadata, container) is evidenced only for the three cases named above.
- The generated page carries no version number, only a timestamp.

## History

- **2026-10-05, first fetch** (page generated 2026-09-02): 123 entries; no
  entry for long operations.
- **2026-10-05, second fetch** (page regenerated 2026-10-05 13:02 UTC): 124
  entries. The only difference is the new entry "SGA/PGA-Details" / "SQL-Area" /
  "Long operations". Whether the entry was added to Panorama between the two
  dates or had been missing from the generated list is not evidenced; the blog
  already names this menu path ([[long-operations]]).

## Sources

- [[rammpeter-github-io]]
