#!/bin/bash

export CF_HOME="/Users/pivotal/workspace/envs/panda"
export UAAC_HOME="${CF_HOME}"

cf "$@"
