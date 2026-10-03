# Clarify myths of indexing foreign key constraints on Oracle-DB

Datum: 2016-11-25
URL: https://rammpeter.blogspot.com/2016/11/clarify-myths-of-indexing-foreign-key.html
Labels: Analyze performance issue

---

If you use foreign keys there’s one very common dogma:

You always need to index all the column(s) for which you define a foreign key constraint!

I definitely do not agree with this dogma and want to explain why.

There are two reasons for indexing columns with foreign key constraints: 

- Avoiding full table scans on referencing table during deletes on referenced tables 

- Avoiding blocking lock problems e.g. if you are doing DML on both referencing and referenced table 

You may find a detailed description of the locking behaviour of foreign keys at chapter "Locks and Foreign Keys" here in the Oracle documentation.

Considerations on full table scan due to foreign key constraint not protected by index 

- If you do not index referencing column(s) than delete on referenced table leads to a full table scan on referencing table for every deleted row 

- Therefore you should index referencing column(s) especially in OLTP-environments if your referenced table has more than a small amount of records and there are DELETE-Operations on this referenced table. 

- Otherwise you really needn’t index the referencing column(s) if your referenced table has only few records 

- In this case: 

- rare cases of full table scan due to delete on referenced table can be accepted 

- an index would be very little selective and useless for data access, but costs storage and maintenance effort during DML 

Lock-behavior with and without indexed foreign key column(s) for several Oracle releases starting with 11.2

Let’s consider two tables with foreign key constraint, the parent table Dim and the child table Fact.

Result tables shows lock types TM for Session 1 and 2 for different Oracle-versions and Session 2 blocking or not.

CREATE TABLE Dim (ID Number, Name VARCHAR2(100), 
CONSTRAINT Dim_PK PRIMARY KEY (ID));

CREATE TABLE Fact (ID NUMBER, Name VARCHAR2(100), Dim_ID NUMBER,
CONSTRAINT Fact_PK PRIMARY KEY (ID),
CONSTRAINT Dim_FK FOREIGN KEY (Dim_ID) REFERENCES Dim(ID)
);

At first there is no index at Fact(Dim_ID) for the next tests.

The lock modes named for the following scenarios are:

- RS: row share lock (mode 2)

- RX: row exclusive lock (mode 3)

- S: share lock (mode 4)

- X: exklusive lock (mode 6) 

A compatibility matrix for different lock modes can be found in Oracle's documentation up to release 11.1

Szenario 1: Pending insert-DML on Dim + insert into Dim in concurrent session without index on Fact(Dim_ID)

Step 1 with session 1

INSERT INTO Dim VALUES (1, 'First');
INSERT INTO Dim VALUES (2, 'Second');
COMMIT;

INSERT INTO Dim VALUES (3, 'Third');

Step 2 with session 2

INSERT INTO Dim VALUES (4, 'Third');

DBSession 1Session 2Block

11.2RX lock on both Dim and FactRX lock on both Dim and Fact

12.1RX lock on Dim and a RS lock on Fact RX lock on Dim and a RS lock on Fact

19.3RX lock on Dim and a RS lock on Fact RX lock on Dim and a RS lock on Fact

Szenario 2: Pending insert-DML on Dim + update on Dim without index on Fact(Dim_ID)

Step 1 with session 1

INSERT INTO Dim VALUES (1, 'First');
INSERT INTO Dim VALUES (2, 'Second');
COMMIT;

INSERT INTO Dim VALUES (3, 'Third');

Step 2 with session 2

UPDATE Dim SET Name = 'Firster' WHERE ID=1;

DBSession 1Session 2Block

11.2RX lock on both Dim and FactRX lock on Dim

12.1RX lock on Dim and RS lock on FactRX lock on Dim

19.3RX lock on Dim and RS lock on FactRX lock on Dim

Step 3 with session 2, now including the PK-column in the update

UPDATE Dim SET ID=1, Name = 'Firster' WHERE ID=1;

DBSession 1Session 2Block

11.2RX lock on both Dim and FactRX lock on Dim and requesting S lock on Fact that is blocked by RX lock from session 1"enq: TM - contention"

12.1RX lock on Dim and RS lock on FactRX lock on Dim but no lock on Fact

19.3RX lock on Dim and RS lock on FactRX lock on Dim but no lock on Fact

Szenario 2: Same again, but with index on Fact(Dim_ID)

CREATE INDEX Protect_FK ON Fact(Dim_ID);

Now with index updating the PK-column by session 2 is possible without blocking lock also for Oracle 11.2.

Szenario 3: Pending update on Dim + insert on Dim in concurrent session without index on Fact(Dim_ID)

Step 1 with session 1

INSERT INTO Dim VALUES (1, 'First');
INSERT INTO Dim VALUES (2, 'Second');
COMMIT;
UPDATE Dim Set ID=1, Name = 'FIRSTER' WHERE ID=1;

Step 2 with session 2

INSERT INTO Dim VALUES (4, 'Fourth');

DBSession 1Session 2Block

11.2RX lock on DimRX lock on both Dim and Fact

12.1RX lock on DimRX lock on Dim and RS lock on Fact

19.3RX lock on DimRX lock on Dim and RS lock on Fact

Szenario 4: Pending insert-DML on Dim + insert on Fact without index on Fact(Dim_ID)

Step 1 with session 1

INSERT INTO Dim VALUES (1, 'First');
INSERT INTO Dim VALUES (2, 'Second');
COMMIT;
INSERT INTO Dim VALUES (3, 'Third');

Step 2 with session 2

INSERT INTO Fact VALUES (1, 'First', 1);

DBSession 1Session 2Block

11.2RX lock on both Dim and FactRX lock on both Dim and Fact

12.1RX lock on Dim and RS lock on FactRX lock on both Dim and Fact

19.3RX lock on Dim and RS lock on FactRX lock on both Dim and Fact

Szenario 5: Pending update on Dim + insert on Fact without index on Fact(Dim_ID)

Step 1 with session 1

INSERT INTO Dim VALUES (1, 'First');
INSERT INTO Dim VALUES (2, 'Second');
COMMIT;
UPDATE Dim SET ID=2, Name='More' WHERE ID=2;

Step 2 with session 2

INSERT INTO Fact VALUES (1, 'First', 2);

DBSession 1Session 2Block

11.2RX lock on DimRX lock on both Dim and Fact

12.1RX lock on DimRX lock on both Dim and Fact

19.3RX lock on DimRX lock on both Dim and Fact

In this case it doesn’t matter that PK-column is updated because share lock on Fact is only held shortly by session 1 during update.

Szenario 6: Concurrent DML on Fact with same Dim_ID without index on Fact(Dim_ID)

Step 1 with session 1

INSERT INTO Dim VALUES (1, 'First');
INSERT INTO Dim VALUES (2, 'Second');
INSERT INTO Fact VALUES (1, 'First', 1);
INSERT INTO Fact VALUES (2, 'Second', 1);
COMMIT;
UPDATE Fact SET Dim_ID=1, Name='More' WHERE ID=1;

Step 2 with session 2

UPDATE Fact SET Dim_ID=1, Name='More' WHERE ID=2;
INSERT INTO Fact VALUES (3, 'Hugo', 1);

Step 3 with session 1

DELETE FROM Fact WHERE ID=1;

DBSession 1Session 2Block

11.2RX lock on both Dim and Fact and requesting exclusive lock (mode 6) on FactRX lock on both Dim and Fact"enq: TX - row lock contention"

12.1RX lock on both Dim and Fact and requesting exclusive lock (mode 6) on Fact RX lock on both Dim and Fact"enq: TX - row lock contention"

19.3RX lock on both Dim and Fact and requesting exclusive lock (mode 6) on FactRX lock on both Dim and Fact"enq: TX - row lock contention"

Szenario 6: Same again, but with index on Fact(Dim_ID)

CREATE INDEX Protect_FK ON Fact(Dim_ID);

Now with index delete on Fact is possible without blocking lock.

Szenario 7: Update on Fact + Delete an not referenced record on Dim without Index on Fact(Dim_ID)

Step 1 with session 1

INSERT INTO Dim VALUES (1, 'First');
INSERT INTO Dim VALUES (2, 'Second');
INSERT INTO Fact VALUES (1, 'First', 1);
INSERT INTO Fact VALUES (2, 'Second', 1);
COMMIT;
UPDATE Fact SET Dim_ID=1, Name='More' WHERE ID=2;

Step 2 with session 2

DELETE FROM Dim WHERE ID=2;

DBSession 1Session 2Block

11.2RX lock on both Dim and FactRX lock on Dim and requesting share lock (mode 4) on Fact"enq: TM - contention"

12.1RX lock on both Dim and FactRX lock on Dim and requesting share lock (mode 4) on Fact"enq: TM - contention"

19.3RX lock on both Dim and FactRX lock on Dim and requesting share lock (mode 4) on Fact"enq: TM - contention"

Deletes on Dim are blocked because share lock (mode 4) on Fact is blocked by row exclusive lock of session 1.

Step 3 with session 3

UPDATE Fact SET Dim_ID=1, Name='More' WHERE ID=1;

Session 3 is requesting a RX lock on Fact which is blocked by the requested S lock from session 2.

Szenario 8: Same again, but with index on Fact(Dim_ID)

CREATE INDEX Protect_FK ON Fact(Dim_ID);

Now with index on Fact(Dim_ID) delete on Dim with pending update on Fact is possible.

Conclusion

1.

- There are real world systems following the above dogma with more than 50% of storage footprint caused only by useless indexes to protect all referential integrity constraints.

- By carefully rating the necessity of this indexes you have a large lever to reduce storage footprint and effort for index maintenance.

2.

- Primary key columns should be treated as technical row identities and their values should never be changed.

- This enables you to skip this primary key columns in the set-clause of update-statements.

- This way updates on referenced tables are now possible without influence on locking behavior via foreign key constraints even if foreign key column is not indexed.

- Verify that your ORM-frameworks supports skipping primary key columns from update.

3.

- Deletes on referenced tables need a short share lock (mode 4) on referencing table if FK is not protected by index.
 
This share lock is required only at the start of the update statement and is already released during the following full table scan on the referencing table.

- Updates on referenced tables including the PK-column in set clause have a similar behaviour like deletes.

- Updates without PK-columns in set-clause and inserts on referenced tables are not blocked by DML on referencing table even if foreign key is not protected by index.

Summary:

- If you don’t have frequent DML on referenced table there is usually no need to protect a foreign key constraint with an index

p.s.:

You can scan your database for possibly unnecessary indexes with Panorama’s selects at menu “Spec. additions / Dragnet investigation” point 1.2.

If you don’t agree with this perspective on indexing foreign keys please share your arguments.
