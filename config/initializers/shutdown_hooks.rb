# Ensure Puma/the JVM can exit promptly even if a background thread is currently blocked in an active
# JDBC call (e.g. a long-running sampler query). See PanoramaConnection.abort_all_connections_for_shutdown.
at_exit { PanoramaConnection.abort_all_connections_for_shutdown } unless Rails.env.test?
