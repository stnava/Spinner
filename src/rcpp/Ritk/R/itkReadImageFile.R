# function wrapper to read an image file
itkReadImageFile <- function( filename ){
	VectorAndDims<-.Call( "itkImageFileReader2D", filename , PACKAGE = "Ritk" ) ;
	dim( VectorAndDims[[1]] ) <- VectorAndDims[[2]] ;
	VectorAndDims ;
}

