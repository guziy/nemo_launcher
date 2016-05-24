#!/bin/bash

#$ -cwd
#$ -e error
#$ -o log
#$ -M guziy.sasha@gmail.com
#$ -q q_skynet2
#$ -pe pure_mpi 20
#$ -S /bin/bash

echo "Current directory: $(pwd)"
. ~/.profile_nemo
./run.sh 20 >& run.log 
