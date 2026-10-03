# Panorama: Evaluate SGA memory usage and resize operations for Oracle DBs

Datum: 2018-09-05
URL: https://rammpeter.blogspot.com/2018/09/panorama-evaluate-sga-memory-usage-and.html
Labels: Analyze performance issue, Panorama How-To

---

Starting with release 10.1 Oracle introduced automatic shared memory management.

Setting only SGA_TARGET=x without defining limits for the SGA-components (buffer cache, shared pool, large pool, java pool) allows your database to redistribute SGA memory between components due to current needs.

This will work properly in many cases but sometimes there are some pitfalls:

A very common problem on Oracle databases are applications without usage of bind variables in their SQL statements.

Not using bind variables leads to excessive SGA memory consumption in shared pool and parse effort if you have a large number of SQLs executed with different values in filter conditions stored as literals.

For example:

SELECT a, b FROM Item WHERE ItemNo = 453612;
SELECT a, b FROM Item WHERE ItemNo = 876886;

etc. instead of

SELECT a, b FROM Item WHERE ItemNo = :ItemNo;

In such a situation the DB may resize the SGA. The size of the shared pool will grow thus reducing the size of the buffer cache.

In worst case this may lead to a SQL-area in shared pool which is much greater than the remaining buffer cache. Result in this case is poor SQL performance due to poor cache hit ratio.

With alternating load scenarios between heavy db-cache and SQL-area utilization there is also a risk of getting "ORA-04031 unable to allocate x bytes of shared memory" if SGA resize operations are not satisfied fast enough.

Solution for such a problematic skew position is to define minimum values for SGA components according to your needs thus preventing SGA components from falling below these values and reducing resize operations.

The minimum values set for e.g. DB_CACHE_SIZE and SHARED_POOL_SIZE may by smaller in sum than SGA_TARGET, so you may leave some remaining space for Oracle's own decision who gets it.

The Oracle performance analysis tool "Panorama" allows the evaluation of current and historic distribution of SGA memory between the components and also a view inside the objects and their memory consumption for some components.

Panorama is available free of charge at http://rammpeter.github.io/panorama.html.

View SGA components and their sizes (Menu "SGA/PGA details" / "SGA memory" / "SGA components")

View last resize operations (Click "Resize ops." in previous table) 

View content of SQL-area (Click on name "SQLA" in previous table)

Historic SGA resize operations

Current buffer cache content (Menu:  "SGA/PGA details" / "DB-cache" / "DB-cache usage current")

Panorama also has it's own sampling of historic information so consideration of DB-cache contents is also possible back in history even if this is not part of AWR-recordings. See http://rammpeter.github.io/panorama_sampler.html if interested.
