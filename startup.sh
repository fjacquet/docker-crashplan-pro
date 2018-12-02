#!/bin/bash
export DISPLAY=:1
export SWT_GTK3=0

cd /root/noVNC || exit

ln -s vnc_auto.html index.html
Xvfb :1 -screen 0 1024x768x16 &
sleep 5
openbox-session &
x11vnc -display :1 -nopw -listen localhost -xkb -ncache 10 -ncache_cr -forever &
./utils/launch.sh --vnc localhost:5900 &

export CRASHPLAN_DIR=/usr/local/crashplan
export LD_LIBRARY_PATH=${CRASHPLAN_DIR}
export FULL_CP=${CRASHPLAN_DIR}/lib/com.backup42.desktop.jar:${CRASHPLAN_DIR}/lang:${CRASHPLAN_DIR}
export APP_NAME="CrashPlan for Small Business" 
export KEEP_APP_RUNNING=1 
export JAVACOMMON=${CRASHPLAN_DIR}/jre/bin/java
export PATH=${CRASHPLAN_DIR}/electron/:${CRASHPLAN_DIR}/jre/bin/:$PATH
export HOME=/config
if [ ! -d ${HOME}/conf ]; then
    chmod 0755 /crashplan-pro.sh && \
    /crashplan-pro.sh
fi
source ${CRASHPLAN_DIR}/bin/run.conf 
cd ${CRASHPLAN_DIR} && \
exec "${JAVACOMMON}" "${SRV_JAVA_OPTS}"  -classpath  "${FULL_CP}"  com.backup42.service.CPService &
cd /config || exit
exec" ${CRASHPLAN_DIR}/electron/crashplan" >> /config/log/ui_output.log 2>> /config/log/ui_error.log & 
/bin/bash 