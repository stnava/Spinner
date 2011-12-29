Date: Dec 28, 2011
Author: Shrinidhi KL
Description: Ritk package
Files: Files pertaining to building an R package
Usage:
Follow these steps to build and install Ritk package.

Get into the directory 'src':

$ cd src

Invoke ccmake:

$ ccmake .

and if required, enter locations of ITK build directory, R and Rcpp include
and libraries directory. For R and Rcpp libraries, you may give full path to 
a specific library file instead of giving a directory. This lets you run a 
specific version of library and not the latest. Hit 'configure' and hit 
'generate'. 
This should generate a file named 'Makefile'.
Now go up directories as follows:

$ cd ../..
$ ls
  Ritk ...... other dirs/file ......
  
Build a tarball of the sources using the R convenience command:

$ R CMD build Ritk/

This will build a tarball named 'Ritk_1.0.tar.gz'. Now install the Ritk package
from this tarball as follows:

$ R CMD INSTALL Ritk_1.0.tar.gz

Ritk package is now installed in your R library tree. 

Follow these steps to use the package in R.
Start R.

$ R

Load the package Ritk.

> library( Ritk )

The Rcpp package is also loaded if absent in the memory. Now call any routine in
the namespace 'Ritk'.

> Ritk::itkReadImageFile( "<path-to-ITK>/ITK/Examples/Data/FatMRISlice.png" ) ;

This example program will output a list with first component being an array of 
the image read and second component being a vector of dimensions of the image 
read
