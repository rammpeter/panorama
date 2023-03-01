-- Modify instance settings
-- CAUTION: for XE Memory settings MUST be < 2 GB, otherwise no startup nomount is possible
ALTER SYSTEM SET SGA_MAX_SIZE=1500M scope=spfile;
ALTER SYSTEM SET SGA_TARGET=1500M scope=spfile;
SHUTDOWN IMMEDIATE;
STARTUP;