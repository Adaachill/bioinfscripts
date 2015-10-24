#!/usr/bin/perl

# note: code skeleton is from Raynbow code

use warnings;
use strict;

use Pod::Usage; ## uses pod documentation in usage code
use Getopt::Long qw(:config auto_version auto_help);
use File::Basename; ## for parsing file names
use IPC::Open3; ## for redirecting STDERR from called commands
use IO::Select; ## for non-blocking communication between threads
use Time::HiRes qw(time); ## for measuring sub-second time
use IO::Compress::Gzip qw(gzip $GzipError); ## for gzip output

our $VERSION = "0.1";

=head1 NAME

lastlopper.pl - trim sequences to primer locations using LAST alignments

=head1 SYNOPSIS

./lastlopper.pl -p <primers.fasta> -i <reads.fq> [options]

=head2 Basic Options

=over 2

=item B<-help>

Only display this help message

=item B<-primerfile>

File(s) containing primer sequences to search for

=item B<-outdir>

Output dir for lopped sequences (default 'out_lopped')

=item B<-inputfile>

File(s) containing read sequences to trim

=back

=head1 DESCRIPTION

Carry out a trimming of sequences to identify barcodes and/or other
adapter sequences by searching with LAST using very permissive
parameters.

=head1 METHODS

=cut

=head2 inPath(program)

Returns true if I<program> is in the path

=cut

sub inPath{
  my ($s) = @_;
  system('which', $s);
  return(!($?));
}

=head2 preDotted(string)

Replace the beginning of I<string> with dots if it has length greater
than 30 characters.

=cut

sub preDotted{
  my ($s) = @_;
  $s =~ s/^(.*?)(.{30})$/...$2/;
  return($s);
}

=head2 makePrimerIndex(file, directory)

Generates a LAST index from I<file>, placing the index in I<directory>.

=cut

sub makePrimerIndex{
  my ($primerFile, $outDir) = @_;
  my $startTime = time;
  printf(STDERR "Generating index from primer file '%s'... ",
         preDotted($primerFile));
  my $indexBase = "$outDir/".basename($primerFile);
  $indexBase =~ s/\.[^\.]+?$/.index/;
  my ($wtr,$sout,$serr);
  use Symbol 'gensym'; $serr = gensym;
  my $pid = open3($wtr, $sout, $serr,
                  "lastdb",$indexBase, $primerFile);
  waitpid($pid, 0);
  my $child_exit_status = $? >> 8;
  close($wtr);
  close($sout);
  close($serr);
  my $timeDiff = time - $startTime;
  printf(STDERR "done [created '$indexBase' in %0.1f seconds]\n", $timeDiff);
  return($indexBase);
}

=head2 writeClipTable(outDir, clipHash)

Writes out a table in I<outDir> containing the best primer matches, as
stored in I<clipHash>.

=cut

sub writeClipTable{
  my ($outDir, $clipHash) = @_;
  my $outFileName = "$outDir/bestMapped.tsv";
  my $startTime = time;
  printf(STDERR "Writing best matches to '%s'...",
         preDotted($outFileName));
  open(my $outFile, ">", $outFileName);
  print($outFile join("\t",("qName","score","target",
                            "keepStart","keepEnd"))."\n");
  foreach my $qName (keys(%{$clipHash})){
    print($outFile join("\t",($qName,
                              $clipHash->{$qName}->{"score"},
                              $clipHash->{$qName}->{"target"},
                              $clipHash->{$qName}->{"keepStart"},
                              $clipHash->{$qName}->{"keepEnd"}))."\n");
  }
  my $timeDiff = time - $startTime;
  printf(STDERR " done [written in %0.1f seconds]\n", $timeDiff);
  close($outFile);
}


=head2 lastMap(outDir, dbLoc, inputFile, lastOpts)

Maps I<inputFile> to I<dbLoc> in I<outDir> with LAST using
I<lastOpts> as mapping options.

=cut

sub lastMap{
  my ($outDir, $dbLoc, $inputFile, $lastOpts) = @_;
  my $startTime = time;
  printf(STDERR "Mapping input file '%s' to primers...",
         preDotted($inputFile));
  my ($wtr,$sout,$serr);
  use Symbol 'gensym'; $serr = gensym;
  my @cline = split(/ /,$lastOpts);
  push(@cline, $dbLoc, $inputFile);
  my $pid = open3($wtr, $sout, $serr,
                  "lastal", @cline);
  my $outFileName = "$outDir/lastal_mapped.tsv";
  my $linesOutput = 0;
  my $lineMod = 0;
  my %queryScore = ();
  my $queryMeta = {};
  open(my $outFile, ">", $outFileName);
  while(<$sout>){
    my $line = $_;
    print($outFile $line);
    $linesOutput++;
    $lineMod++;
    if($lineMod > 5000){
      print(STDERR ".");
      $lineMod = 0;
    }
    if($line =~ /^#/){
      next;
    }
    # parse output and store best scores in hash
    my ($score, $name1, $start1, $alnSize1, $strand1, $seqSize1,
        $name2, $start2, $alnSize2, $strand2, $seqSize2, $blocks, $rest) =
          split(/\t/, $line, 13);
    if(!exists($queryScore{$name2}) || ($queryScore{$name2} < $score)){
      $queryScore{$name2} = $score;
      # default to keep start of sequence
      my $keepStart = 0;
      my $keepEnd = $start2;
      if(($start2 + ($alnSize2 / 2)) < ($seqSize2 / 2)){
        # keep last part of sequence
        $keepStart = $start2 + $alnSize2;
        $keepEnd = $seqSize2;
      }
      $queryMeta -> {$name2} = {score => $score, target => $name1,
                                keepStart => $keepStart, keepEnd => $keepEnd};
    }
  }
  if($linesOutput == 0){
    while(<$serr>){
      print(STDERR $_);
    }
  }
  close($wtr);
  close($sout);
  close($serr);
  close($outFile);
  waitpid($pid, 0);
  my $child_exit_status = $? >> 8;
  my $timeDiff = time - $startTime;
  printf(STDERR " done [mapped '$inputFile' in %0.1f seconds]\n", $timeDiff);
  if($linesOutput == 0){
    return("");
  } else {
    writeClipTable($outDir, $queryMeta);
    return($outFileName);
  }
}

####################################################
# Command line parsing and verification starts here
####################################################

my $argLine = join(" ",@ARGV);

my $options =
  {
   "outdir" => "out_lopped",
  };

GetOptions($options,
           'outdir|o=s',
           'primerfile=s',
           'inputfile=s',
          ) or
  pod2usage(1);

## don't overwrite output dir; derive a new name instead

if(-e $options->{"outdir"}){
  my $iter = 0;
  while(-e $options->{"outdir"}.".$iter"){
    $iter++;
  }
  $options->{"outdir"} .= ".$iter";
}

## check to make sure input files are specified and exist

if(!($options->{"primerfile"}) ||
   !($options->{"inputfile"})){
  pod2usage("Error: primer file (-p) and input file (-i) must be specified");
}

if(!(-f $options->{"primerfile"})){
  pod2usage("Error: specified primer file [".$options->{"primerfile"}.
            "] does not exist");
}

if(!(-f $options->{"inputfile"})){
  pod2usage("Error: specified input file [".$options->{"inputfile"}.
            "] does not exist");
}

## check to make sure program(s) exist

foreach my $prog ("lastal"){
  if(!inPath($prog)){
    pod2usage("Error: '$prog' cannot be found in the system path. ".
              "Please install $prog.");
  }
}

###############################
# Program meat starts here
###############################

mkdir($options->{"outdir"});

open(my $outFile, ">", $options->{"outdir"}."/cmdline.txt");
printf($outFile "Command line: %s\n", $argLine);
close($outFile);

## create primer index file
my $indexBase = makePrimerIndex($options->{"primerfile"}, $options->{"outdir"});

my $outFileName = lastMap($options->{"outdir"}, $indexBase, $options->{"inputfile"}, "-f 0 -Q 1 -T 1 -r 5 -a 0 -e 50");

=head1 AUTHOR

David Eccles (gringer) 2014 <bioinformatics@gringene.org>

=head1 LICENSE

Permission to use, copy, modify, and/or distribute this software for
any purpose with or without fee is hereby granted, provided that the
above copyright notice and this permission notice appear in all
copies.

The software is provided "as is" and the author disclaims all
warranties with regard to this software including all implied
warranties of merchantability and fitness. In no event shall the
author be liable for any special, direct, indirect, or consequential
damages or any damages whatsoever resulting from loss of use, data or
profits, whether in an action of contract, negligence or other
tortious action, arising out of or in connection with the use or
performance of this software.

=head1 AVAILABILITY

The most recent version of this code can be found on github:

https://github.com/gringer/bioinfscripts/lastlopper.pl
