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
# Install miniconda
ENV CONDA_DIR /opt/conda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
     /bin/bash ~/miniconda.sh -b -p /opt/conda

# Put conda in path so we can use conda activate
ENV PATH=$CONDA_DIR/bin:$PATH

RUN conda update -n base -c defaults conda

# install conda env
COPY conda_config/scientific.yml .
#RUN conda config --add channels conda-forge
#RUN conda config --set channel_priority strict
RUN conda env create -f scientific.yml

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