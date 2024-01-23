# Be sure to restart your server when you modify this file.

Rails.application.config.session_store :cookie_store, key: '_panorama_session', expire_after: Panorama::MAX_SESSION_LIFETIME_AFTER_LAST_REQUEST
