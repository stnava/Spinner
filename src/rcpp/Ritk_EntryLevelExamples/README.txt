Date: Dec 25, 2011
Author: ShrinidhiKL
Description: Testing Rcpp. Entry level programs.
---------------------------------------------------------
pingpong.cpp -> answers 'pong' for 'ping' and vice versa

sortVector.cpp -> sorts a given numeric-vector from R

CMakeLists.txt -> use this to build the sources
---------------------------------------------------------
Usage:
In R, install the Rcpp package

   > install.packages('Rcpp')

Now compile the above two files into shared objects in one of two 
following ways.
---------------------------------------------------------
( Method 1 )
First we have to tell R where to find the headers and libraries. 
Run following two lines on :

    $ export PKG_CPPFLAGS=`Rscript -e 'Rcpp:::CxxFlags()'`
    $ export PKG_LIBS=`Rscript -e 'Rcpp:::LdFlags()'`

Now compile and build shared libraries from the source by using 
following command:

	  $ R CMD SHLIB <source-file>
	    ex: R CMD SHLIB pingpong.cpp
---------------------------------------------------------
( Method 2 )
The current directory contains CMakeLists.txt and the source files.
Create a build directory and get into it.

       $ mkdir build
       $ cd build

Invoke cmake gui to configure the Makefile.

       $ ccmake ../

In the gui, set the variables appropriately and configure. Invoke
make to build the shared objects.

     $ make
---------------------------------------------------------
Now that the shared objects have been created, they can be loaded
and called by R.
Start R and load the library dynamically withn R as follows.

      > dyn.load( "<shared-library-name>" ) ;
        ex: dyn.load( "pingpong.so" ) ;

Call the program as follows.
     > .Call( "<program-name>" , <comma-separated-argument-list> ) ;
       ex: .Call( "pingpong" , "ping" ) ;
           .Call( "pingpong" , "pong" ) ;
	   .Call( "pingpong" , "random-string" ) ;
	   .Call( "sortVector" , c(4,3,2,1) ) ;
