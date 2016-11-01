#! / bin/bash

mnt3_sswang=/mnt/bay3/sswang
lastz_dir=~/software/genome/lastz-distrib-1.02.00/bin/
phastCons_dir=~/software/genome/phast-1.3/bin
multiz_dir=/home/sswang/software/genome/multiz-tba.012109/
UCSC_dir=$mnt3_sswang/software/genome/UCSC
ucsc_tools=$mnt3_sswang/software/genome/ucsc_tools/executables/

export PATH=$PATH:$phastCons_dir:$lastz_dir:$multiz_dir
export PATH=$PATH:$UCSC_dir
export PATH=$PATH:$ucsc_tools


