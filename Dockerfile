
#
# This is from the Berkeley Datahub R deployment
#
FROM rocker/geospatial@sha256:7b0e833cd52753be619030f61ba9e085b45eb9bb13678311da4a55632c3c8c79
ENV NB_USER rstudio
#ZENV NB_UID 1000
ENV NB_UID 2001

RUN /usr/bin/perl -pi -e 's/:100:/:1003:/' /etc/group
RUN /usr/bin/perl -pi -e 's/:1000:100:/:2001:1003:/' /etc/passwd

# Set ENV for Conda...
ENV CONDA_DIR /srv/conda

# FIXME: Why do I need to set this here manually?
ENV REPO_DIR /srv/repo

# Set ENV for all programs...
ENV PATH ${CONDA_DIR}/bin:$PATH

# And set ENV for R! It doesn't read from the environment...
RUN echo "PATH=${PATH}" >> /usr/local/lib/R/etc/Renviron

# Add PATH to /etc/profile so it gets picked up by the terminal
RUN echo "PATH=${PATH}" >> /etc/profile
RUN echo "export PATH" >> /etc/profile

# The `rsession` binary that is called by jupyter-rsession-proxy to 
# start R doesn't seem to start without this being explicitly set
ENV LD_LIBRARY_PATH /usr/local/lib/R/lib
ENV HOME /home/${NB_USER}
WORKDIR ${HOME}

# Install packages needed by notebook-as-pdf
# Default fonts seem ok, we just install an emoji font
# Can't use fonts-noto-color-emoji since this is based
# on debian stretch
# tcl/tk needed by vioplot/sm (rocker #316)
# poppler and libglpk for D-Lab CTAWG
# nodejs for installing notebook / jupyterhub from source
# libarchive-dev for https://github.com/berkeley-dsep-infra/datahub/issues/1997

RUN apt-get update && \
    apt-get install --yes \
            libx11-xcb1 \
            libxtst6 \
            libxrandr2 \
            libasound2 \
            libpangocairo-1.0-0 \
            libatk1.0-0 \
            libatk-bridge2.0-0 \
            libgtk-3-0 \
            libnss3 \
            libxss1 \
            libssl1.1 \
            fonts-symbola \
            tcl8.6-dev \
            tk8.6-dev \
            libpoppler-cpp-dev \
            libglpk-dev \
            gdebi-core \
            nodejs npm \
            libarchive-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download and install rstudio manually
# Newer one has bug that doesn't work with jupyter-rsession-proxy
#ENV RSTUDIO_URL https://download2.rstudio.org/rstudio-server-1.1.419-amd64.deb
ENV RSTUDIO_URL https://download2.rstudio.org/server/bionic/amd64/rstudio-server-1.2.5042-amd64.deb

#
# install rstudio
#
RUN curl --silent --location --fail ${RSTUDIO_URL} > /tmp/rstudio.deb && \
    dpkg -i /tmp/rstudio.deb && \
    rm /tmp/rstudio.deb

#
# Download and install shiny server
#
RUN wget --no-verbose https://download3.rstudio.org/ubuntu-14.04/x86_64/shiny-server-1.5.12.933-amd64.deb -O ss.deb && \
    gdebi -n ss.deb && \
    rm -f ss.deb
RUN chown -R rstudio:rstudio /var/lib/shiny-server

#
# install miniforge
#
COPY install-miniforge.bash /tmp/install-miniforge.bash
RUN /tmp/install-miniforge.bash

USER ${NB_USER}

COPY infra-requirements.txt ${REPO_DIR}/infra-requirements.txt
COPY requirements.txt ${REPO_DIR}/requirements.txt
RUN pip install --no-cache-dir -r ${REPO_DIR}/infra-requirements.txt
RUN pip install --no-cache-dir -r ${REPO_DIR}/requirements.txt


# Set up nbpdf dependencies
#ENV PYPPETEER_HOME /srv/conda
#RUN pyppeteer-install
#
#  I could not get the above to work so I installed it using pip
#
RUN pip install pyppeteer

# Install latex packages via tlmgr for texlive
#RUN tlmgr update --self
#RUN tlmgr install collection-latexextra
#
# could not get the above to work so I used the below command
RUN  wget https://mirror.ctan.org/systems/texlive/tlnet/update-tlmgr-latest.sh  \
  && sh update-tlmgr-latest.sh -- --upgrade &&  rm  /home/${NB_USER}/update-tlmgr-latest.sh 

#
# Install IRKernel
#
RUN R --quiet -e "install.packages('IRkernel', quiet = TRUE)" && \
    R --quiet -e "IRkernel::installspec(prefix='${CONDA_DIR}')"

#
# Install some R libraries that aren't in the base image
#
COPY class-libs.R /tmp/class-libs.R

#
# I do not need any of the class stuff so its commented out.
#
##RUN mkdir -p /tmp/extras.d
#
#COPY --chown=rstudio extras.d/example /tmp/extras.d
#RUN Rscript /tmp/extras.d/example
#
#COPY --chown=rstudio extras.d/2019-fall-stat-131a.r /tmp/extras.d/
#RUN Rscript /tmp/extras.d/2019-fall-stat-131a.r
#
#COPY --chown=rstudio extras.d/eep-1118.r /tmp/extras.d
#RUN Rscript /tmp/extras.d/eep-1118.r
#
#COPY --chown=rstudio extras.d/ias-c188.r /tmp/extras.d
#RUN Rscript /tmp/extras.d/ias-c188.r
#
#COPY --chown=rstudio extras.d/ph-142.r /tmp/extras.d
#RUN Rscript /tmp/extras.d/ph-142.r
#
#COPY --chown=rstudio extras.d/ph-w250fg.r /tmp/extras.d
#RUN Rscript /tmp/extras.d/ph-w250fg.r
#
#COPY --chown=rstudio extras.d/stat-131a.r /tmp/extras.d
#RUN Rscript /tmp/extras.d/stat-131a.r
#
#COPY --chown=rstudio extras.d/2020-spring-envecon-c118.r /tmp/extras.d/
#RUN Rscript /tmp/extras.d/2020-spring-envecon-c118.r
#
#COPY --chown=rstudio extras.d/econ-140.r /tmp/extras.d/
#RUN Rscript /tmp/extras.d/econ-140.r
#
#COPY --chown=rstudio extras.d/ph-290.r /tmp/extras.d/
#RUN Rscript /tmp/extras.d/ph-290.r
#
#COPY --chown=rstudio extras.d/dlab-ctawg.r /tmp/extras.d/
#RUN Rscript /tmp/extras.d/dlab-ctawg.r


COPY ipython_config.py ${REPO_DIR}/ipython_config.py
USER root


#
#  STATA
#  Needed for STATA15
#
#
RUN  apt-get -y update && apt-get -y install software-properties-common \
  && add-apt-repository ppa:linuxuprising/libpng12  \
  && apt-get -y install libpng12-0

# Install facets which does not have a pip or conda package at the moment
RUN pip install stata_kernel &&  python -m stata_kernel.install --sys-prefix


# Install Python 3 packages
# conda clean --all -f -y
RUN conda install --quiet --yes \
    'altair=4.1.*' \
    'beautifulsoup4=4.9.*' \
    'bokeh=2.3.*' \
    'bottleneck=1.3.*' \
    'cloudpickle=1.6.*' \
    'conda-forge::blas=*=openblas' \
    'cython=0.29.*' 

RUN conda install  --quiet --yes    'dask=2021.4.*' \
    'dill=0.3.*' \
    'h5py=3.2.*' \
    'ipympl=0.7.*'\
    'ipywidgets=7.6.*' \
    'matplotlib-base=3.4.*' \
    'numba=0.53.*' \
    'numexpr=2.7.*' \
    'pandas=1.2.*' \
    'patsy=0.5.*' \
    'protobuf=3.15.*' \
    'pytables=3.6.*' \
    'scikit-image=0.18.*' \
    'scikit-learn=0.24.*' \
    'scipy=1.6.*' \
    'seaborn=0.11.*' \
    'sqlalchemy=1.4.*' \
    'statsmodels=0.12.*' \
    'sympy=1.8.*' \
    'widgetsnbextension=3.5.*'\
    'xlrd=2.0.*' && \
    conda clean --all -f -y

# Install facets which does not have a pip or conda package at the moment
WORKDIR /tmp

RUN git clone https://github.com/PAIR-code/facets.git && \
    jupyter nbextension install facets/facets-dist/ --sys-prefix && \
    rm -rf /tmp/facets


# Import matplotlib the first time to build the font cache.
ENV XDG_CACHE_HOME="/home/${NB_USER}/.cache/"


RUN pip install stata_kernel
RUN python -m stata_kernel.install

USER $NB_UID
ENV PATH=$PATH:/home/${NB_USER}/.local/bin:/bulk/apps/STATA/stata15
ENV STATA_SYSDIR=/bulk/apps/STATA/stata15
ADD stata_kernel.conf  /home/${NB_USER}/.stata_kernel.conf
WORKDIR $HOME
COPY requirements_stata.txt       ${REPO_DIR}/requirements_stata.txt
RUN pip install --no-cache-dir -r ${REPO_DIR}/requirements_stata.txt

USER root
RUN  ln -s /usr/lib/x86_64-linux-gnu/libncurses.so.6     /usr/lib/x86_64-linux-gnu/libncurses.so.5    \
  && ln -s /usr/lib/x86_64-linux-gnu/libncurses.so.6.2   /usr/lib/x86_64-linux-gnu/libncurses.so.5.2  \
  && ln -s /usr/lib/x86_64-linux-gnu/libncursesw.so.6    /usr/lib/x86_64-linux-gnu/libncursesw.so.5   \
  && ln -s /usr/lib/x86_64-linux-gnu/libncursesw.so.6.2  /usr/lib/x86_64-linux-gnu/libncursesw.so.5.2 \
  && ln -s /usr/lib/x86_64-linux-gnu/libtinfo.so.6	 /usr/lib/x86_64-linux-gnu/libtinfo.so.5      \
  && ln -s /usr/lib/x86_64-linux-gnu/libtinfo.so.6.2     /usr/lib/x86_64-linux-gnu/libtinfo.so.5.2
#END STATA15


#
##### SAS kernel BEGIN
#
RUN apt-get install libnuma1
ADD sas /usr/local/bin
RUN pip install sas_kernel ipystata pandas-datareader  sparkmagic
#This is because I installed sas in /bulk, not where the sascfg.py looks for it.
RUN mkdir /opt/sasinside &&  ln -s /bulk/apps/SAS/SAS94/SASHome /opt/sasinside/
RUN conda install -c conda-forge jupyter_contrib_nbextensions
RUN jupyter nbextension install --py widgetsnbextension --sys-prefix
RUN jupyter nbextension enable --py --sys-prefix widgetsnbextension
##### SAS END

#
# Let's start playing with jupyterlab
#

RUN curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -
RUN apt-get install -y nodejs

RUN pip install jupyterlab && jupyter labextension install @jupyterlab/hub-extension
#
# Also added this to the yaml so /lab would be default:
#  extraConfig: |
#    c.NotebookApp.iopub_data_rate_limit = 1000000
#    c.Spawner.cmd=["jupyter-labhub"]
#

USER root

ENV DEBIAN_FRONTEND=noninteractive


##########
# add Video Chat
#
#RUN pip install -U jupyter-videochat  &&  jupyter serverextension enable --sys-prefix --py jupyter_video#chat
#
# End Video Chat
##########


##########
# Add Julia 
#
RUN  apt-get  install -y julia 
COPY julia.jl /tmp/julia.jl
RUN julia /tmp/julia.jl
#
# End Julia
##########

#########
# Add Desktop
#
RUN apt-get -y install gtk2-engines-pixbuf
RUN apt-get -y update \
 && apt-get install -y dbus-x11 \
   firefox \
   xfce4 \
   xfce4-panel \
   xfce4-session \
   xfce4-settings \
   xorg \
   xubuntu-icon-theme


# Remove light-locker to prevent screen lock
RUN wget 'https://sourceforge.net/projects/turbovnc/files/2.2.5/turbovnc_2.2.5_amd64.deb/download' -O turbovnc_2.2.5_amd64.deb && \
   apt-get install -y -q ./turbovnc_2.2.5_amd64.deb && \
   apt-get remove -y -q light-locker && \
   rm ./turbovnc_2.2.5_amd64.deb && \
   ln -s /opt/TurboVNC/bin/* /usr/local/bin/


ADD . /opt/install
#RUN /opt/install/fix-permissions /opt/install

RUN cd /opt/install && \
   conda env update -n base --file environment.yml

#
# Install Matlab integration
#
RUN python -m pip install https://github.com/mathworks/jupyter-matlab-proxy/archive/0.1.0.tar.gz

#
# Fix perms because we used root to install some apps
#
RUN chown -R ${NB_USER}:${NB_USER}  /home/${NB_USER} && chmod 755 /usr/local/bin/sas


#
# Change shell for terminal users
#
RUN chsh -s /usr/bin/bash  rstudio

USER ${NB_USER}
ENV PATH=$PATH:/bulk/apps/STATA/stata15
EXPOSE 8888

#RUN /tmp/fix-permissions /opt/install
COPY postBuild ${REPO_DIR}/postBuild
RUN ${REPO_DIR}/postBuild

