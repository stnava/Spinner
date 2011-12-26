#include <Rcpp.h>

RcppExport SEXP pingpong( SEXP __msg__ )
{
  std::string in_msg = Rcpp::as<std::string>( __msg__ ) ;
  std::string out_msg = "only (ping|pong) please" ;
  if( in_msg == "ping" )
    out_msg = "pong" ;
  else if( in_msg == "pong" )
    out_msg = "ping" ;

  return Rcpp::wrap( out_msg ) ;
}
