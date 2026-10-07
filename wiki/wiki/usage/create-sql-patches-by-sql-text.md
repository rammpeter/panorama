---
title: Create SQL patches by SQL text, not by SQL ID
type: decision
decision_status: adopted
status: draft
tags: [execution-plan, optimizer, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Create SQL patches by SQL text, not by SQL ID

**Status: adopted.** When creating a SQL patch, the parameter `sql_text` is
preferred over `sql_id` — even though it is the more expensive route.

## The choice

`DBMS_SQLDIAG.CREATE_SQL_PATCH` (or `DBMS_SQLDIAG_INTERNAL.i_create_patch`
before 12.2) accepts either a `sql_id` or the full `sql_text`. Both lead to the
same result.

## The rationale

> "I personally prefer SQL patch creation using SQL text because SQL-ID requires
> existence of SQL-Statement in SGA at SQL patch creation time."
> — [Blog series on execution plans and the optimizer](../sources/blog-execution-plans.md), 2018-01-14

The variant using the SQL ID requires the statement to **still be in the SGA** at
the time the patch is created. That is precisely what is often no longer the case
for a problem SQL — you typically analyse it from the AWR history, long after the
last execution.

The route via the SQL text is independent of that: the patch can still be created
when the statement has long been aged out of the SGA.

[Panorama](panorama.md) implements this decision: the "SQL patch" button generates a snippet
that explicitly uses "the more expensive alternative with SQL text instead of
SQL-ID" — so that a patch can be created for any SQL from the SGA **or** from the
AWR history.

## Open despite the decision (implementation risks)

- **The price is not quantified.** The source calls the variant "more expensive"
  but does not say what the extra cost consists of (runtime at creation? memory?
  parse effort?).
- **Text accuracy.** A patch created via the SQL text binds to its signature. How
  sensitive that is to formatting, whitespace or case is not covered by the
  source.

## Provenance

- An explicit personal preference of the blog author in the post of
  **2018-01-14** ("Panorama: Handle SQL patches for Oracle-DB"), implemented in
  Panorama's behaviour.
- Ingested into the wiki on 2026-10-01.

## Relationships

- Mechanics: [SQL plan management](sql-plan-management.md)
- A use case beyond pinning a plan: [Optimizer diagnostics](optimizer-diagnostics.md)

## Sources

- [Blog series on execution plans and the optimizer](../sources/blog-execution-plans.md)
