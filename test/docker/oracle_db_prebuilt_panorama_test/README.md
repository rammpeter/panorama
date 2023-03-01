# Build Docker image with DB prepared for Panorama tests

## Precondition
Base image with installed DB instance according to https://github.com/OttoGroupSolutionProvider/oracle-db_docker

## Steps
* Run build_panorama_db_image.sh with parameters base image and target image<br/>
Example:

      ./build_panorama_db_image.sh \
        registry.site.com/oracle/database_prebuild:12.1.0.2-ee \
        registry.site.com/oracle/database_prebuild_panorama_test:12.1.0.2-ee


