#!/bin/bash
# docker build --no-cache

ME=davidlinhardt
GEAR=prfresult
VERSION=0.1.3
docker build $1 --platform linux/x86_64 --tag $ME/$GEAR:$VERSION .

