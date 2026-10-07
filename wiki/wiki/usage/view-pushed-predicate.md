---
title: VIEW PUSHED PREDICATE
type: concept
status: draft
tags: [execution-plan, optimizer, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# VIEW PUSHED PREDICATE

A technique for having grouping and sorting operations performed where the data
volume is smallest — instead of where the optimizer moves them of its own accord.

## The problem

> "The optimizer itself tends to move GROUP BY and SORT operations out to the
> last operation of a SQL, thus executing these operations on larger data sets
> than necessary."
> — [Blog series on execution plans and the optimizer](../sources/blog-execution-plans.md), 2023-06-07

The most efficient arrangement would be to group at the objects actually
affected, on the smallest number of rows and columns. The optimizer regularly
does the opposite.

## The measurement

The post reproduces the task: a table `ORDERS` (1 million rows) and `POSITIONS`
(3 million rows, three per order). Wanted are the orders of one customer,
enriched with the sum of quantity and price from the positions — one row per
order. Measured over 1 million calls on Oracle 19.19:

| Variant | µs per execution |
|---|---|
| 1 – join, then `GROUP BY` over everything | 91.97 |
| 2 – subselects in the select list | 51.45 |
| 2b – ditto, with `NO_MERGE` per subselect | 51.82 |
| 3 – subselect in the join, with an additional access on `ORDERS` | 81.32 |
| 3b – ditto, filter on `Customer_ID` duplicated | 115.18 |
| **Solution – `NO_MERGE` on an aggregating inline view** | **33.64** |

**38 % faster than the best alternative.** The author notes that in practice the
advantage is usually even greater, because there more columns and more joined
data sources are involved.

## The solution

```sql
SELECT o.ID, o.CreationDate, p.Quantity, p.Price
FROM   Orders o
JOIN  (SELECT /*+ NO_MERGE */ Order_ID, SUM(Quantity) Quantity, SUM(Price) Price
       FROM   Positions
       GROUP  BY Order_ID
      ) p ON p.Order_ID = o.ID
WHERE  o.Customer_ID = :customer_id;
```

The inline view apparently aggregates over *all* positions. In fact the database
pushes the join predicate into the view — the `VIEW PUSHED PREDICATE` operation —
and groups per order over that order's own positions. The result:

- Both tables are touched **once each**.
- The grouping runs only over the positions of *one* order ID.

**Why the hint is necessary:** the optimizer's cost estimate often does not rate
this solution as the best. `NO_MERGE` prevents the view from being merged and
thereby forces the desired access.

## An additional benefit

Further partial results from the same data source need no additional subselect —
they come as additional aggregates from the same inline view:

```sql
SUM(CASE WHEN Quantity = 1 THEN Price END) Price1
```

## Relationships

- A use case for a deliberately placed hint → [Optimizer hints](optimizer-hints.md).
- Can be applied without changing the application via a SQL patch →
  [SQL plan management](sql-plan-management.md).
- The same pattern is used to optimise the check query in
  [Cross-table uniqueness](cross-table-uniqueness.md).
- The plans in the post are rendered with [Panorama](panorama.md).

## Open questions

- The post shows the execution plans as screenshots, which are not available via
  the feed. The plan shapes behind the measurements are therefore missing here.
- Measured on 19.19. Do the optimizers of newer releases rate the variant better
  of their own accord, so that the hint can be dropped?
- At what volume ratio between outer and inner table does the advantage tip over?

## Sources

- [Blog series on execution plans and the optimizer](../sources/blog-execution-plans.md)
