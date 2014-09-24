# Be sure to restart your server when you modify this file.

# Your secret key is used for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!

# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.
# You can use `rake secret` to generate a secure secret key.

# Make sure your secret_key_base is kept private
# if you're sharing your code publicly.
# Panorama::Application.config.secret_key_base = 'f44aca1e584c61bcae117e3892e650aaf3b188c0193b7fc8445fa010f3034a2a68cd97ecb5408979e54ec1e75639d6848786ff5d5473e20548927a830902f97e'


Panorama::Application.config.secret_key_base = "f4a010f3034a2a68cd97ecb5408#{ENV['SECRET_KEY_BASE']}979e39d6848786ff5d5473e20548927a830902f97e"
