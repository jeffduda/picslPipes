#!/usr/bin/perl -w

##
## sample usage:  perl convertToNifti.pl subjects.txt Dicom Nifti
##
##


# use module
use strict;
use warnings;
use Data::Dumper;
use Cwd 'realpath';
use Cwd;
use File::Spec;
use File::Find;
use File::Basename;
use File::Path;
use Getopt::Long;

sub logCmd {
  my $cmd = shift;
  my $log = shift;

  print $log "$cmd\n";
  my $val = system($cmd);

  return $val;
}


my $bold  = "";     # bold nii file
my $boldinfo = "";  # bold json file
my $t1 = "";        # t1 image (brain masked)
my $t1mask = "";    # t1 brain mask
my @echomag = ();
my $echophase = "";
my $echodelta = 2.46;
my $dwell = 0.00003;
my $out = "";
my $verbose;

my $FSL = $ENV{'FSLDIR'};
$FSL = "${FSL}/bin";
my $ANTS = $ENV{'ANTSPATH'};

GetOptions ("bold=s"        => \$bold,        # string
            "bold-info=s"   => \$boldinfo,     # string
            "t1=s"          => \$t1,
            "t1-mask=s"     => \$t1mask,
            "echo-mag=s"    => \@echomag,
            "echo-phase=s"  => \$echophase,
            "echo-delta=f"  => \$echodelta,
            "dwell-time=f"  => \$dwell,
            "out=s"         => \$out,
            "verbose"       => \$verbose)     # flag
or die("Error in command line arguments\n");

# Echo back inputs
if ( $verbose ) {
  print( "picslPipeRsBold.pl called with:\n");
  print( "Bold:      $bold\n");
  print( "Bold-info: $boldinfo\n");
  print( "System settings:\n");
  print( "T1: $t1\n");
  print( "T1-Mask: $t1mask\n");
  print( "Echo-mag: @echomag\n");
  print( "Echo-phase: $echophase\n");
  print( "Echo-delta: $echodelta\n");
  print( "Dwell-time: $dwell\n");
  print( "Output-prefix: $out\n");
  print( "FSL=$FSL\n");
  print( "ANTS=$ANTS\n");
}

# Check for all required files
# FIXME

open( my $log, '>', "${out}commands.log" );

my $cmdTest = "";

if ( scalar(@echomag) > 1 ) {
  $cmdTest = logCmd( "${ANTS}/AverageImages 3 ${out}echomag.nii.gz 0 @echomag", $log);
}
else {
  $cmdTest = logCmd( "cp $echomag[0] ${out}echomag.nii.gz", $log);
}

if ( ! -s "${out}echomag_BrainExtractionBrain.nii.gz" ) {
  if ( $verbose ) {
    print $log "# Brain Extraction for fieldmap\n";
  }

  $cmdTest = logCmd("${ANTS}/antsBrainExtraction.sh -d 3 -a ${out}echomag.nii.gz -c 3,2,3,1 -e $t1 -m $t1mask -q 1 -o ${out}echomag_",$log);

  #FSL suggest a tight mask and suggests "erring on excluding brain voxels"
  $cmdTest = logCmd("${ANTS}/ImageMath 3 ${out}echomag_BrainExtractionMask.nii.gz ME ${out}echomag_BrainExtractionMask.nii.gz 2", $log);
  $cmdTest = logCmd("${ANTS}/ImageMath 3 ${out}echomag_BrainExtractionBrain.nii.gz m ${out}echomag.nii.gz ${out}echomag_BrainExtractionMask.nii.gz", $log);

}

# Create shift map
if ( ! -s "${out}shiftmap.nii.gz" ) {
  if ( $verbose ) {
    print $log "# Distortion Correction\n";
  }

  my $fsl1 = "${FSL}/fsl_prepare_fieldmap SIEMENS $echophase ${out}echomag_BrainExtractionBrain.nii.gz ${out}fieldmap_rads.nii.gz $echodelta";
  $cmdTest = logCmd($fsl1, $log);
  my $fsl2 = "${FSL}/fugue -i $bold --dwell=$dwell --loadfmap=${out}fieldmap_rads.nii.gz --saveshift=${out}shiftmap.nii.gz -u ${out}rsbold_corr.nii.gz --unwarpdir=y-";
  $cmdTest = logCmd($fsl2, $log);
  $cmdTest = logCmd("Rscript shiftToWarp.R ${out}shiftmap.nii.gz ${out}shift0Warp.nii.gz", $log);
}

# Motion correction
if ( ! -s "${out}mocoMOCOparams.csv" ) {
  if ( $verbose ) {
    print $log "# Motion Correction of BOLD\n";
  }

  $cmdTest = logCmd("${ANTS}/antsMotionCorr -d 3 -a ${out}rsbold_corr.nii.gz -o ${out}bold_mean.nii.gz", $log);

  my $outFlag = "";

  for ( my $i=0; $i<3; $i++ ) {
    if ( $i == 2 ) {
      $outFlag = "-w 1";
    }
    my $moco = "${ANTS}/antsMotionCorr -d 3 -u 1 -m MI[${out}bold_mean.nii.gz,${out}rsbold_corr.nii.gz,1,32,Regular,0.25] -t Rigid[0.2] -f 3x2x1 -s 2x1x0 -i 100x100x100 -v 1 -o [${out}moco, ${out}bold_warped.nii.gz, ${out}bold_mean.nii.gz]  --use-histogram-matching 0 $outFlag";
    $cmdTest = logCmd( $moco, $log );
  }
}

# Bold -> T1 mapping
if ( ! -s "${out}boldToT11Warp.nii.gz" ) {
  if ( $verbose ) {
    print $log "# BOLD to T1 mapping\n";
  }
  $cmdTest = logCmd("${ANTS}/ResampleImageBySpacing 3 $t1 ${out}t1_ref.nii.gz 2 2 2", $log);
  $cmdTest = logCmd("${ANTS}/ResampleImageBySpacing 3 $t1mask ${out}t1_ref_mask.nii.gz 2 2 2", $log);
  $cmdTest = logCmd("${ANTS}/ThresholdImage 3 ${out}t1_ref_mask.nii.gz ${out}t1_ref_mask.nii.gz 0.01 Inf", $log);
  $cmdTest = logCmd("${ANTS}/antsRegistration -d 3 -z 1 --winsorize-image-intensities [0.005, 0.995] -u 1 -x [${out}t1_ref_mask.nii.gz] -m MI[ ${out}t1_ref.nii.gz, ${out}bold_mean.nii.gz, 1, 32, Regular, 0.25] -c [1000x500x100, 1e-7,5 ] -f 3x2x1 -s 2x1x0mm -t Affine[0.1] -m MI[ ${out}t1_ref.nii.gz, ${out}bold_mean.nii.gz, 1, 32, Regular, 0.25] -c [50x50x20, 1e-7,5 ] -f 3x2x1 -s 2x1x0mm -t SyN[0.1] -o [${out}boldToT1, ${out}boldToT1Warped.nii.gz] -v 1", $log);
}

# Slice timing to csv

# Combo 4D warp


# Clean-up
#$cmdText = logCmd("rm ${out}bold_warped.nii.gz")
