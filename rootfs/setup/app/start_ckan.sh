#!/bin/bash
# Run the prerun script to init CKAN and create the default admin user
python prerun.py

# Set the common gunicorn options
GUNICORN_OPTS="--log-file=- -k gevent -w 2 -b 0.0.0.0:5000 --paste production.ini"

# Check whether http basic auth password protection is enabled and enable basicauth routing on gunicorn respecfully
if [ $? -eq 0 ]
then
  if [ "$PASSWORD_PROTECT" = true ]
  then
    if [ "$HTPASSWD_USER" ] || [ "$HTPASSWD_PASSWORD" ]
    then
      # Generate htpasswd file for basicauth
      htpasswd -d -b -c /srv/app/.htpasswd $HTPASSWD_USER $HTPASSWD_PASSWORD
      # Start gunicorn with basicauth
      gunicorn $GUNICORN_OPTS
    else
      echo "Missing HTPASSWD_USER or HTPASSWD_PASSWORD environment variables. Exiting..."
      exit 1
    fi
  else
    # Start gunicorn
    gunicorn $GUNICORN_OPTS
  fi
else
  echo "[prerun] failed...not starting CKAN."
fi
