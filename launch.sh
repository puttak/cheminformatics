#!/bin/bash
# Copyright 2020 NVIDIA Corporation
# SPDX-License-Identifier: Apache-2.0

###############################################################################
#
# This is my $LOCAL_ENV file
#
LOCAL_ENV=.cheminf_local_environment
#
###############################################################################

usage() {
	cat <<EOF

USAGE: launch.sh

launch utility script
----------------------------------------

launch.sh [command]

    valid commands:

	build
	pull
	push
	root
	dbSetup
	dash
	jupyter


Getting Started tl;dr
----------------------------------------

	./launch build
	./launch dash
	navigate browser to http://localhost:5000
For more detailed info on getting started, see README.md


More Information
----------------------------------------

Note: This script looks for a file called $LOCAL_ENV in the
current directory. This file should define the following environment
variables:
	CONT
		container image, prepended with registry. e.g.,
		cheminformatics:latest
	DATA_PATH
		path to data directory. e.g.,
		/scratch/data/cheminformatics
	PROJECT_PATH
		path to repository. e.g.,
		/home/user/projects/cheminformatics
	REGISTRY_ACCESS_TOKEN
		container registry access token. e.g.,
		Ckj53jGK...
	REGISTRY_USER
		container registry username. e.g.,
		astern
	REGISTRY
		container registry URL. e.g.,
		server.com/registry:5005

EOF
	exit
}


###############################################################################
#
# if $LOCAL_ENV file exists, source it to specify my environment
#
###############################################################################

if [ -e ./$LOCAL_ENV ]
then
	echo sourcing environment from ./$LOCAL_ENV
	. ./$LOCAL_ENV
	write_env=0
else
	echo $LOCAL_ENV does not exist. Writing deafults to $LOCAL_ENV
	write_env=1
fi

###############################################################################
#
# alternatively, override variable here.  These should be all that are needed.
#
###############################################################################

CONT=${CONT:=cheminf-clustering}
JUPYTER_PORT=${JUPYTER_PORT:-9000}
PLOTLY_PORT=${PLOTLY_PORT:-5000}
DASK_PORT=${DASK_PORT:-9001}
REGISTRY=${REGISTRY:=NotSpecified}
REGISTRY_USER=${REGISTRY_USER:='$oauthtoken'}
REGISTRY_ACCESS_TOKEN=${REGISTRY_ACCESS_TOKEN:=$(cat ~/NGC.NVIDIA.COM.API)}
PROJECT_PATH=${PROJECT_PATH:=$(pwd)}
DATA_PATH=${DATA_PATH:=/tmp}

###############################################################################
#
# If $LOCAL_ENV was not found, write out a template for user to edit
#
###############################################################################

if [ $write_env -eq 1 ]; then
	echo CONT=${CONT} >> $LOCAL_ENV
	echo JUPYTER_PORT=${JUPYTER_PORT} >> $LOCAL_ENV
	echo PLOTLY_PORT=${PLOTLY_PORT} >> $LOCAL_ENV
	echo DASK_PORT=${DASK_PORT} >> $LOCAL_ENV
	echo REGISTRY=${REGISTRY} >> $LOCAL_ENV
	echo REGISTRY_USER=${REGISTRY_USER} >> $LOCAL_ENV
	echo REGISTRY_ACCESS_TOKEN=${REGISTRY_ACCESS_TOKEN} >> $LOCAL_ENV
	echo PROJECT_PATH=${PROJECT_PATH} >> $LOCAL_ENV
	echo DATA_PATH=${DATA_PATH} >> $LOCAL_ENV
fi

###############################################################################
#
#          shouldn't need to make changes beyond this point
#
###############################################################################

DOCKER_CMD="docker run --network host --gpus all --user $(id -u):$(id -g) -p ${JUPYTER_PORT}:8888 -p ${DASK_PORT}:${DASK_PORT} -p ${PLOTLY_PORT}:5000 -v ${PROJECT_PATH}:/workspace -v ${DATA_PATH}:/data --shm-size=1g --ulimit memlock=-1 --ulimit stack=67108864 -e HOME=/workspace -e TF_CPP_MIN_LOG_LEVEL=3 -w /workspace"

build() {
	docker build -t ${CONT} .
	exit
}

push() {
	docker login ${REGISTRY} -u ${REGISTRY_USER} -p ${REGISTRY_ACCESS_TOKEN}
	docker push ${CONT}
	exit
}


pull() {
	docker login ${REGISTRY} -u ${REGISTRY_USER} -p ${REGISTRY_ACCESS_TOKEN}
	docker pull ${CONT}
	exit
}


bash() {
	${DOCKER_CMD} -it ${CONT} bash
	exit
}


root() {
	${DOCKER_CMD} -it --user root ${CONT} bash
	exit
}


dbSetup() {
	local DATA_DIR=$1

	if [[ ! -e "${DATA_DIR}/chembl_27.db" ]]; then
		echo "Downloading chembl db to ${DATA_DIR}..."
		mkdir -p ${DATA_DIR}
		wget -q --show-progress \
			-O ${DATA_DIR}/chembl_27_sqlite.tar.gz \
			ftp://ftp.ebi.ac.uk/pub/databases/chembl/ChEMBLdb/latest/chembl_27_sqlite.tar.gz
		echo "Unzipping chembl db to ${DATA_DIR}..."
		tar -C ${DATA_DIR} \
			--strip-components=2 \
			-xf ${DATA_DIR}/chembl_27_sqlite.tar.gz chembl_27/chembl_27_sqlite/chembl_27.db
	fi
}


dash() {
	if [[ "$0" == "/opt/nvidia/cheminfomatics/launch.sh" ]]; then
		# Executed within container or a managed env.
		dbSetup '/data/db'
	        python3 startdash.py
	else
		dbSetup "${DATA_PATH}/db"
		# run a container and start dash inside container.
		${DOCKER_CMD} -it ${CONT} python startdash.py
	fi
	exit
}


jupyter() {
	${DOCKER_CMD} -it ${CONT} jupyter-lab --no-browser --port=8888 --ip=0.0.0.0 --notebook-dir=/workspace --NotebookApp.password=\"\" --NotebookApp.token=\"\" --NotebookApp.password_required=False
	exit
}


case $1 in
	build)
		;&
	push)
		;&
	pull)
		;&
	bash)
		;&
	root)
		;&
	dbSetup)
		;&
	dash)
		;&
	jupyter)
		$1
		;;
	*)
		usage
		;;
esac

