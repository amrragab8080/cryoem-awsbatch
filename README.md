## Executing CryoEM Workflow on AWS Batch

Using a built CryoEM docker image build the AWS Batch compute and example job definitions to stand up the distributed workflow 

## License Summary

This sample code is made available under a MIT license. See the LICENSE file.

## Requirements

You will need an AWS Account with IAM permissions to S3FullAccess. As well as the ability to execute CloudFormation scripts. The cloudformation script will provision an . Permissions to create the network topology will be needed.

<p align="center">
  <img src="/imgs/arch.png?raw=true" alt="CryoEM Workflow Overview" width="800" height="450"/>
</p>

## Instructions

1) Clone the github into a workspace and build the Relion3 docker image. Build platform requires installation of [nvidia-docker2](https://github.com/NVIDIA/nvidia-docker).
```
git clone https://github.com/amrragab8080/cryoem-awsbatch.git
cd cryoem-awsbatch
docker build -t nvidia/relion3 .
```
Please note that the relion3 Dockerfile will git clone the Relion3 [git](https://github.com/3dem/relion.git)

2) Once built you can commit this docker image to your AWS Elastic Container Registry (ECR) using [these instructions](https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html).

Note the fully qualified docker registry URI as you will need this for the cloudformation step.

3) In AWS Cloudformation upload the ```cloudformation/cryoem-cf.yaml```into S3 and source that location in the Cloudformation panel.

4) Fill out the relevant fields for standing up the environment.
<p align="center">
  <img src="/imgs/cfn.png?raw=true" alt="CloudFormation"/>
</p>

5) Once you execute the cloudformation Stack a new AWS jobdefinition, queue, and compute enviroment will be stood up.
```
IAM Role for AWSBatchServiceRole - Used for AWS Batch to call additional services on your behalf
CryoEMECSInstanceRole - Used on the ECS Instance level to access resources on the account, in this example S3
CryoEM Batch Compute Enviroment - Used to create a the compute enviroment definition, here we are using the entire p2, p3 families as included instances types as well as the p3dn.24xl
CryoEM Job Queue - Queue priority to submit jobs to the above compute enviroment
CryoEM Job Definition - Basic job definition template which defines the job submittion parameters
```
6) The jobdefinition is a generic template, but does require some modification at job runtime to complete the example. The startup command here:
```/app/cryo_wrapper.sh mpirun --allow-run-as-root -np Ref::mpithreads /opt/relion/bin/relion_refine_mpi```
Needs to have appened the flags for the various workloads, we running the refine step across multiple GPUs. The full command stack for example running classficiation 3D is:
```/app/cryo_wrapper.sh mpirun --allow-run-as-root -np Ref::mpithreads /opt/relion/bin/relion_refine_mpi --i Particles/shiny_2sets.star --ref emd_2660.map:mrc --firstiter_cc --ini_high 60 --ctf --ctf_corrected_ref --iter 25 --tau2_fudge 4 --particle_diameter 360 --K 6 --flatten_solvent --zero_mask --oversampling 1 --healpix_order 2 --offset_range 5 --offset_step 2 --sym C1 --norm --scale --random_seed 0 --o $PWD --gpu --pool 100 --j 1 --dont_combine_weights_via_disc```
As you can see we are running the Plasmodium ribosome data presented in [Wong et al, eLife 2014](https://elifesciences.org/articles/03080)
