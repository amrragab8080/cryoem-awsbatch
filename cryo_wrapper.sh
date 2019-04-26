#!/bin/bash -xe
###################################
env
###################################
echo "DOWNLOADING CRYOEM INPUT FILES..."
mkdir -p $JOBDIR/$AWS_BATCH_JOB_ID
aws s3 cp $S3_INPUT $JOBDIR/$AWS_BATCH_JOB_ID
tar -xvf $JOBDIR/$AWS_BATCH_JOB_ID/*.tar.gz -C $JOBDIR/$AWS_BATCH_JOB_ID
echo "STARTING UP MAIN CRYOEM WORKFLOW..." 
cd $JOBDIR/$AWS_BATCH_JOB_ID
if [[ -z "${AWS_BATCH_JOB_ARRAY_INDEX}" ]]; then
   :
else
   LINE=$((AWS_BATCH_JOB_ARRAY_INDEX + 1))
   CRYO_SYSTEM=$(sed -n ${LINE}p $JOBDIR/$AWS_BATCH_JOB_ID/cryoem.txt)
   export CRYO_SYSTEM
fi

$@

echo "JOB FINISHED, COMPRESSING OUTPUT..."
tar -czvf $JOBDIR/batch_output_$AWS_BATCH_JOB_ID.tar.gz $JOBDIR/$AWS_BATCH_JOB_ID/*
aws s3 cp $JOBDIR/batch_output_$AWS_BATCH_JOB_ID.tar.gz $S3_OUTPUT
echo "CLEANUP..."
rm -rf $JOBDIR/$AWS_BATCH_JOB_ID
echo "BATCH JOB DONE"
