#
# Example build:
#   docker build --no-cache --tag davidlinhardt/prfpresult `pwd`
#

FROM ubuntu:focal

# Make directory for flywheel spec (v0)
ENV FLYWHEEL /flywheel/v0
RUN mkdir -p ${FLYWHEEL}
WORKDIR ${FLYWHEEL}


RUN apt update --fix-missing \
 && apt install -y wget \
                   xvfb \
                   libgl1 \
                   gcc


############################
# Install mamba
ENV CONDA_DIR /opt/conda
ENV MAMBA_ROOT_PREFIX="/opt/conda"
RUN wget --quiet https://github.com/conda-forge/miniforge/releases/latest/download/Mambaforge-$(uname)-$(uname -m).sh -O ~/mamba.sh && \
      /bin/bash ~/mamba.sh -b -p /opt/conda

# Put conda in path so we can use conda activate
ENV PATH=$CONDA_DIR/bin:$PATH

RUN mamba update -n base --all

# install conda env
COPY conda_config/scientific.yml .
RUN mamba env create -f scientific.yml

RUN grep -Ril np.float\: /opt/conda/envs/scientific/lib/python3.10/site-packages/surfer | xargs -r sed -i 's/np\.float:/np.float32:/g'
RUN grep -Ril np.float\) /opt/conda/envs/scientific/lib/python3.10/site-packages/surfer | xargs -r sed -i 's/np\.float)/np.float32)/g'
RUN grep -Ril np.int\: /opt/conda/envs/scientific/lib/python3.10/site-packages/surfer | xargs -r sed -i 's/np\.int:/np.int32:/g'
RUN grep -Ril np.int\) /opt/conda/envs/scientific/lib/python3.10/site-packages/surfer | xargs -r sed -i 's/np\.int)/np.int32)/g'

RUN apt update && apt install -y jq

RUN sed -i 's/from collections import Sequence/from collections.abc import Sequence/g' /opt/conda/envs/scientific/lib/python3.10/site-packages/surfer/utils.py

# Make directory for flywheel spec (v0)
ENV FLYWHEEL /flywheel/v0
RUN mkdir -p ${FLYWHEEL}

# copy the PRFclass
ADD PRFclass /PRFclass

# Copy and configure run script and metadata code
COPY bin/run.sh \
	bin/run.py \
      ${FLYWHEEL}/

# Handle file properties for execution
RUN chmod -R +x \
      ${FLYWHEEL}/run.sh \
      ${FLYWHEEL}/run.py \
      /PRFclass

WORKDIR ${FLYWHEEL}
# Run the run.sh script on entry.
ENTRYPOINT ["/flywheel/v0/run.sh"]

RUN rm /bin/sh && ln -s /bin/bash /bin/sh