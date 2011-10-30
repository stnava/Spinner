# Defaults for paths we need.
#
# If these programs cannot be found, then other programs may try
# your system path.
#
# Note that these defaults may be changed below as we try to guess where you are.
# Nothing will be changed if the dcm2nii path is correct.
#
# PICSL cluster defaults
DCM2NIIPATH="~/Downloads/mricronmac/"
ANTSPATH="/Users/ntustison/Pkg/ANTS/bin/"
JAVAPATH="/usr/bin"
CAMINOPATH="/Users/ntustison/Pkg/camino/bin/"
IMAGEMAGICKPATH="/opt/local/bin/"
SCCAPATH="/Users/ntustison/Pkg/sccan/bin/"
GDCMPATH="/home/pcook/grosspeople/research/gdcm/bin"

#
# The qsub commmand that will be invoked by pipedream. Include path information and
# options such as -q that may be necessary. Beware that some options, like -o or -S,
# may be set at run time by pipedream programs. Some recommended options:
#
# -q   Restrict submission to a particular queue, useful for limiting the number of
#      concurrent jobs
#
# -p   Set job priority, another way to avoid being a cluster hog
#
# -P   Set project for job, used on clusters where CPU time is controlled by project
#
# -v   Pass environment variable to the job.
#
# Please see the man page for qsub for more detail.
#
PIPEDREAMQSUB="qsub -pe serial 2 -v CAMINO_HEAP_SIZE=1100 "

#
# The vbbatch commmand that will be invoked by pipedream. Include path information and
# options that may be necessary.
#
PIPEDREAMVBBATCH="vbbatch"

export GDCMPATH DCM2NIIPATH ANTSPATH JAVAPATH CAMINOPATH IMAGEMAGICKPATH PIPEDREAMQSUB PIPEDREAMVBBATCH SCCAPATH

# PICSL-specific ImageMagick stuff
export LD_LIBRARY_PATH=/home/pcook/grosspeople/research/imagemagick/lib:$LD_LIBRARY_PATH
export MAGICK_THREAD_LIMIT=1

# Path to XML files needed by GDCM
export GDCM_RESOURCES_PATH=/home/pcook/grosspeople/research/gdcm/Source/InformationObjectDefinition

return 0
