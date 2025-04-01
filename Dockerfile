ARG BASE_IMAGE=ubuntu:noble

#############################
# Download stages
#############################

# Utilities for downloading packages
FROM ${BASE_IMAGE} AS downloader

RUN apt update && \
    apt install -y --no-install-recommends \
                    binutils \
                    bzip2 \
                    ca-certificates \
                    curl \
                    unzip && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Micromamba
FROM downloader AS micromamba
# Install a C compiler to build extensions when needed.
# traits<6.4 wheels are not available for Python 3.11+, but build easily.
RUN apt update && \
    apt install -y --no-install-recommends build-essential && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba

ENV MAMBA_ROOT_PREFIX="/opt/conda"
COPY config_files/scientific.yml /tmp/scientific.yml
WORKDIR /tmp
RUN micromamba create -y -f /tmp/scientific.yml && \
    micromamba clean -y -a

# Put conda in path so we can use conda activate
ENV PATH="/opt/conda/envs/scientific/bin:$PATH" \
      UV_USE_IO_URING=0

RUN grep -Ril np.float\: /opt/conda/envs/scientific/lib/python3.10/site-packages/surfer | xargs -r sed -i 's/np\.float:/np.float32:/g'
RUN grep -Ril np.float\) /opt/conda/envs/scientific/lib/python3.10/site-packages/surfer | xargs -r sed -i 's/np\.float)/np.float32)/g'
RUN grep -Ril np.int\: /opt/conda/envs/scientific/lib/python3.10/site-packages/surfer | xargs -r sed -i 's/np\.int:/np.int32:/g'
RUN grep -Ril np.int\) /opt/conda/envs/scientific/lib/python3.10/site-packages/surfer | xargs -r sed -i 's/np\.int)/np.int32)/g'

RUN sed -i 's/spatialimages/filebasedimages/g' /opt/conda/envs/scientific/lib/python3.10/site-packages/surfer/io.py

RUN apt update && apt install -y jq

RUN sed -i 's/from collections import Sequence/from collections.abc import Sequence/g' /opt/conda/envs/scientific/lib/python3.10/site-packages/surfer/utils.py

#############################
# Main stage
#############################
FROM ${BASE_IMAGE} AS prfresult

# Make directory for flywheel spec (v0)
ENV FLYWHEEL=/flywheel/v0
RUN mkdir -p ${FLYWHEEL}
WORKDIR ${FLYWHEEL}

RUN apt update --fix-missing \
 && apt install -y wget \
                   xvfb \
                   libgl1 \
                   gcc \
                   jq

# Install files from micromamba stage
COPY --from=micromamba /bin/micromamba /bin/micromamba
COPY --from=micromamba /opt/conda/envs/scientific /opt/conda/envs/scientific

ENV MAMBA_ROOT_PREFIX="/opt/conda"
RUN bash -c 'eval "$(micromamba shell hook --shell bash)"' && \
    echo "micromamba activate scientific" >> $HOME/.bashrc
ENV PATH="/opt/conda/envs/scientific/bin:$PATH" \
    CPATH="/opt/conda/envs/scientific/include:$CPATH" \
    LD_LIBRARY_PATH="/opt/conda/envs/scientific/lib:$LD_LIBRARY_PATH"

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