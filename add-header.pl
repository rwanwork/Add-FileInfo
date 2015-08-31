#!/usr/bin/perl
###########################################################################
##  Add-FileInfo
##  Helps add a header to the tops of a set of files
##  
##  Version 1.0 -- August 31, 2015
##  
##  Copyright (C) 2011-2015 by Raymond Wan, All rights reserved.
##  Contact:  rwan.work@gmail.com
##  Organization:  Division of Life Science, The Hong Kong University of Science
##                 and Technology, Hong Kong, China
##  
##  This file is part of Add-FileInfo.
##  
##  Add-FileInfo is free software; you can redistribute it and/or 
##  modify it under the terms of the GNU General Public License 
##  as published by the Free Software Foundation; either version 
##  3 of the License, or (at your option) any later version.
##  
##  Add-FileInfo is distributed in the hope that it will be useful,
##  but WITHOUT ANY WARRANTY; without even the implied warranty of
##  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##  GNU General Public License for more details.
##  
##  You should have received a copy of the GNU General Public 
##  License along with Add-FileInfo; if not, see 
##  <http://www.gnu.org/licenses/>.
###########################################################################


use FindBin qw ($Bin);

use diagnostics;
use strict;
use warnings;

use lib "$Bin";
use fileinfo;

use Text::Wrap;

use AppConfig;
use AppConfig::Getopt;
use Pod::Usage;
use Switch;
use Cwd;


####################
##  Global variables
my $i = 0;  ##  General counter

my $FILL_LENGTH = 74;

my @HEADER_TEXT;  ##  Header text with the variables substituted in
my $header_lines = 0;  ##  Header text size in number of lines
my $header_chars = 0;  ##  Header text size in number of characters

my %SETTINGS;  ##  Hash of the settings to insert into the template

my %HEADER;
my %HEADER_TOP;
my %HEADER_BOTTOM;

##  Arrays
my @PATHS_STACK;  ##  Stack of paths to process
my @FILES_STACK;  ##  Stack of files to process

##  Hashes
my %PATHS_DONE;  ##  Hash of paths to CMakeLists.txt that have been processed already
my %FILES_ADDED;  ##  Hash of files added already (but not yet processed)


####################
##  Process arguments

##  Create AppConfig and AppConfig::Getopt objects
my $config = AppConfig -> new ({
        GLOBAL => {
            DEFAULT => undef,     ##  Default value for new variables
        }
    });

my $getopt = AppConfig::Getopt -> new ($config);

$config -> define ("cmake", {
            ARGCOUNT => AppConfig::ARGCOUNT_ONE,
            ARGS => "=s",
        });                            ##  Top-level CMakeLists.txt
$config -> define ("text", {
            ARGCOUNT => AppConfig::ARGCOUNT_ONE,
            ARGS => "=s",
        });                            ##  Text file with full pathnames
$config -> define ("settings", {
            ARGCOUNT => AppConfig::ARGCOUNT_ONE,
            ARGS => "=s",
            DEFAULT => "settings.txt",
        });                            ##  Location of the package specific settings
$config -> define ("template", {
            ARGCOUNT => AppConfig::ARGCOUNT_ONE,
            ARGS => "=s",
            DEFAULT => "sample-template.txt",
        });                            ##  Location of the template
$config -> define ("filetypes", {
            ARGCOUNT => AppConfig::ARGCOUNT_ONE,
            ARGS => "=s",
            DEFAULT => "filetypes.txt",
        });                            ##  Location of filetypes.txt file
$config -> define ("verbose!", {
            DEFAULT => 0,
        });                            ##  Verbose mode
$config -> define ("test!", {
            DEFAULT => 0,
        });                            ##  Test mode (do not perform any changes)
$config -> define ("help!", {
            DEFAULT => 0,
        });                            ##  Help screen

##  Process the command-line options
$config -> getopt ();


####################
##  Validate the settings
if ($config -> get ("help")) {
  pod2usage (-verbose => 0);
  exit (1);
}

if ((!defined ($config -> get ("cmake"))) && (!defined ($config -> get ("text")))) {
  printf STDERR "EE\tEither the location of the top-level cmake file (CMakeLists.txt) OR a text file with full pathnames is required with --cmake or --text, respectively.\n";
  exit (1);
}

if ((defined ($config -> get ("cmake"))) && (defined ($config -> get ("text")))) {
  printf STDERR "EE\tOnly one of either --cmake or --text should be specified.  Not both.\n";
  exit (1);
}

if (!defined ($config -> get ("settings"))) {
  printf STDERR "EE\tSettings file required with the --settings option.\n";
  exit (1);
}
elsif (!-e $config -> get ("settings")) {
  printf STDERR "EE\tThe settings file provided with the --settings option could not be found [%s].\n", $config -> get ("settings");
  exit (1);
}

if (!defined ($config -> get ("template"))) {
  printf STDERR "EE\tTemplate file required with the --template option.\n";
  exit (1);
}
elsif (!-e $config -> get ("template")) {
  printf STDERR "EE\tThe template file provided with the --template option could not be found.\n";
  exit (1);
}

if (!defined ($config -> get ("filetypes"))) {
  printf STDERR "EE\tList of file types required with the --filetypes option.\n";
  exit (1);
}
elsif (!-e $config -> get ("filetypes")) {
  printf STDERR "EE\tThe list of file types provided with the --filetypes option could not be found.\n";
  exit (1);
}


####################
##  Read in the settings
my $fn = $config -> get ("settings");
open (FP, "<", $fn) or die "EE\tCould not open $fn for input.\n";
while (<FP>) {
  my $line = $_;
  chomp $line;

  my @array = split /\t/, $line;

  ##  Ignore comments
  if ($line =~ /^#/) {
    next;
  }

  ##  Ignore line of 0 or more white spaces
  if ($line =~ /^\s*$/) {
    next;
  }

  ##  Must be tab-separated file
  if (scalar (@array) != 2) {
    printf STDERR "WW\tSettings file should be tab-separated!\n";
    next;
  }

  if (!defined ($SETTINGS{$array[0]})) {
    $SETTINGS{$array[0]} = $array[1];
  }
  else {
    $SETTINGS{$array[0]} = $SETTINGS{$array[0]}."\n".$array[1];
  }
}
close (FP);

if ($config -> get ("verbose")) {
  foreach my $key (sort (keys %SETTINGS)) {
    printf STDERR "II\t%s = %s\n", $key, $SETTINGS{$key};
  }
}


####################
##  Read in the template
my $count = 0;
$header_chars = 0;
$fn = $config -> get ("template");
open (FP, "<", $fn) or die "EE\tCould not open $fn for input.\n";
while (<FP>) {
  my $line = $_;

  while ($line =~ /(=[^=]+=)/) {
    if ($line =~ /(=[^=]+=)/) {
      my $key = $1;
      my $newkey = $SETTINGS{$key};

      if (!defined $newkey) {
        printf STDERR "WW\tNo replacement available for %s.\n", $key;
        next;
      }

      if (length ($newkey) > $FILL_LENGTH) {
        if ($key eq "=PROGINFO=") {
          $newkey = $newkey;
          $Text::Wrap::unexpand = 0;
          $Text::Wrap::columns = ($FILL_LENGTH);
          $newkey =  wrap ('', '  ', $newkey);
        }
        elsif ($key eq "=AUTHOR_ORGANIZATION=") {
          $newkey = $newkey;
          $Text::Wrap::unexpand = 0;
          $Text::Wrap::columns = ($FILL_LENGTH - 10);
          $Text::Wrap::break = '[\s,]';
          $Text::Wrap::huge = "overflow";
          $newkey =  wrap ('', '               ', $newkey);
        }

        my @tmp_array = split /\n/, $newkey;
        $line =~ s/$key/$tmp_array[0]/s;
        $HEADER_TEXT[$count++] = $line;
        my $k = 0;
        for ($k = 1; $k < (scalar (@tmp_array) - 1); $k++) {
          $HEADER_TEXT[$count++] = $tmp_array[$k]."\n";
        }
        $line = $tmp_array[$k]."\n";
      }
      else {
        $line =~ s/$key/$newkey/s;
      }
    }
  }

  $HEADER_TEXT[$count] = $line;
  $count++;
  $header_chars += length ($line);
}
close (FP);
$header_lines = $count;

if ($config -> get ("verbose")) {
  printf STDERR "\n\n";
  printf STDERR "II\tLength of the header file in characters:  %u\n", $header_chars;
  printf STDERR "II\tLength of the header file in lines:  %u\n", $header_lines;
  for ($i = 0; $i < $header_lines; $i++) {
    printf STDERR "%s", $HEADER_TEXT[$i];
  }
}


####################
##  Read in file types
$fn = $config -> get ("filetypes");
open (FP, "<", $fn) or die "EE\tCould not open $fn for input.\n";
while (<FP>) {
  my $line = $_;
  chomp $line;

  if ($line =~ /^#/) {
    next;  ##  Comment line
  }

  my ($type, $extfn, $prepend, $firststart_ch, $fillch, $lastend_ch) = split /\t/, $line;
  if (!defined $lastend_ch) {
    printf STDERR "EE\tThe line [%s] in %s is incomplete.  Please double-check it.\n", $line, $config -> get ("filetypes");
    exit (1);
  }

  my $str = "";
  my $top = $firststart_ch.($fillch x $FILL_LENGTH);
  for ($i = 0; $i < $header_lines; $i++) {
    $str = $str.$prepend."  ".$HEADER_TEXT[$i];
  }
  my $bottom = ($fillch x $FILL_LENGTH).$lastend_ch;

  $str = $top."\n".$str.$bottom."\n";

  if ($type eq "X") {
    $HEADER_TOP{$extfn} = $top;
    $HEADER{$extfn} = $str;
    $HEADER_BOTTOM{$extfn} = $bottom;
  }
  elsif ($type eq "F") {
    $HEADER_TOP{$extfn} = $top;
    $HEADER{$extfn} = $str;
    $HEADER_BOTTOM{$extfn} = $bottom;
  }
}
close (FP);


####################
##  Read in and process the CMakeLists.txt files

if (defined ($config -> get ("cmake"))) {
  my $top_path = $config -> get ("cmake");

  push (@PATHS_STACK, $top_path);

  while (scalar (@PATHS_STACK) != 0) {
    ##  Pop the current path where the CMakeLists.txt and other source files are
    my $curr_path = shift (@PATHS_STACK);

    ##  Check if we have processed this path already
    if (!defined $PATHS_DONE{$curr_path}) {
      my $curr_cmake_fn = $curr_path."/CMakeLists.txt";

      ##  Open the CMakeLists.txt and find subdirectories that it depends on
      open (FP, "<", $curr_cmake_fn) or die "EE\tCould not open $curr_cmake_fn for input.\n";
      while (<FP>) {
        my $line = $_;
        if ($line =~ /^#/) {
          next;  ##  Skip comments
        }

        if ($line =~ /ADD_SUBDIRECTORY_ONCE \((.+) /) {
          my $new_path = $curr_path."/".$1;
          $new_path = CleanPath ($new_path);

          if (!defined $PATHS_DONE{$new_path}) {
            push (@PATHS_STACK, $new_path);
          }
        }
      }
      close (FP);

      ##  Read in the list of files in the directory
      opendir (my $dh, $curr_path) || die "Can't opendir $curr_path: $!";
      my @files = readdir ($dh);
      closedir $dh;

      ##  Process each file
      for my $tmp (@files) {
        ##  Filenames to ignore
        if (-d $curr_path."/".$tmp) {
          next;  ##  Directory
        }
        if ($tmp =~ /^\.svn$/) {
          next;
        }
        elsif ($tmp =~ /\.kdev4$/) {
          next;
        }
        elsif ($tmp =~ /^\.+$/) {
          next;
        }
        elsif ($tmp =~ /~$/) {
          next;
        }
        elsif ($tmp =~ /^build$/) {
          next;
        }

        my $key = "";
        $key = GetFilenameKey ($tmp);
        if (length ($key) == 0) {
          printf STDERR "WW\tUnrecognized file type:  %s.\n", CleanPath ($curr_path."/".$tmp);
          next;
        }

        AddHeader ($config -> get ("test"), $curr_path."/".$tmp, $HEADER{$key}, $HEADER_TOP{$key}, $HEADER_BOTTOM{$key}, $header_chars);
      }
    }

    $PATHS_DONE{$curr_path} = 1;
  }
}
elsif (defined ($config -> get ("text"))) {
  my $fn = $config -> get ("text");
  open (FP, "<", $fn) or die "EE\tCould not open $fn for input.\n";
  while (<FP>) {
    my $current_file = $_;
    chomp $current_file;

    ##  Ignore comments
    if ($current_file =~ /^#/) {
      next;
    }

    my $key = "";
    $key = GetFilenameKey ($current_file);
    if (length ($key) == 0) {
      printf STDERR "WW\tUnrecognized file type:  %s.\n", CleanPath ($current_file);
      next;
    }

    if (-e $current_file) {
      AddHeader ($config -> get ("test"), $current_file, $HEADER{$key}, $HEADER_TOP{$key}, $HEADER_BOTTOM{$key}, $header_chars);
    }
    else {
      printf "WW\tThe file \'%s\' could not be found.  Note that relative path names are relative to the current directory.\n", $current_file;
    }
  }
  close (FP);
}



=pod

=head1 NAME

add-header.pl -- Add a header to a set of files.  An example header
might include a software header, author's name, and his/her
affiliation.

=head1 SYNOPSIS

B<add-header.pl> [OPTIONS]

=head1 DESCRIPTION

Adds a header to the top of a set of source files.

=head1 OPTIONS

=over 5

=item --cmake F<path>

Path to the top-level CMakeLists.txt.  Only one of --cmake or --text can be used.

=item --text F<path>

Path to a text file of files to add a header to.  Only one of --cmake or --text can be used.

=item --settings F<file>

File of settings specific to this distribution.

=item --template F<path>

Header template to use.

=item --filetypes F<path>

File showing list of file types that are supported and how to handle each one.

=item --verbose

Verbose mode.

=item --test

Run in test mode (no changes actually made).

=item --help

Display this help message.

=back

=head1 EXAMPLE

=over 5

./add-header.pl --cmake ~/src/ 2>&1

=back

=head1 AUTHOR

Raymond Wan <rwan.work@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2011-2015, Raymond Wan, All rights reserved.

