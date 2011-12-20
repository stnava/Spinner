#include "itkImage.h"
#include "itkImageRegionIterator.h"
#include "itkImageFileReader.h"
#include "itkImageFileWriter.h"
// #include <Rcpp.h>
#include <vector>
#include <string>
#include <iostream>

std::vector< unsigned char > ITKImageFileReader2D( std::string input_filename )
{
  const unsigned int dimension = 2;

  typedef int PixelType;
  typedef itk::Image< PixelType, dimension > ImageType;

  typedef itk::ImageRegionConstIterator< ImageType > ConstImageIteratorType;
  typedef itk::ImageRegionIterator< ImageType>       ImageIteratorType;

  typedef itk::ImageFileReader< ImageType > ImageFileReaderType;
  typedef itk::ImageFileWriter< ImageType > ImageFileWriterType;

  ImageFileReaderType::Pointer imagefilereader = ImageFileReaderType::New() ;
  imagefilereader->SetFileName( input_filename ) ;
  imagefilereader->Update();

  ConstImageIteratorType input_imageiter( imagefilereader->GetOutput() , imagefilereader->GetOutput()->GetRequestedRegion() ) ;
  std::vector< unsigned char > output_imagevector ;

  for( input_imageiter.GoToBegin() ; !input_imageiter.IsAtEnd() ; ++input_imageiter )
    {
      output_imagevector.push_back( input_imageiter.Get() ) ;
    }

  return output_imagevector ;
}

// RcppExport SEXP itkImageFileReader2D( SEXP __input_filename__ )
// {
//   return Rcpp::wrap( ITKImageFileReader2D( Rcpp::as< std::string >( __input_filename__ ) ) ) ;
// }

