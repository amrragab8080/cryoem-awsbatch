FROM nvidia/cuda:9.0-devel-ubuntu16.04

LABEL maintainer="amrraga@amazon.com"

ENV USER root

# -------------------------------------------------------------------------------------
# install needed software -
# openssh
# mpi
# awscli
# supervisor
# -------------------------------------------------------------------------------------

RUN apt update
RUN DEBIAN_FRONTEND=noninteractive apt install -y iproute2 openssh-server openssh-client python python-pip build-essential gfortran wget curl libfftw3-dev git
RUN pip install supervisor awscli

RUN mkdir -p /var/run/sshd
ENV DEBIAN_FRONTEND noninteractive

ENV NOTVISIBLE "in users profile"

#####################################################
## CMAKE
RUN wget -O /tmp/cmake.tar.gz https://github.com/Kitware/CMake/archive/v3.9.6.tar.gz
RUN cd /tmp && tar -xvf /tmp/cmake.tar.gz
RUN cd /tmp/CMake* && ./configure && make -j $(nproc) && make install

#####################################################
## SSH SETUP

RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
RUN echo "export VISIBLE=now" >> /etc/profile

RUN echo "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
ENV SSHDIR /root/.ssh
RUN mkdir -p ${SSHDIR}
RUN touch ${SSHDIR}/sshd_config
RUN ssh-keygen -t rsa -f ${SSHDIR}/ssh_host_rsa_key -N ''
RUN cp ${SSHDIR}/ssh_host_rsa_key.pub ${SSHDIR}/authorized_keys
RUN cp ${SSHDIR}/ssh_host_rsa_key ${SSHDIR}/id_rsa
RUN echo "    IdentityFile ${SSHDIR}/id_rsa" >> /etc/ssh/ssh_config
RUN echo "Host *" >> /etc/ssh/ssh_config && echo "    StrictHostKeyChecking no" >> /etc/ssh/ssh_config
RUN chmod -R 600 ${SSHDIR}/* && \
    chown -R ${USER}:${USER} ${SSHDIR}/
# check if ssh agent is running or not, if not, run
RUN eval `ssh-agent -s` && ssh-add ${SSHDIR}/id_rsa

##################################################
## S3 OPTIMIZATION

RUN aws configure set default.s3.max_concurrent_requests 30
RUN aws configure set default.s3.max_queue_size 10000
RUN aws configure set default.s3.multipart_threshold 64MB
RUN aws configure set default.s3.multipart_chunksize 16MB
RUN aws configure set default.s3.max_bandwidth 4096MB/s
RUN aws configure set default.s3.addressing_style path

##################################################
## CUDA MPI

RUN wget -O /tmp/openmpi.tar.gz https://download.open-mpi.org/release/open-mpi/v4.0/openmpi-4.0.0.tar.gz && \
    tar -xvf /tmp/openmpi.tar.gz -C /tmp
RUN cd /tmp/openmpi* && ./configure --prefix=/opt/openmpi --with-cuda --enable-mpirun-prefix-by-default && \
    make -j $(nproc) && make install
RUN echo "export PATH=/opt/openmpi/bin:$PATH" >> /etc/bash.bashrc
RUN echo "export LD_LIBRARY_PATH=/opt/openmpi/lib:/usr/local/cuda/include:/usr/local/cuda/lib64:$LD_LIBRARY_PATH" >> /etc/bash.bashrc

###################################################
## RELION INSTALL

ENV PATH /opt/openmpi/bin:$PATH
ENV LD_LIBRARY_PATH /opt/openmpi/lib:/usr/local/cuda/include:/usr/local/cuda/lib64:$LD_LIBRARY_PATH

RUN git clone https://github.com/3dem/relion.git /root/relion
RUN cd /root/relion && mkdir build
RUN cd /root/relion/build && \
	cmake -DGUI=OFF -DCUDA=ON -DCudaTexture=ON -DCMAKE_INSTALL_PREFIX=/opt/relion -DCUDA_ARCH='35 -gencode=arch=compute_50,code=sm_50 -gencode=arch=compute_70,code=sm_70' .. && make -j $(nproc) && make install

####################################################
## CRYO WRAPPER

RUN mkdir -p /app
ADD cryo_wrapper.sh /app/cryo_wrapper.sh
RUN chmod +x /app/cryo_wrapper.sh


