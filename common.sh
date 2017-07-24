#!/bin/bash

# Common variables for build scripts
OPTUM_DTR_USR=ocdapp_ose
DOCKER_ORG=ocdapp_ose
DOCKER_HUB=docker.optum.com
DOCKER_FLAG_HOST="-H "

OPTUM_OSE_USR=ocdapp_ose
OSE_APP=communication-poc
OSE_SERVER=https://ose-dmz.optum.com
OSE_DEV_PROJECT=testproject
OSE_STAGE_PROJECT=testproject
OSE_TEST_PROJECT=testproject
HOST_NAME=patient-communication1-ocsldev.ose-elr-core.optum.com

SMOKE_STAGE_ENVIRONMENT="https://trustbroker-stg-svcs.optum.com:8443/NGP/"
SMOKE_TEST_ENVIRONMENT="https://trustbroker-stg-svcs.optum.com:8443/NGP/tst"

# This will canonicalize the path
ROOT=$(cd $(dirname "${BASH_SOURCE}")/.. && pwd -P)
cd $ROOT


# Smoke test the test environment
function smoke_test() {

	mvn -U clean package -DtargetUrl=${SMOKE_TEST_ENVIRONMENT} -Dcucumber.options="--tags @smoke --tags @test --tags @patient --tags @Appointments  --tags ~@ignore"
}

# Smoke test the stage environment
function smoke_stage() {

	mvn -U clean package -DtargetUrl=${SMOKE_STAGE_ENVIRONMENT} -Dcucumber.options="--tags @smoke --tags @test --tags @patient --tags @Appointments  --tags ~@ignore"
}

# Pushes docker image to Docker Trusted Registry
# Set DOCKER_HOST="-H jenkins.optum.com:30303" for Jenkins build slave support
function push_dtr() {

	# If not running from Jenkins/Username not defined, prompt for it
	if [ -z "$OPTUM_DTR_USR" ]; then
		read -s -p "Enter Docker Hub Password: " OPTUM_DTR_USR
	fi

	# If not running from Jenkins/Password not defined, prompt for it
	if [ -z "$OPTUM_DTR_PSW" ]; then
		read -s -p "Enter Docker Hub Password: " OPTUM_DTR_PSW
	fi

	# Add flag to Docker Host var
	if [ -n "$DOCKER_HOST" ]; then
		DOCKER_HOST=${DOCKER_FLAG_HOST}${DOCKER_HOST}
	fi

	#Log on to Docker Trusted Registry
	docker $DOCKER_HOST login -u $OPTUM_DTR_USR -p $OPTUM_DTR_PSW docker.optum.com

	# deploy docker image tagged 'latest' to registry
	docker $DOCKER_HOST tag $OPTUM_DTR_USR/$OSE_APP $DOCKER_HUB/$OPTUM_DTR_USR/$OSE_APP:latest
	docker $DOCKER_HOST push $DOCKER_HUB/$OPTUM_DTR_USR/$OSE_APP:latest

	# deploy docker image tagged $BUILD_ID to registry
	#If the Build ID is not set then likely running local
	if [ -n "$BUILD_ID" ]; then
		docker $DOCKER_HOST tag $OPTUM_DTR_USR/$OSE_APP $DOCKER_HUB/$OPTUM_DTR_USR/$OSE_APP:$BUILD_ID
		docker $DOCKER_HOST push $DOCKER_HUB/$OPTUM_DTR_USR/$OSE_APP:$BUILD_ID
	fi
}

# Change to parent directory and build war file
# Assumption: The current pom.xml requires an existing settings.xml (not in repo) for caller
# with arficatory credentials
function build_war() {

	mvn -U -Dci.env= clean package
}

# Change to parent directory and build docker image. Dockerfile must
# live in parent directory due to docker "context"
# Assumption: The current Dockerfile assumes a WAR file has recently been built and resides
# in target/ dir
function build_docker() {

	# Add flag to Docker Host var
	if [ -n "$DOCKER_HOST" ]; then
		DOCKER_HOST=${DOCKER_FLAG_HOST}${DOCKER_HOST}
	fi

	# build docker image
	docker $DOCKER_HOST build --force-rm --no-cache --pull --rm=true -t $OPTUM_DTR_USR/$OSE_APP .
}

# Deploys docker image to dev OSE environment
function deploy_dev() {

	check_ose_credentials

	# login to openshift and switch projects
	oc login --server=$OSE_SERVER -u $OPTUM_OSE_USR -p $OPTUM_OSE_PSW --insecure-skip-tls-verify=true
	oc project $OSE_DEV_PROJECT

	deploy_ose
}

# Deploys docker image to stage OSE environment
function deploy_stage() {

	check_ose_credentials

	# login to openshift and switch projects
	oc login --server=$OSE_SERVER -u $OPTUM_OSE_USR -p $OPTUM_OSE_PSW --insecure-skip-tls-verify=true
	oc project $OSE_STAGE_PROJECT

	deploy_ose
}

# Deploys docker image to test OSE environment
function deploy_test() {

	check_ose_credentials

	# login to openshift and switch projects
	oc login --server=$OSE_SERVER -u $OPTUM_OSE_USR -p $OPTUM_OSE_PSW --insecure-skip-tls-verify=true
	oc project $OSE_TEST_PROJECT

	deploy_ose
}

function check_ose_credentials() {

	if [ -z "$OPTUM_OSE_USR" ]; then
		read -s -p "Enter Openshift Username: " OPTUM_OSE_USR
	fi

	# If not running from Jenkins/Password not defined, prompt for it
	if [ -z "$OPTUM_OSE_PSW" ]; then
		read -s -p "Enter Openshift Password: " OPTUM_OSE_PSW
	fi
}

# Common deploy docker image to Openshift. Deploys image tagged 'latest'
function deploy_ose() {

	# detemine if this app already exists, if not deploy a new one
	BUILD_CONFIG=`oc get dc | grep ${OSE_APP} | tail -1 | awk '{print $1}'`

	if [ "$BUILD_CONFIG" == "$OSE_APP" ]; then

	    # import new docker image into project (kicks off deployment)
	    oc import-image $OSE_APP
	    oc delete rc $(oc get rc | grep $OSE_APP | awk '$2 == 0 {print $1}') || true

	else

	    # create new app automatically
	    oc new-app docker.optum.com/$DOCKER_ORG/$OSE_APP:latest --name=$OSE_APP \
	        -e RELAY_SERVICE_ENDPOINT="http://relay-sma-optumcaresvcdev.ose-elr-core.optum.com" \
	        -e ACUITY_SERVICE_ENDPOINT="https://apitest.sierrahealth.com" \
	        -e ACUITY_SERVICE_AUTH_ENDPOINT="https://apitest.sierrahealth.com/api/oauth2/token" \
	        -e ACUITY_SERVICE_CLIENTID=optumportal \
	        -e ACUITY_SERVICE_CLIENTSECRET=h]Jk2YXQek \
	        -e HCO_SERVICE_CONNECTION=UPG53 \
	        -e HCO_SERVICE_USERID=opidxtest \
	        -e HCO_SERVICE_PASSWORD=optum2017 \
	        -e HCO_SERVICE_CONFIG="classpath:/idx/sma/HCOConfig-nonProd.xml" \
	        -e HCO_SERVICE_INITIAL_CONNS=2 \
	        -e HCO_SERVICE_MAX_CONNS=50 \
	        -e HCO_SERVICE_USERPER_CONN=5 \
	        -e keyStorePassword=changeit \
	        -e trustStorePassword=changeit \
	        -e keyStore="/etc/pki/java/cacerts" \
	        -e JAVA_OPTS_APPEND="-agentpath:/home/jboss/dynatrace-6.3/agent/lib64/libdtagent.so=name=NGP_PT_APPTS_SMA_DEV_JBOSS,server=dtc-nonprod-core-elr.uhc.com:34445" \
	        -e trustStore="/etc/pki/java/cacerts" \
	        -e SMA_PROV_SEARCH_SLOTS_TO=20000 \
	        -e SMA_PROV_SEARCH_TO=8000

	    oc expose service $OSE_APP --hostname=$HOST_NAME
	fi;

}
