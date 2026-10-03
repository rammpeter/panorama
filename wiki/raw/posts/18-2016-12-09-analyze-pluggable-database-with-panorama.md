# Analyze pluggable database with Panorama

Datum: 2016-12-09
URL: https://rammpeter.blogspot.com/2016/12/analyze-pluggable-database-with-panorama.html
Labels: Panorama How-To

---

Panorama now supports analysis of pluggable databases (PDB) too.

Visibility of informations in CDB and PDB

There are different informations visible wether you are selecting from DBA_xx-views or CDB_xx-views and your are connected to CDB or PDB

Role / user connectedContainer-DB (CDB / root)Pluggable database (PDB)

Kind of viewsCDB_xxDBA_xxCDB_xxDBA_xx

systemall PDBs including rootall PDBs including rootnothingyour current PDB

user (SELECT ANY DICTIONARY)all PDBs including rootroot CDBnothingyour current PDB

Posted on "Analyze pluggable database with Panorama"
