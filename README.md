Panorama
========

Web-tool for monitoring performance issues of Oracle databases.
Provides easy access to several internal information. 

RubyOnRails-Application:
- immmediately startable as Java war-File with built-in Jetty application Server. ( java -jar Panorama.war )
- may be deployed as web application to every JEE or web container (Glassfish, JBoss, Tomcat ...) 

Preconditions for Server machine:
- if using tnsnames.ora it should be in $ORACLE_HOME/network/admin or below $TNS_ADMIN 
- Java runtime environment Java 6 or 7
- Installed Java Cryptography Extension (JCE).<br>
If JCE is not installed you will get this error:<br>
Illegal key size: possibly you need to install Java Cryptography Extension (JCE) Unlimited Strength Jurisdiction Policy Files for your JRE<br>
JCE is available under http://www.oracle.com/technetwork/java/javase/downloads/index.html
