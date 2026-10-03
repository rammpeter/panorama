# Oracle-DB: Requirements for a multi-column index for protecting foreign key constraints

Datum: 2023-03-27
URL: https://rammpeter.blogspot.com/2023/03/oracle-db-requirements-for-multi-column.html
Labels: Index, Oracle

---

If you want avoid blocking locks while using referential integrity constraints in an Oracle-DB, it is suggested to protect a foreign key constraint by an index.
Not always it is useful and necessary to protect a foreign key constraint with an index. But this question was considered separately in this blog post.

The question today is:
What column structure must an index have to be accepted by the Oracle DB as protection for a multi-column foreign key constraint?
To answer this question, several scenarios are tested.

Test setup:

CREATE TABLE Dim(ID1 NUMBER, ID2 NUMBER, ID3 NUMBER, Name VARCHAR2(200));

ALTER TABLE Dim ADD CONSTRAINT Dim_PK PRIMARY KEY (ID1, ID2, ID3);

INSERT INTO Dim VALUES(1,1,1, 'First');

INSERT INTO Dim VALUES(2,2,2, 'Second');

CREATE TABLE Fact(ID1 NUMBER, ID2 NUMBER, ID3 NUMBER, Name VARCHAR2(200));

ALTER TABLE Fact ADD CONSTRAINT Fact_Dim_FK FOREIGN KEY (ID1, ID2, ID3) REFERENCES Dim(ID1, ID2, ID3);

Scenario 1: No index
second session is blocked by the first session-- Session 1
INSERT INTO Fact VALUES (1,1,1, 'Erster');

-- Session 2
UPDATE Dim SET ID3=3 WHERE ID1=2 AND ID2=2 AND ID3=2;

Scenario 2: Incomplete index

second session is blocked by the first session
CREATE INDEX Fact_IX ON Fact(ID1);

-- Session 1
INSERT INTO Fact VALUES (1,1,1, 'Erster');

-- Session 2
UPDATE Dim SET ID3=3 WHERE ID1=2 AND ID2=2 AND ID3=2;

Scenario 3: Complete index

second session is not blocked by the first session
DROP INDEX Fact_IX;
CREATE INDEX Fact_IX ON Fact(ID1, ID2, ID3);

-- Session 1
INSERT INTO Fact VALUES (1,1,1, 'Erster');

-- Session 2
UPDATE Dim SET ID3=3 WHERE ID1=2 AND ID2=2 AND ID3=2;

Scenario 4: Complete index but different order

second session is not blocked by the first session
DROP INDEX Fact_IX;
CREATE INDEX Fact_IX ON Fact(ID3, ID1, ID2);

-- Session 1
INSERT INTO Fact VALUES (1,1,1, 'Erster');

-- Session 2
UPDATE Dim SET ID3=3 WHERE ID1=2 AND ID2=2 AND ID3=2;

Scenario 5: Complete index but additional columns before constraint columns

second session is blocked by the first session
DROP INDEX Fact_IX;
CREATE INDEX Fact_IX ON Fact(Name, ID3, ID1, ID2);

-- Session 1
INSERT INTO Fact VALUES (1,1,1, 'Erster');

-- Session 2
UPDATE Dim SET ID3=3 WHERE ID1=2 AND ID2=2 AND ID3=2;

Scenario 6: Complete index but additional columns between constraint columns 

second session is blocked by the first session
DROP INDEX Fact_IX;
CREATE INDEX Fact_IX ON Fact(ID1, Name, ID3, ID2);

-- Session 1
INSERT INTO Fact VALUES (1,1,1, 'Erster');

-- Session 2
UPDATE Dim SET ID3=3 WHERE ID1=2 AND ID2=2 AND ID3=2;

Scenario 7: Complete index but additional columns after constraint columns

second session is not blocked by the first session
DROP INDEX Fact_IX;
CREATE INDEX Fact_IX ON Fact(ID3, ID1, ID2, Name);

-- Session 1
INSERT INTO Fact VALUES (1,1,1, 'Erster');

-- Session 2
UPDATE Dim SET ID3=3 WHERE ID1=2 AND ID2=2 AND ID3=2;
Conclusion:
To be accepted as protection for a foreign key constraint, an index must contain all columns of the foreign key constraint as the first columns of that index, no matter which order they are in.
