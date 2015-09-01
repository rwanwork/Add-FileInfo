# Add-FileInfo

The purpose of this Perl script is to add a boiler plate in the
form of a header to a set of files.  The set of files can be
given as:

  * a text file
  * a CMake CMakeLists.txt file

Unlike what an Integrated Development Environment (IDE) might
do, this script adds the boiler plate *after* development.
The boiler plate is surrounded by a box -- if an update is
required, this box is replaced rather than prepended to.


## Prerequisites

The following is a list of Perl modules that are required:
  * Text::Wrap
  * AppConfig
  * AppConfig::Getopt
  * Pod::Usage
  * Switch
  * Cwd

Under Ubuntu 15.04, the following packages should be installed:
  * libtext-wrapi18n-perl 
  * libappconfig-perl 
  * libswitch-perl

  
## Execution


The following inputs are required to run the script:

  * template -- added to the beginning of every file
  * substitutions -- a tab-separated list of substitutions
  * filetypes -- a list of file extensions that explain how comments are formatted

Type `perldoc add-header.pl` for some additional information.


## Example

The header for the files in this distribution were generated using these two commands:

     find ./ -name '*.p?' >files.txt
     ./add-header.pl --text files.txt --settings add-fileinfo.txt --template sample-template.txt

Consider creating a blank file with the `tmp` extension and then run the above command.  
Then compare the output with the entry in `filetypes.txt` for the file extension `.tmp`.


## Caveats

Very minimal testing has been performed.  It's been used a few times for several
projects, but that doesn't mean that major bugs do not still exist.

Back up yourfiles before running in case your files end up being clobbered.


## About Add-FileInfo


This software was implemented by Raymond Wan. Most of it was implemented while
I was at the University of Tokyo in 2011, but it has been continually improved.
Now that I'm at the Hong Kong University of Science and Technology and using
Git regularly, I decided to release it on GitHub in case someone else finds
this useful.

     E-mail: rwan.work AT gmail DOT com
     Homepage: http://www.rwanwork.info/

The latest version can be downloaded from Git at:

     Download:  https://github.com/rwanwork/Add-FileInfo

This software is actively maintained. If you have any information about bugs, 
suggestions for the documentation or just have some general comments, feel free 
to write to me at the above address.


## Copyright and License

     Add-FileInfo (Add file information to a set of files)
     Copyright (C) 2011-2015 by Raymond Wan

Add-FileInfo is distributed under the terms of the GNU General
Public License (GPL, version 3 or later) -- see the file LICENSE for details.

Permission is granted to copy, distribute and/or modify this document under the
terms of the GNU Free Documentation License, Version 1.3 or any later version
published by the Free Software Foundation; with no Invariant Sections, no
Front-Cover Texts and no Back-Cover Texts. A copy of the license is included
with the archive as LICENSE.


