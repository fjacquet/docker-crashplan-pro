#
# crashplan-pro Dockerfile
#
# https://github.com/fjacquet/docker-crashplan-pro
#
FROM ubuntu:bionic
# Metadata.
LABEL \
      org.label-schema.name="crashplan-pro" \
      org.label-schema.description="Docker container for CrashPlan PRO" \
      org.label-schema.version="unknown" \
      org.label-schema.vcs-url="https://github.com/fjacquet/crashplan-pro" \
      org.label-schema.schema-version="1.0"
# Define software versions.
ARG CRASHPLANPRO_VERSION=6.7.1
ARG CRASHPLANPRO_TIMESTAMP=1512021600671
ARG CRASHPLANPRO_BUILD=4615
# Define software download URLs.
ARG CRASHPLANPRO_URL=https://web-eam-msp.crashplanpro.com/client/installers/CrashPlanSmb_${CRASHPLANPRO_VERSION}_${CRASHPLANPRO_TIMESTAMP}_${CRASHPLANPRO_BUILD}_Linux.tgz
# Define container build variables.
ARG TARGETDIR=/usr/local/crashplan
# Define mountable directories.
VOLUME ["/config"]
VOLUME ["/volume1"]
EXPOSE 6080

ENV DEBIAN_FRONTEND noninteractive \
    APP_NAME="CrashPlan for Small Business" \
    KEEP_APP_RUNNING=1 \
    CRASHPLAN_DIR=${TARGETDIR} \
    JAVACOMMON="${TARGETDIR}/jre/bin/java"



RUN apt-get update -y && \
    apt-get install -y git x11vnc python python-numpy unzip xvfb openbox cpio curl sed libgconf2-4 net-tools openjdk-8-jdk  && \
    cd /root && git clone https://github.com/kanaka/noVNC.git && \
    cd noVNC/utils && git clone https://github.com/kanaka/websockify websockify && \
    cd /root && \
    apt-get autoclean && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

# Define working directory.
WORKDIR /tmp

# Install CrashPlan.
RUN \
    echo "Installing CrashPlanSmb_${CRASHPLANPRO_VERSION}..." && \
    curl -# -L ${CRASHPLANPRO_URL} | tar -xz && \
    mkdir -p ${TARGETDIR} && \
    cd ${TARGETDIR}   && \
    # Extract CrashPlan.
    cat $(ls /tmp/crashplan-install/*.cpi) | gzip -d -c - | cpio -i --no-preserve-owner && \
    mv "${TARGETDIR}"/*.asar "${TARGETDIR}/electron/resources" && \
    chmod 755 "${TARGETDIR}/electron/crashplan" 
# Keep a copy of the default config.
RUN \    
    mkdir -p /defaults && \
    mv ${TARGETDIR}/conf /etc/conf && \
    cp /tmp/crashplan-install/scripts/run.conf /etc/ && \
    # Make sure the UI connects by default to the engine using the loopback IP address (127.0.0.1).
    sed -i '/<orgType>BUSINESS<\/orgType>/a \\t<serviceUIConfig>\n\t\t<serviceHost>127.0.0.1<\/serviceHost>\n\t<\/serviceUIConfig>' /etc/conf/default.service.xml && \
    # Set manifest directory to default config.  It should not be used, but do
    # like the install script.
    sed -i "s|<backupConfig>|<backupConfig>\n\t\t\t<manifestPath>/usr/local/var/crashplan</manifestPath>|g" /etc/conf/default.service.xml && \
    mkdir -p /usr/local/var/crashplan && \
    # Prevent automatic updates.
    rm -r /usr/local/crashplan/upgrade && \
    touch /usr/local/crashplan/upgrade && chmod 400 /usr/local/crashplan/upgrade && \
    # The configuration directory should be stored outside the container.
    ln -s /config/conf $TARGETDIR/conf && \
    # The run.conf file should be stored outside the container.
    ln -s /config/bin/run.conf $TARGETDIR/bin/run.conf && \
    # The cache directory should be stored outside the container.
    ln -s /config/cache $TARGETDIR/cache && \
    # The log directory should be stored outside the container.
    rm -r $TARGETDIR/log && \
    ln -s /config/log $TARGETDIR/log && \
    # The '/var/lib/crashplan' directory should be stored outside the container.
    ln -s /config/var /var/lib/crashplan && \
    # The '/repository' directory should be stored outside the container.
    # NOTE: The '/repository/metadata' directory changed in 6.7.0 changed to
    #       '/usr/local/crashplan/metadata' in 6.7.1.
    ln -s /config/repository/metadata /usr/local/crashplan/metadata && \
    # Download and install the JRE.
    echo "Installing JRE..." && \
    . /tmp/crashplan-install/install.defaults && \
    curl -# -L ${JRE_X64_DOWNLOAD_URL} | tar -xz -C ${TARGETDIR} && \
    chown -R root:root ${TARGETDIR}/jre && \
    # Cleanup 
    rm -rf /tmp/*

# Misc adjustments.
RUN  \
    # Remove the 'nobody' user.  This is to avoid issue when the container is
    # running under ID 65534.
    sed -i '/^nobody:/d' /etc/passwd && \
    sed -i '/^nobody:/d' /etc/group && \
    sed -i '/^nobody:/d' /etc/shadow && \
    # Clear stuff from /etc/fstab to avoid showing irrelevant devices in the open
    # file dialog window.
    echo > /etc/fstab && \
    # CrashPlan requires the machine-id to be the same to avoid re-login.
    rm /etc/machine-id && \
    ln -s /config/machine-id /etc/machine-id && \
    # Save the current CrashPlan version.
    echo "${CRASHPLANPRO_VERSION}" > /etc/cp_version


COPY crashplan-pro.sh /crashplan-pro.sh
COPY startup.sh /startup.sh
RUN chmod 0755 /startup.sh 
    
CMD /startup.sh && /bin/bash