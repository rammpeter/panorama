Panorama for Oracle-DB
========

Web-tool for analyzing performance issues of Oracle databases.<br/>
Provides easy access to several current and historic state information of Oracle DBs.<br>

![Dashboard](doc/dashboard.jpg)

For more details please have a look at:
- a more comprehensive documentation: https://rammpeter.github.io/panorama.html
- the blog about Oracle performance topics: https://rammpeter.blogspot.com

## Installation / Usage
there are two ways to run Panorama:
1. as Java program (jar file)
2. as Docker container

### 1. Use Panorama as Java program (jar file)
- Ensure you have Java installed (version 21 or higher)
- Download the latest release of Panorama.jar from https://github.com/rammpeter/panorama/releases/latest
- Start the application by executing the jar file in a terminal:
  ```
  > java -jar panorama.jar
  ```
- Open the application in your browser: http://localhost:8080
- Login with an Oracle user of the choosen database 

### 2. Use Panorama as container
- Ensure you have Docker or Podman installed
- Run the application by executing the following command in a terminal:
  ```
  > docker run -p 8080:8080 docker.io/rammpeter/panorama
  ```
- Open the application in your browser: http://localhost:8080
- Login with an Oracle user of the choosen database

## License
This application is available free of charge under the terms of the [GNU General Public License](http://www.gnu.org/licenses/gpl-3.0).
