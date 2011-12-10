#include <Rcpp.h>
#include <algorithm>

RcppExport SEXP sortVector( SEXP __vect__ )
{
  Rcpp::NumericVector in_vector( __vect__ ) ;
  std::sort( in_vector.begin() , in_vector.end() ) ;
  return Rcpp::wrap( in_vector ) ;
}
