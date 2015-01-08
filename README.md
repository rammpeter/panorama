Panorama
========

Web-tool for monitoring performance issues of Oracle databases.
Provides easy access to several internal information.<br>
Aims to issues that are inadequately analyzed and presented by other existing tools such as Enterprise Manager.

Here you can find more information about Panorama (including download link for instant runnable bundled web archive file):
http://rammpeter.github.io/

<b>RubyOnRails-Application:</b>
- immmediately startable as Java war-File with built-in Jetty application Server. ( java -jar Panorama.war )
- may be deployed as web application to every JEE or web container (Glassfish, JBoss, Tomcat ...) 

<b>Preconditions for Server machine:</b>
- if using tnsnames.ora it should be in $ORACLE_HOME/network/admin or below $TNS_ADMIN 
- Java runtime environment Java 7 or 8
- Some problems may occur with IBM JVM. If so please use JVM from SUN/Oracle.

This GitHub-project is intended to provide function as Rails engine which can be embedded in other Rails application.
Runnable Rails application with Panorama-gem embedded as engine you find at https://github.com/rammpeter/Panorama

