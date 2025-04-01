#!/bin/bash
# docker build --no-cache

ME=davidlinhardt
GEAR=prfresult
VERSION=1.0
docker build $1 --platform linux/x86_64 --tag $ME/$GEAR:$VERSION .

