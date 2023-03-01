#!/bin/sh
# Encrypt the file by: gpg -c Wallet_panoramatest.zip

# Decrypt the file
mkdir $HOME/secrets
# --batch to prevent interactive command --yes to assume "yes" for questions
gpg --quiet --batch --yes --decrypt --passphrase="$GPG_KEY_FOR_DB_WALLET_ENCRYPTION" --output Wallet_panoramatest.zip Wallet_panoramatest.zip.gpg
