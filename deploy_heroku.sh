# Deployment nach Heroku

# Schritte zur Einrichtung, Beschreibung unter https://github.com/heroku/heroku-deploy
# > Installation ToolBelt
# > heroku plugins:install https://github.com/heroku/heroku-deploy
# > heroku create
# Letzte URL war: https://boiling-plains-4451.herokuapp.com/

# Direkten Zugriff auf Internet sicherstellen ohne Proxy mit https-Unterbrechung

heroku deploy:war --war Panorama.war --app panorama-ramm
