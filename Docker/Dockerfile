FROM mcr.microsoft.com/powershell:lts-arm32v7-ubuntu-18.04

LABEL author="David Barbarin" maintainer="David Barbarin"

ENV TZ='Europe/Amsterdam'
ENV API_KEY=''
ENV LAMETRIC_IP=''
ENV SQL_FOLDER_TOSEARCH=''
ENV RECIPIENT_NAME=''
ENV RECIPIENT_PWD=''
ENV TIME_INTERVAL_READ_MAIL_S=''
ENV TIME_INTERVAL_SEND_ALERT_S=''
ENV START_CHECK_HOUR=0
ENV END_CHECK_HOUR=0

ADD LaMetricAlert.ps1 /usr/local/bin/

ENTRYPOINT ["/usr/bin/pwsh", "-File","/usr/local/bin/LaMetricAlert.ps1"]