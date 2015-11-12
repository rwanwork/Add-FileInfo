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


package fileinfo;
require Exporter;
our @ISA = qw (Exporter);
our @EXPORT = qw (CleanPath GetFilenameKey AddHeader);
our @EXPORT_OK = qw (CleanPath GetFilenameKey AddHeader);

use FindBin qw ($Bin);
use lib "$Bin";

use File::Copy;

use strict;
use warnings;
use diagnostics;


################################################################################
##  Clean up paths
sub CleanPath {
  my $path = shift;

  ##  Remove double /'s.
  $path =~ s/\/\//\//s;

  ##  Search for "/X/Y/" where Y has ".." and X has no "." nor "/".  Replace it with a "/"
  $path =~ s/\/[^\.\/]+\/\.\.\//\//so;

  ##  If there are still .., then call recursively
  if ($path =~ /\.\./) {
    $path = CleanPath ($path);
  }

  return $path;
}


##  Translate a filename to a 'key' used to lookup a hash of file types
sub GetFilenameKey {
  my $fn = shift;
  my $key = "";

  if ($fn =~ /\.pl$/) {
    $key = "pl";
  }
  elsif ($fn =~ /\.pm$/) {
    $key = "pm";
  }
  elsif ($fn =~ /\.cpp$/) {
    $key = "cpp";
  }
  elsif ($fn =~ /\.hpp$/) {
    $key = "hpp";
  }
  elsif ($fn =~ /\.hpp\.in$/) {
    $key = "hpp.in";
  }
  elsif ($fn =~ /^Doxyfile.in$/) {
    $key = "Doxyfile.in";
  }
  elsif ($fn =~ /\/Doxyfile.in$/) {
    $key = "Doxyfile.in";
  }
  elsif ($fn =~ /^CMakeLists.txt$/) {
    $key = "CMakeLists.txt";
  }
  elsif ($fn =~ /\/CMakeLists.txt$/) {
    $key = "CMakeLists.txt";
  }
  elsif ($fn =~ /\.tmp$/) {
    $key = "tmp";
  }

  return ($key);
}


sub AddHeader {
  my ($istest, $fn, $header, $header_top, $header_bottom, $header_size) = @_;
  my $tmp_fn = "/tmp/add-header.tmp";
  my $str = "";
  my $hashbang = "";

  ##  Read in the file and store it in $str
  open (FP_IN, "<", $fn) or die "Could not open $fn.";
  $hashbang = <FP_IN>;
  while (<FP_IN>) {
    my $line = $_;
    $str = $str.$line;
  }
  close (FP_IN);

  ##  Check if there is a hashbang at the top
  if ((defined $hashbang) && ($hashbang !~ /^#\!/)) {
    $str = $hashbang.$str;  ##  Put the first line back
    $hashbang = "";
  }

  my $top_position = index ($str, $header_top);
  my $bottom_position = -1;
  if ($top_position != -1) {
    $bottom_position = index ($str, $header_bottom, $top_position + length ($header_top));
  }

  ##  A header exists already, so skip this file
  if (($top_position != -1) && ($bottom_position != -1)) {
    ##  $top_position is the start of $header_top
    ##  $bottom_position is the start of $header_bottom,
    ##    so we add its length to move to the end
    ##  we +1 to include the newline at the end of $header_bottom
    my $len = $bottom_position + length ($header_bottom) - $top_position + 1;
    my $old_header = substr ($str, $top_position, $len, $header);
    if ($old_header ne $header) {
      printf STDERR "II\tReplacing header:  %s...\n", $fn;
    }
    else {
      printf STDERR "II\tNo change to header:  %s...\n", $fn;
    }
  }
  else {
    printf STDERR "II\tAdding header:  %s...\n", $fn;

    $str = $header."\n\n".$str;
  }

  open (FP_OUT, ">", $tmp_fn) or die "Could not open $tmp_fn.";
  if (defined ($hashbang)) {
    print FP_OUT $hashbang;
  }
  if (defined ($str)) {
    print FP_OUT $str;
  }
  close (FP_OUT);

  ##  Rename files
  if (!$istest) {
    move ($tmp_fn, $fn);
  }

  return;
}

1;


