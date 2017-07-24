FROM registry.access.redhat.com/jboss-eap-6/eap64-openshift

USER root


COPY config/standalone-openshift.xml /standalone/configuration/standalone-openshift.xml

COPY deployments/ROOT.war /deployments/ROOT.war

## java trust store
ENV JAVA_CACERTS /etc/pki/java/cacerts
ENV CERTS /etc/ssl/certs/
COPY config/certs/${spring_profiles_active} ${CERTS}

COPY config/dt-agent /tmp/src/dt-agent
RUN echo -e Y\\nN\\n/opt/dynatrace/6.3\\nY | ${JAVA_HOME}/bin/java -jar /tmp/src/dt-agent/dynatrace-agent-6.3.0.1305-unix.jar

COPY config/splunk /opt/splunk/
RUN chmod -R 777 /opt/splunk
RUN chmod a+x /opt/splunk/entrypoint.sh



ENTRYPOINT /opt/splunk/entrypoint.sh

#COPY config/certs/all ${CERTS}

ENV DEV /etc/ssl/certs/dev/
ENV TEST /etc/ssl/certs/test/
ENV STAGE /etc/ssl/certs/stage/

COPY config/certs/dev ${DEV}
COPY config/certs/test ${TEST}
COPY config/certs/stage ${STAGE}

#RUN ${JAVA_HOME}/bin/keytool -v -noprompt -importkeystore -srckeystore ${CERTS}cacerts -destkeystore ${JAVA_CACERTS} -srcstoretype JKS -deststoretype JKS  -deststorepass changeit -srcstorepass changeit

USER 1001