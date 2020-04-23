#! /bin/bash

LOG=/tmp/update.log

heartbeat() {
    FORM='1FAIpQLSemeGH8Ko9eR_Ri8UFyq0PtlC4WThPvrEX3AME0hp7h6JKJrg'
    URL=https://docs.google.com/forms/d/e/$FORM/formResponse
    # Post to Google Form. Only show status code.
    curl $URL \
         -s -o /dev/null -w "%{http_code}" \
         -d ifq \
         -d entry.1405426464="$HOSTNAME" \
         -d submit=Submit
}

once_per_day() {
    heartbeat
}

run() {
    echo 'Update script.'
    if [ ! -r $LOG ] ; then
        once_per_day
    fi
    date >> $LOG
}

run
