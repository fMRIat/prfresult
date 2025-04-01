#! /bin/bash

# The run script for the prfpreare docker.
################################################################################
set +o verbose   # Command echo off

# If run in debug mode, just exec bash:
if [ "$1" = "DEBUG" ]
    then exec /bin/bash
elif [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "-help" ] || [ "$1" = "help" ]
    then cat /opt/help.txt
    exit 0
fi


# Some variables and functions #################################################

GEAR=prfresult
REPO=dlinhardt
CONTAINER="[${REPO}/$GEAR]"

echo -e "$CONTAINER  Initiated"
set -e


VERBOSE=0
FORCE=0 # 1 for force overwrite

export SUBJECTS_DIR=${OUTPUT_DIR}

# Pass the license when calling docker/singularity, Singularity does not allow to write within the machine and furthermore this way of working goes against Freesurfer's license
# echo "j.gutierrez@bcbl.eu 18112 *CKoktUM2tKG.  FSrcfSWoDhLJE" >> $FREESURFER_HOME/license.txt

# Built to flywheel-v0 spec.
FLYWHEEL_BASE=/flywheel/v0
OUTPUT_DIR="$FLYWHEEL_BASE"/output
INPUT_DIR="$FLYWHEEL_BASE"/input
CONFIG_FILE=$FLYWHEEL_BASE/config.json

# How we print to stdout:
function note {
    [ "$VERBOSE" = 1 ] && echo "$CONTAINER" "   " "$*"
}
function err {
    echo "<ERROR>" "$CONTAINER" "   " "$*" >2
}
function die {
    echo "<ERROR>" "$CONTAINER" "   " "$*" >2
    exit 1
}


# Process Arguments ############################################################

while [ "$#" -gt 0 ]
do   case "$1"
     in "--help"|"-h")
            cat /opt/help.txt
            exit 0
            ;;
        "--force"|"-f")
            FORCE=1
            ;;
        "--verbose"|"-v")
            VERBOSE=1
            ;;
        *)
            if [ -z "$CONFIG_FILE" ]
            then CONFIG_FILE="$1"
            else die "Too many arguments given to docker"
            fi
            ;;
     esac
     shift
done


# start virtual display
#Xvfb :1 -screen 0 1280x1024x24 -auth localhost &
#export DISPLAY=:10

# Main Script ##################################################################

# If no input is given we exit
[ -r "$CONFIG_FILE" ] || {
    note "No config file found. Please provide one!"
    exit 0
}


# run the run.py stricp
export FORCE
export VERBOSE
export FIELDS

xvfb-run --server-args="-screen 0 800x600x24" \
python ${FLYWHEEL_BASE}/run.py "$CONFIG_FILE" || die "Python startup script failed!"
# At this point, the files should have been exported to the appropriate directory,
# which should be linked to /running/out
[ -d $OUTPUT_DIR ] || die "Python startup script failed to make output link!"


# Handle permissions of the outputs
cd /flywheel/v0/output
find "$OUTPUT_DIR/plots" -type d -exec chmod 777 '{}' ';'
find "$OUTPUT_DIR/plots" -type f -exec chmod 666 '{}' ';'

# we don't have any post-processing to do at this point (but later we might)
exit 0