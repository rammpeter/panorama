======================================================
Oracle Free Use Terms and Conditions (FUTC) License 
======================================================
https://www.oracle.com/downloads/licenses/oracle-free-license.html
===================================================================

ojdbc11-full.tar.gz - JDBC Thin Driver and Companion JARS
========================================================
This TAR archive (ojdbc11-full.tar.gz) contains the 21.1 release of the Oracle JDBC Thin driver(ojdbc11.jar), the Universal Connection Pool (ucp.jar) and other companion JARs grouped by category. 

(1) ojdbc11.jar (5,132,090 bytes) - 
(SHA1 Checksum: 133b7b0d14b4f4cd4e76661db4727dac937d6856)
Oracle JDBC Driver compatible with JDK11, JDK12, JDK13, JDK14, and JDK15; 
(2) ucp.jar (1,788,363 bytes) - (SHA1 Checksum: a7c9cf31549bff61cb9d7f34a52d74a6c4d819db)
Universal Connection Pool classes for use with JDK8, JDK9, and JDK11 -- for performance, scalability, high availability, sharded and multitenant databases.
(3) rsi.jar (345,036 bytes) - (SHA1 Checksum: 583d93f3e56c647c5b047c1a15debbd6ccb58f34)
Reactive Streams Ingestion (RSI) - A dedicated path for ingesting high volume of data into Oracle database
(4) ojdbc.policy (11,515 bytes) - Sample security policy file for Oracle Database JDBC drivers

======================
Security Related JARs
======================
Java applications require some additional jars to use Oracle Wallets. 
You need to use all the three jars while using Oracle Wallets. 

(5) oraclepki.jar (306,476 bytes) - (SHA1 Checksum: e5d703a7dda3e004ea803147ab1be268eb489dd8)
Additional jar required to access Oracle Wallets from Java
(6) osdt_cert.jar (210,338 bytes) - (SHA1 Checksum: 3d48a246021fd11b091bc57c95b7245b654cf5a9)
Additional jar required to access Oracle Wallets from Java
(7) osdt_core.jar (312,230 bytes) - (SHA1 Checksum: 6f59d819b4c52d696f92a07a2d08f36b388a3c8b)
Additional jar required to access Oracle Wallets from Java

=============================
JARs for NLS and XDK support 
=============================
(8) orai18n.jar (1,664,450 bytes) - (SHA1 Checksum: c36ad4814d128f1259c81fad5d52ad2033e6ad37) 
Classes for NLS support
(9) xdb.jar (265,864 bytes) - (SHA1 Checksum: 6dcf369a16311b51c0408c9b73527bda9de3b4c0)
Classes to support standard JDBC 4.x java.sql.SQLXML interface 
(10) xmlparserv2.jar (1,951,430 bytes) - (SHA1 Checksum: b0611e7d7db4d4f536348bf14a17e2b85e683456)
Classes to support standard JDBC 4.x java.sql.SQLXML interface 
====================================================
JARs for Real Application Clusters(RAC), ADG, or DG 
====================================================
(11) ons.jar (198,469 bytes) - (SHA1 Checksum: 78ebf2e55f7a4b4cb4d4c615a8e61519f1aebbb8)
for use by the pure Java client-side Oracle Notification Services (ONS) daemon
(12) simplefan.jar (32,169 bytes) - (SHA1 Checksum: d4f5325bc099dc3cc4f7aacdb9e14178af124916)
Java APIs for subscribing to RAC events via ONS; simplefan policy and javadoc

=================
USAGE GUIDELINES
=================
Refer to the JDBC Developers Guide (https://docs.oracle.com/en/database/oracle/oracle-database/21/jjdbc/index.html) and Universal Connection Pool Developers Guide (https://docs.oracle.com/en/database/oracle/oracle-database/19/jjucp/index.html)for more details. 
