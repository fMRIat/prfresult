#!/bin/sh

export cmd="docker run -ti --rm $4 \
	         -v $2/derivatives:/flywheel/v0/data/derivatives  \
	         -v $2/BIDS:/flywheel/v0/BIDS  \
	         -v $2/$3:/flywheel/v0/config.json \
      		 --platform linux/x86_64 \
	         davidlinhardt/prfresult:$1"
echo "Launching the following command: "
echo $cmd
eval $cmd

