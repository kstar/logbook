#!/bin/bash
#
# Turn the current observation plan into a logbook

qdbus org.kde.kstars /KStars org.kde.kstars.getObservingSessionPlanObjectNames | grep -v '^$'> obsplan.txt

./generate-logbook.sh obsplan.cfg
