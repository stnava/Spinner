#include "itkImage.h"
#include "itkImageRegionIterator.h"
#include "itkImageFileReader.h"
#include "itkImageFileWriter.h"
#include <Rcpp.h>
#include <vector>
#include <string>
#include <iostream>
#include <algorithm>

// function that R wrapper calls to read an image file
RcppExport SEXP itkImageFileReader2D( SEXP __input_filename__ )
{
  std::string input_filename = Rcpp::as< std::string >( __input_filename__ ) ;
  const unsigned int dimension = 2;

  typedef unsigned int PixelType;
  typedef itk::Image< PixelType, dimension > ImageType;

  typedef itk::ImageRegionConstIterator< ImageType > ConstImageIteratorType;
  typedef itk::ImageRegionIterator< ImageType>       ImageIteratorType;

  typedef itk::ImageFileReader< ImageType > ImageFileReaderType;
  typedef itk::ImageFileWriter< ImageType > ImageFileWriterType;

  ImageFileReaderType::Pointer imagefilereader = ImageFileReaderType::New() ;
  imagefilereader->SetFileName( input_filename ) ;
  imagefilereader->Update();

  ConstImageIteratorType input_imageiter( imagefilereader->GetOutput() , imagefilereader->GetOutput()->GetRequestedRegion() ) ;
  std::vector< PixelType > output_imagevector ;

  // fill up the output vector with image pixel values
  for( input_imageiter.GoToBegin() ; !input_imageiter.IsAtEnd() ; ++input_imageiter )
    {
      output_imagevector.push_back( input_imageiter.Get() ) ;
    }

  // return a list containing the image vector and the vector with extents of the dimensions of the image read
  return Rcpp::List::create( Rcpp::wrap( output_imagevector ) , Rcpp::NumericVector::create( imagefilereader->GetOutput()->GetRequestedRegion().GetSize()[0] , imagefilereader->GetOutput()->GetRequestedRegion().GetSize()[1] ) ) ;
}
