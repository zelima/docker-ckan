#!/bin/bash
python prerun.py
if [ $? -eq 0 ]
then
  if [ "$PASSWORD_PROTECT" = true ]
  then
    if [ "$HTPASSWD_USER" ] || [ "$HTPASSWD_PASSWORD" ]
    then
      cp -a /srv/app/nginx.conf /etc/nginx/nginx.conf
      htpasswd -b -c /srv/app/.htpasswd $HTPASSWD_USER $HTPASSWD_PASSWORD
      nginx
      gunicorn --log-file=- --log-level=DEBUG -k gevent -w 4 -b 127.0.0.1:4000 --timeout 90 --keep-alive 75 --capture-output --enable-stdio-inheritance --paste production.ini
    else
      echo "Missing HTPASSWD_USER or HTPASSWD_PASSWORD environment variables. Exiting..."
      exit 1
    fi
  else
    gunicorn --log-file=- --log-level=DEBUG -k gevent -w 4 -b 0.0.0.0:5000 --timeout 90 --keep-alive 75 --capture-output --enable-stdio-inheritance --paste production.ini
  fi
else
  echo "[prerun] failed...not starting CKAN."
fi
