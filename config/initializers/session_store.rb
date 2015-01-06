# Be sure to restart your server when you modify this file.
Rails.application.config.session_store :cookie_store, key: '_Panorama_session'

# Session in memory speichern mit Lifetime = html-Session
# Funktioniert ab Rails 4.2.0 nicht mehr mit Jetty, daher zurück auf cookie_store
# Panorama::Application.config.session_store :cache_store


# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rails generate session_migration")
# Panorama::Application.config.session_store :active_record_store


