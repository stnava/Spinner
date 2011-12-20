cmake_minimum_required(VERSION 2.8)

find_package(ITK REQUIRED)
include(${ITK_USE_FILE})

project(ITKImageFileReader)

add_library( ITKImageFileReader2D SHARED ITKImageFileReader2D.cxx )
target_link_libraries( ITKImageFileReader2D ${ITK_LIBRARIES} )