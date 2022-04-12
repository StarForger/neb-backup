#!/usr/bin/env bash

export $(grep -v '^#' .env | xargs -d '\n')

aws --profile ${AWS_PROFILE:-"default"} ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com