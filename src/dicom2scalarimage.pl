#!/usr/bin/perl -w
#
# Convert DICOM to scalar (e.g. T1) (.nii)
#

my $usage = qq{
dicom2t1.sh converts dicom to scalar (e.g. T1) in .nii.gz format

Usage: dicom2t1.sh <input_dir> <protocol_name> <output_dir> <output_file_root>

<input_dir> - input directory. Program looks for scans matching <input_dir>/*<protocol_name>.

<protocol_name> - name of the protocol you want to convert, eg t1_mpr_AX_MPRAGE. 
                  Repeat scans are currently not supported, the first series matching the protocol
		  will be processed.

<output_dir> - Output base directory.

<output_file_root> - Root of output, eg subject_TP1_t1

};

use strict;
use FindBin qw($Bin);
use File::Path;
use File::Spec;

# Set to 1 to delete intermediate files after we're done
my $cleanup=1;

# # Input directory. DICOM files are in $inputDir/.*${sequenceName}.*/
my $inputDir = "";

# # Output directory
my $outputDir = "";

# # Output file root
my $outputFileRoot = "";

# # eg DTI_30dir_noDiCo_vox2_1000
# # We will process all directories matching this
# # Or alternate ones if desired (skip scanner moco series)
my $protocolName = "";

my ($antsDir, $dcm2niiDir, $imageMagickDir) = @ENV{'ANTSPATH', 'DCM2NIIPATH', 'IMAGEMAGICKPATH'};

#Process command line args
if (($#ARGV != 3)) {
    print "$usage\n";
    exit 0;
}
else {

    my $useQueue = "";

    ($inputDir, $protocolName, $outputDir, $outputFileRoot) = @ARGV;

}
# done with args

if (! -d $outputDir ) {
    mkpath($outputDir, {verbose => 0, mode => 0755}) or die "Can't make output directory $outputDir\n\t";
}

#Directories containing the scans
my @scanDirs = `find -L $inputDir -maxdepth 1 -type d -name \"*${protocolName}\"`;

if (scalar(@scanDirs) == 0) {
    print "No scans found matching protocol ${protocolName}. Exiting\n";
    exit 1;
}

# sort by series number
@scanDirs = sort(@scanDirs);

# Current implementation does not handle multiple scans properly
# In the future, we will rigidly align, then average multiple scans

my $singleScan = $scanDirs[0];

chomp $singleScan;

if (scalar(@scanDirs) > 1) {
    print "WARNING: Multiple scans found matching ${protocolName}. Processing $singleScan only\n";
}

print "Transfering DICOM files for scan ${singleScan}\n";

my $tmpDir = "${outputDir}/${outputFileRoot}tmp";

mkpath($tmpDir, {verbose => 0, mode => 0755}) or die "Can't make working directory $tmpDir\n\t";

my @imageFiles = `ls $singleScan`;

foreach my $inputFile (@imageFiles) {
    chomp $inputFile;
    
    # Skip non-dicom files that may exist in that directory	
    if (isDicom("${singleScan}/$inputFile")) {
	
	my $dcmFile = $inputFile;
	
	if ($inputFile =~ m/\.gz$/) {
	    
	    $dcmFile =~ s/\.gz$//;
	    `gunzip -c ${singleScan}/${inputFile} > ${tmpDir}/$dcmFile`;
	}
	else {
	    `cp ${singleScan}/$inputFile ${tmpDir}/$dcmFile`;
	}
    }
    else {
	print "Skipping non-dicom file $inputFile\n";
    }
    
}

# run dcm2nii
my $dcm2niiOutput = `${dcm2niiDir}/dcm2nii -b ${Bin}/../config/dcm2nii.ini -r n -a n -d n -e y -f y -g n -i n -n y -p y -o ${outputDir}/ $tmpDir`;

$dcm2niiOutput =~ m/->(.*\.nii)/;
my $niftiDataFile = $1;

# Look for warnings in the dicom conversion
if ($dcm2niiOutput =~ m/Warning:/ || $dcm2niiOutput =~ m/Error/) {
    print "\nDICOM conversion failed. dcm2nii output follows\n";
    
    print "\n${dcm2niiOutput}\n\n";
    
    exit 1;
}


`mv ${outputDir}/$niftiDataFile ${outputDir}/${outputFileRoot}.nii`;
`gzip ${outputDir}/${outputFileRoot}.nii`;


if ($cleanup) {
    `rm -rf $tmpDir`;
}



#
# my $fileIsDicom = isDicom($file)
#
# Returns 1 if we don't have imageMagick (have to assume given dirs contain dicom) 
# or if file is dicom. Returns 0 if we can confirm that a file is not dicom
# 
#
sub isDicom {
   
    # Hack - need to replace identify with something more reliable
    return 1;
 
    if (!${imageMagickDir}) {
	return 1;
    }

    my ($file) = @_;

    my $identity = `${imageMagickDir}/identify $file 2> /dev/null`;

    # If $file is compressed, ImageMagick will decompress it ti a tmp file, so output will be ${file}=>/tmp/file TYPE 
    $identity =~ m|^${file}(=>[^\s]+)?\s+(\w+)\s+|;

    if (defined($2) && $2 eq "DCM") {
	return 1;
    }

    return 0;
}
