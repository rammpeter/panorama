# Using Panorama for autonomous database in Oracle cloud

Datum: 2019-09-20
URL: https://rammpeter.blogspot.com/2019/09/using-panorama-for-autonomous-database.html
Labels: Panorama How-To

---

Panorama is now able to connect to autonomous databases in the Oracle cloud.

At start of Panorama you must ensure that environment variable TNS_ADMIN targets to a directory containing:

- the tnsnames.ora provided by Oracle cloud

- the unzipped files from the Oracle wallet provided by Oracle cloud:

- Oracle wallet files (ewallet.sso, ewallet.p12) 

- Java KeyStore (JKS) files (truststore.jks, keystore.jks).

- Connection properties required to use Oracle Wallets or Java KeyStore (ojdbc.properties)
