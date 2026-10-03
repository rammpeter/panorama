# Oracle DB: Evaluate database audit trail with Panorama

Datum: 2023-09-21
URL: https://rammpeter.blogspot.com/2023/09/oracle-db-evaluate-database-audit-trail.html
Labels: 

---

The performance analysis tool Panorama for Oracle now supports both evaluation of standard audit trail as well as evaluation of unified audit trail.

The menu item "DBA General" / "Audit Trail" / "Auditing rules" shows the current configuration of the DB audit trail as well as several auditing rules for standard, fine grained and unified audit trail.

With menu item "DBA General" / "Audit Trail" / "Standard audit trail" you open a dialog for evaluation of standard audit trail including find grained audit trail.
Depending on the choosen value for "Grouping" single audit records are show for the selected period or the result is grouped by time with record counts for the top x OS and DB users, machines and actions.

By clicking at the links in the columns for "Action", "Machine", "User" etc. you can refine the grouped result.
Clicking at the column "Audits total" shows the single audit records for the selected grouping.

The menu item "DBA General" / "Audit Trail" / "Unified audit trail" works similar like previously shown for standard audit trail, but for the unified audit trail.

Several shown columns values in the lists are links.

Clicking a value for "SessionID" will show all recorded audit records for that session.

Clicking at "Client machine" will evaluate the machine name via DNS and lists all currently connected DB sessions for that machine.

Clicking at the object name will show further object details.

For more information about Panorama see: https://rammpeter.github.io/panorama.html
