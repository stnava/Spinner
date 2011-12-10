Testing Rcpp. Entry level programs.
---------------------------------------------------------
pingpong.cpp -> answers 'pong' for 'ping' and vice versa

sortVector.cpp -> sorts a given numeric-vector from R
---------------------------------------------------------
Usage:-
First we have to tell R where to find the headers and libraries. 
Run following two lines on Bash:
  export PKG_CPPFLAGS=`Rscript -e 'Rcpp:::CxxFlags()'`
  export PKG_LIBS=`Rscript -e 'Rcpp:::LdFlags()'`
Now compile and build shared libraries from the source by using 
following command.
  R CMD SHLIB <source-file>
  ex: R CMD SHLIB pingpong.cpp
Start R and load the library dynamically as follows.
  dyn.load( "<shared-library-name>" ) ;
  ex: dyn.load( "pingpong.so" ) ;
Call the program as follows.
  .Call( "<program-name>" , <comma-separated-argument-list> ) ;
  ex: .Call( "pingpong" , "ping" ) ;
      .Call( "pingpong" , "pong" ) ;
      .Call( "pingpong" , "random-string" ) ;
      .Call( "sortVector" , c(4,3,2,1) ) ;
