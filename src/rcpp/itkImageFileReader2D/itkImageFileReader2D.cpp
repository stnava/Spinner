#include <Rcpp.h>
#include <algorithm>

std::vector< unsigned char > ITKImageFileReader2D( std::string /*input_filename*/ ) ;

RcppExport SEXP itkImageFileReader2D( SEXP __input_filename__ )
{
  return Rcpp::wrap( ITKImageFileReader2D( Rcpp::as< std::string >( __input_filename__ ) ) ) ;
}
