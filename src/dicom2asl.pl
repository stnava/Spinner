#!/usr/bin/perl -w
#
# Processes of DICOM ASL data
#

my $usage = qq{
Usage: dicom2dt.sh <input_dir> <protocol_name> <output_dir> <output_file_root> <is_control_first> <smoothing_sigma=2.5> <temporal_interpolation_scheme=bspline>

<input_dir> - input directory. Program looks for scans matching <input_dir>/*<protocol_name>.

<protocol_name> - name of the protocol you want to convert, eg ep2d_pcasl_PHC_1500ms_P2_2.
                  Do not include series numbers if you have repeats- repeat scans matching
                  the protocol name will be processed together (to process a single scan,
                  you should specify its complete name including series number eg
                  0015_ep2d_pcasl_PHC_1500ms_P2_2).

<output_dir> - Output base directory.


<output_file_root> - Root of output, eg subject_TP1_dti_ . Prepended onto output files and directories in
                     <output_dir>. This should be unique enough to avoid any possible conflict within your data set.

<smoothing_sigma> - determines spatial smoothing before subtraction

<interpolation_type> In Aguirre 2002, various interpolation schemes are
      discussed for generating the perfusion images.  Specifically simple (which
      is basically nearest neighbor), surround (or linear interpolation), or
      sinc interpolation are discussed.  The ASL toolbox uses simple subtraction
      but I've included all three previously mentioned in addition to b-spline
      (up to order 5), 5 flavors of sinc interpolation - radius 3 (thanks to
      Paul Yushkevich), and Gaussian interpolation.  These are called by
      specifying:
        Interpolation Type                      Call
        Simple                                  nn
        Surround                                linear
        Windowed Sinc (cosine)                  cosine
        Windowed Sinc (Welch)                   welch
        Windowed Sinc (Blackman)                blackman
        Windowed Sinc (Lanczos)                 lanczos
        Windowed Sinc (Hamming)                 hamming
        BSpline (cubic)                         bspline
        Gaussian                                gaussian

      *******************            References           *********************

      Aguirre GK, Detre JA, Zarahn E, Alsop DC.
      Experimental design and the relative sensitivity of BOLD and perfusion fMRI.
      Neuroimage. 2002 Mar;15(3):488-500.

      Wang Z, Aguirre GK, Rao H, Wang J, FernÃ¡ndez-Seara MA, Childress AR, Detre JA.
      Empirical optimization of ASL data analysis using an ASL data processing toolbox: ASLtbx.
      Magn Reson Imaging. 2008 Feb;26(2):261-9.


Note - DICOM images containing the string "SeriesDescription: MoCoSeries" will be ignored. Only original data
is processed
};

use strict;
use FindBin qw($Bin);
use File::Path;
use File::Spec;

# Set to 1 to delete intermediate files after we're done
# Has no effect if using qsub since files get cleaned up anyhow
my $cleanup = 1;

# Input directory. DICOM files are in $inputDir/.*${sequenceName}.*/
my $inputDir = "";

# Output directory
my $outputDir = "";

# Output file root
my $outputFileRoot = "";

# sigma
my $isControlFirst = 1;

# sigma
my $sigma = 2.5;

# interpolation
my $interpolationType = "bspline";

# eg ep2d_pcasl_PHC_1500ms_P2_2
# We will process all directories matching this
# Or alternate ones if desired (skip scanner moco series)
my $protocolName = "";

# Get the directories containing programs we need
my ( $antsDir, $dcm2niiDir, $imageMagickDir, $caminoDir, $tmpDir ) = @ENV{ 'ANTSPATH', 'DCM2NIIPATH', 'IMAGEMAGICKPATH', 'CAMINOPATH', 'TMPDIR' };

# Process command line args

if(!($#ARGV + 1))
  {
  print "$usage\n";
  exit 0;
  }
else
  {
  ( $inputDir, $protocolName, $outputDir, $outputFileRoot, $isControlFirst, $sigma, $interpolationType ) = @ARGV;
  }

mkpath( $outputDir, {verbose => 0, mode => 0755} ) or die "Cannot create output directory $outputDir\n\t";

# Directory for temporary files that we will optionally clean up when we're done
# Use SGE_TMP_DIR if possible to avoid hammering NFS
if( !( $tmpDir && -d $tmpDir ) )
  {
  $tmpDir = $outputDir . "/${outputFileRoot}aslproc";
  mkpath( $tmpDir, {verbose => 0, mode => 0755} ) or die "Cannot create working directory $tmpDir\n\t";
  print "Placing working files in directory: $tmpDir\n";
  }

# done with args

# ---OUTPUT FILES AND DIRECTORIES---

my $outputASL_Dir = "${outputDir}/${outputFileRoot}asl";
my $outputImageListFile = "${outputASL_Dir}/${outputFileRoot}imagelist.txt";

my $outputBrainMask = "${outputDir}/${outputFileRoot}brainmask.nii";
my $outputAverageASL = "${outputDir}/${outputFileRoot}averageASL.nii";

# Directories containing the scans
my @scanDirs = `find -L $inputDir -maxdepth 1 -type d -name \"*${protocolName}\"`;
chomp @scanDirs;

# sort by series number
@scanDirs = sort( @scanDirs );

if( $imageMagickDir )
  {
  my @noMoco;

  foreach my $scanDir ( @scanDirs )
    {
    # Assuming that first file in data directory is DICOM
    my @dicomFiles = `ls $scanDir`;

   	chomp( @dicomFiles );

   	my $firstDicom = $dicomFiles[0];

   	my $moco = `${imageMagickDir}/identify -verbose ${scanDir}/$firstDicom | grep "SeriesDescription: MoCoSeries"`;

   	if( $moco )
   	  {
	     print "Skipping mocoSeries $scanDir\n";
	     }
	   else
	     {
	     push ( @noMoco, $scanDir );
	     }
    }
  @scanDirs = @noMoco;
  }

# TODO - deal with case where all DICOM data is thrown together in one directory
if( scalar( @scanDirs ) == 0 )
  {
  print "no ASL scans found matching protocol ${protocolName}. Exiting\n";
  exit 1;
  }

print "\nProcessing " . scalar( @scanDirs ) . " scans.\n";

my $numberOfASLTimePoints = 0;

foreach my $scanCounter ( 0 .. $#scanDirs )
  {
  my $singleScan = $scanDirs[$scanCounter];

  my $tmpScanDir = "${tmpDir}/dcmTmp${scanCounter}";

  mkpath( $tmpScanDir, {verbose => 0, mode => 0755} ) or die "Cannot create working directory $tmpScanDir\n\t";

  print "Processing DICOM files for scan ${singleScan}\n";

  my @files = `ls $singleScan`;

  # Copy only dicom files
  foreach my $file (@files)
    {
	   chomp( $file );
	   if( isDicom( "${singleScan}/$file" ) )
	     {
	     `cp ${singleScan}/$file $tmpScanDir`;
	     $numberOfASLTimePoints++;

      if( $file =~ /.gz$/ )
        {
        `gunzip ${tmpScanDir}/$file`;
        }
	     }
    }

  `chmod -R u+w $tmpScanDir`;

  # run dcm2nii - put all scans in single output dir
  my $dcm2niiOutput = `${dcm2niiDir}/dcm2nii -b ${Bin}/../config/dcm2nii.ini -r n -a n -d n -e y -f y -g n -i n -n y -p y -o ${tmpDir}/ $tmpScanDir`;

  $dcm2niiOutput =~ m/->(.*\.nii)/;

  my $niftiDataFile = $1;

  # Look for warnings in the dicom conversion
  if( !$niftiDataFile || $dcm2niiOutput =~ m/Warning:/ || $dcm2niiOutput =~ m/Error/ )
    {
   	print "\nDICOM conversion failed. dcm2nii output follows\n";

   	print "\n${dcm2niiOutput}\n\n";

	   exit 1;
    }
  # Split each of them into 3D volumes
  # Call each volume S[scan number]_M[measurement number]

  my $scanCounterNumber = formatScanCounter($scanCounter+1);

  # need to find output file from dcm2nii
  system("${caminoDir}/split4dnii -inputfile ${tmpDir}/$niftiDataFile -outputroot ${tmpDir}/${outputFileRoot}S${scanCounterNumber}");

  $scanCounter += 1;

  # Always clean up this to avoid going nuts on the disk usage
  `rm -rf $tmpScanDir`;
  }

# Complete path to all asl images
my @aslImages = ();

# Image list contains all corrected image file names.
# This file is for image2voxel and contains no path information, just file names
my @imageList = ();

# File name to which we write this
my $imageListFile = "${tmpDir}/imagelist.txt";

foreach my $s ( 0 .. $#scanDirs )
  {
  foreach my $i ( 1 .. $numberOfASLTimePoints )
    {
    # no path information because we want the image list to remain valid after we move the images
    my $imageFilename = ${outputFileRoot} . "S" . formatScanCounter( $s + 1 ) . sprintf( "%04d", $i ) . ".nii";

    my $pathToImage = "${tmpDir}/$imageFilename";

    push( @aslImages, $pathToImage );

    my $correctedFileName = $imageFilename;

    # Assuming name of corrected file here, better to get it from function call
    $correctedFileName =~ s/\.nii$/_corrected\.nii/;

    push( @imageList, $correctedFileName );
    }
  }

# $referenceB0 contains an absolute path
my $referenceASL = $aslImages[0];

# Write image list to disk. This is a list of corrected 3D volumes
# in the order in which they appear in the scheme file
open( FILE, ">$imageListFile" ) or die $!;
foreach my $imageListEntry ( @imageList )
  {
  print FILE "$imageListEntry\n";
  }
close FILE;

# Write null transform and feed reference image to ANTS
# This ensures a consistent header / data type for all output images
open( FILE, ">${tmpDir}/nullTransform.txt" ) or die $!;

my $nullTrans = qq/
#Insight Transform File V1.0
# Transform 0
Transform: MatrixOffsetTransformBase_double_3_3
Parameters: 1.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0
FixedParameters: 0.0 0.0 0.0
/;
print FILE $nullTrans;
close FILE;

my $referenceASLCorrect = $referenceASL;

$referenceASLCorrect =~ s/\.nii$/_corrected\.nii/;

`$antsDir/WarpImageMultiTransform 3 $referenceASL $referenceASLCorrect -R $referenceASL ${tmpDir}/nullTransform.txt`;

print "Motion correcting " . scalar( @aslImages ) . " ASL images\n";

# Register all volumes to reference
my @aslImagesCorrect = motionCorrect( $referenceASL, @aslImages );

# Output mean ASL image
my $averageASL = "${tmpDir}/averageasl.nii";
averageImages( $averageASL, @aslImagesCorrect );

# Mask brain
my $brainMask = maskMeanBrains( $averageASL, $protocolName );

# Smooth aligned images.

my @smoothImages = ();

print "\nSmoothing images aligned to anatomical image.\n";
for( my $i = 0; $i < @aslImagesCorrect; $i++ )
  {
  my $j = $i + 1;
  print "  Smoothing image $j (of " . @aslImagesCorrect . ").  Sigma = ${sigma}.\n";

  my $smoothImageFileName = $aslImagesCorrect[$i];
  $smoothImageFileName =~ s/\.nii\.gz/Smooth\.nii\.gz/;

  `SmoothImage 3 $aslImagesCorrect[$i] $sigma $smoothImageFileName`;

  push( @smoothImages, $smoothImageFileName );
  }

################################################################################
##
## Perfusion images are created using a interpolation scheme.  Various
## interpolation algorithms used include variants of nearest-neighbor,
## linear, and sinc interpolation.  Since such a big deal is made over
## interpolation, I've included most of the possibilities in the 'ResampleImage'
## function including the different flavors of sinc interpolation, linear,
## b-spline, gaussian.  One assumption is that the time shift between control-
## label image acquisitions is constant.
##
################################################################################

my @out = `PrintHeader $averageASL`;
$out[9] =~ s/ |Image|Dimensions|:|\]|\[|\n|\r//g;
my @size = split( /,/, $out[9] );

print "\nCreating perfusion images.\n";

for( my $i = 0; $i < @smoothImages; $i+=2 )
  {
  my $controlImage = $i;
  my $labelImage = $i + 1;
  if( ! $isControlFirst )
    {
    $labelImage = $i;
    $controlImage = $i + 1;
    }

  print "  Creating perfusion image from image pair ${controlImage}-${labelImage}.\n";

  my $perfusionImageFileName = $smoothImages[$i];
  $perfusionImageFileName =~ s/\.nii/Perfusion\.nii/;

  my $tmpLabelImageFileName = $smoothImages[$i];
  $tmpLabelImageFileName =~ s/\.nii/Label\.nii/;

  my @interpolation = ( 3, 'c' );
  my @labelImageIndices = ( $controlImage - 5, $controlImage - 3, $controlImage - 1,
    $controlImage + 1, $controlImage + 3, $controlImage + 5 );
  if( $interpolationType eq "nn" )
    {
    @interpolation = ( '1' );
    @labelImageIndices = ( $labelImage );
    }
  elsif( $interpolationType eq "linear" )
    {
    @interpolation = ( '0' );
    @labelImageIndices = ( $controlImage - 1, $controlImage + 1 );
    }
  elsif( $interpolationType eq "gaussian" )
    {
    @interpolation = ( '2' );
    }
  elsif( $interpolationType eq "cosine" )
    {
    @interpolation = ( 3, 'c' );
    }
  elsif( $interpolationType eq "welch" )
    {
    @interpolation = ( 3, 'w' );
    }
  elsif( $interpolationType eq "blackman" )
    {
    @interpolation = ( 3, 'b' );
    }
  elsif( $interpolationType eq "lanczos" )
    {
    @interpolation = ( 3, 'l' );
    }
  elsif( $interpolationType eq "hamming" )
    {
    @interpolation = ( 3, 'h' );
    }
  else # ( $interpolationType eq "bspline" )
    {
    @interpolation = ( 4, 3 );
    }

  my $count = 0;
  my $countBeforeFiles = 0;
  for( my $k = 0; $k < @labelImageIndices; $k++ )
    {
    if( $labelImageIndices[$k] >= 0 && $labelImageIndices[$k] < @aslImages )
      {
      if( $count == 0 )
        {
        `cp $smoothImages[${labelImageIndices[$k]}] $tmpLabelImageFileName`;
        $count++;
        if( $labelImageIndices[$k] < $controlImage )
          {
          $countBeforeFiles++;
          }
        }
      else
        {
        my @args = ( 'TileImages', 4, $tmpLabelImageFileName, '1x1x1x2',
          $tmpLabelImageFileName,
          "${smoothImages[${labelImageIndices[$k]}]}"
          );
        `@{args}`;
        $count++;
        if( $labelImageIndices[$k] < $controlImage )
          {
          $countBeforeFiles++;
          }
        }
      }
    }

  if( $count > 1 && $countBeforeFiles > 0 )
    {
    my $numberOfSlices = $count + ( $count - 1 );
    my @args = ( 'ResampleImage', 4, $tmpLabelImageFileName, $tmpLabelImageFileName,
      "${size[0]}x${size[1]}x${size[2]}x${numberOfSlices}", 1 );
    push( @args, @interpolation );
    `@{args}`;

    my $whichSlice = 0;
    if( $countBeforeFiles == 0 )
      {
      $whichSlice = 0;
      }
    elsif( $countBeforeFiles == 1 )
      {
      $whichSlice = 1;
      }
    elsif( $countBeforeFiles == 2 )
      {
      $whichSlice = 3;
      }
    elsif( $countBeforeFiles == 3 )
      {
      $whichSlice = 5;
      }

    `ExtractSliceFromImage 4 $tmpLabelImageFileName $tmpLabelImageFileName 3 $whichSlice`;
    }
  `ImageMath 3 $perfusionImageFileName - $tmpLabelImageFileName $smoothImages[$i]`;
  `CopyImageHeaderInformation $brainMask $perfusionImageFileName $perfusionImageFileName 1 1 1`;
  `ImageMath 3 $perfusionImageFileName m $perfusionImageFileName $brainMask`;
  unlink( $tmpLabelImageFileName );
  }

# Move results to output directory
`mkdir -p ${outputASL_Dir}`;

`mv $brainMask $outputBrainMask`;

`mv $averageASL ${outputAverageASL}`;

`mv ${tmpDir}/*correctedAffine.txt ${outputASL_Dir}`;
`mv ${tmpDir}/*Perfusion* ${outputASL_Dir}`;

#replace .nii with .nii.gz in the imagelist file
`mv $imageListFile $outputImageListFile`;

open( FILE, "<$outputImageListFile" ) or die $!;

my @gzipImageList = ();

while( <FILE> )
  {
  chomp;
  push( @gzipImageList, $_ );
  }

close FILE;

open(FILE, ">$outputImageListFile") or die $!;

foreach my $imageListEntry (@gzipImageList)
  {
  $imageListEntry =~ s/\.nii$/\.nii\.gz/;
  print FILE "$imageListEntry\n";
  }

close FILE;

# image list entries contain no path information
foreach my $imageListEntry ( @imageList )
  {
  `mv ${tmpDir}/$imageListEntry $outputASL_Dir`;
  }

# Compress to save space
`gzip -f ${outputDir}/*.nii ${outputASL_Dir}/*.nii`;


# cleanup
if( $cleanup )
  {
  `rm -rf $tmpDir`;
  }

# Normalizes all images to the reference volume
#
# @corrected = motionCorrect( $fixedImage, @movingImages );
#
# Returns array of corrected images. If the moving image is ${movingRoot}.nii.[gz], then
# the corrected image is ${moving}_corrected.nii. Eg S001_0001.nii.gz -> S001_0001_corrected.nii
#
# Affine transformations are written to ${movingRoot}_correctedAffine.txt
#
sub motionCorrect
  {
  my ( $fixed, @moving ) = @_;

  # corrected image names
  my @corrected = ();

  foreach my $image ( @moving )
    {
    $image =~ m/(.*)(\.nii)(\.gz)?$/;

	   my $imageRoot = $1;

	   my $ext = "nii";

	   my $out = "${imageRoot}_corrected.$ext";

    print "  Warping ${image} to ${fixed}\n";

    my $DEFORMABLEITERATIONS=0;    # for affine only
    #my $DEFORMABLEITERATIONS="1x0x0";  # for a little fun with deformation
   	`${antsDir}/ANTS 3 -m MI[${fixed},${image},1,16] -t SyN[1] -r Gauss[3,1] -o $out -i $DEFORMABLEITERATIONS`;
    `${antsDir}/WarpImageMultiTransform 3 $image $out -R $fixed  ${imageRoot}_correctedAffine.txt`;

   	push( @corrected, $out );
    }

  return @corrected;
}


# Averages images
#
# averageImages($average, @imagesToAverage)
#
# Arguments should both include full path to images
#
sub averageImages
  {
  my ( $average, @imagesToAverage ) = @_;

  # use ants
  `${antsDir}/AverageImages 3 $average 0 @imagesToAverage`;
}

# Computes brain mask from the average ASL images.
#
# $maskFile = maskMeanBrains( $aslMean, $protocol )
#
# Uses the ASL mean to generate a brain / background mask.
#
# Returns mask image file in nii format - not gzipped.
#
sub maskMeanBrains
  {
  my ( $aslMean, $protocol ) = @_;

  my $maskFile = "${tmpDir}/brainmask.nii";

  print "Creating brain mask using Atropos.\n";

  `${antsDir}/Atropos -d 3 -a $aslMean -x none -k Gaussian -i kmeans[4] -c [5,0.000001] -m [3.0,1x1x1] -o $maskFile`;
  `ThresholdImage 3 $maskFile $maskFile 3 4 1 0`;

  return $maskFile;
}

# formatScanCounter($counter)
#
# Formats the scan counter such that qq("S_" formatScanCounter($counter)) gives the root
# of the ASL images that have been produced by this script.
sub formatScanCounter
  {
  my $scanCounter = shift; # first argument

  return sprintf( "%03d", $scanCounter );
  }

#
# my $fileIsDicom = isDicom($file)
#
# Returns 1 if we don't have imageMagick (have to assume given dirs contain dicom)
# or if file is dicom. Returns 0 if we can confirm that a file is not dicom
#
#
sub isDicom
  {
  # Hack - need to replace identify with something more reliable
  return 1;

  if ( !${imageMagickDir} )
    {
   	return 1;
    }

  my ( $file ) = @_;

  my $identity = `${imageMagickDir}/identify $file 2> /dev/null`;

  # If $file is compressed, ImageMagick will decompress it ti a tmp file, so output will be ${file}=>/tmp/file TYPE
  $identity =~ m|^${file}(=>[^\s]+)?\s+(\w+)\s+|;

  if( defined( $2 ) && $2 eq "DCM" )
    {
  	 return 1;
    }

  return 0;
}
