#!/bin/bash
# docker build --no-cache

ME=davidlinhardt
GEAR=prfresult
VERSION=0.0.1
docker build --tag $ME/$GEAR:$VERSION .

