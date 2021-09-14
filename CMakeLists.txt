cmake_minimum_required(VERSION 3.0)
project(basisu)

if(POLICY CMP0063)
	cmake_policy(SET CMP0063 NEW)
endif()

option(BASISU_SILENT_BUILD "Do not print out selected options" FALSE)
option(BASISU_BUILD_X86 "build 32-bit" FALSE)
option(BASISU_USE_SSE4 "SSE 4.1 support" FALSE)
option(BASISU_USE_ZSTD "ZSTD support for KTX2 transcoding/encoding" TRUE)
option(BASISU_BUILD_ENCODER "Build also encoder part of basis library" TRUE)
option(BASISU_BUILD_EXECUTABLE "Build basisu executable tool" TRUE)
option(BASISU_BUILD_LIBRARY "Build basisu library with mode defined using BUILD_SHARED_LIBS" FALSE)

if ((NOT BASISU_BUILD_LIBRARY AND NOT BASISU_BUILD_EXECUTABLE) OR (BASISU_BUILD_LIBRARY AND BASISU_BUILD_EXECUTABLE))
	set(BASISU_BUILD_EXECUTABLE TRUE)
	set(BASISU_BUILD_LIBRARY FALSE)
endif()

if (BASISU_BUILD_EXECUTABLE)
	set(BASISU_BUILD_ENCODER TRUE)
endif()

if (NOT CMAKE_BUILD_TYPE)
	set(CMAKE_BUILD_TYPE Release)
endif()

if (NOT BASISU_SILENT_BUILD)
	message(STATUS ${PROJECT_NAME} ", build type: " ${CMAKE_BUILD_TYPE} ", shared: " ${BUILD_SHARED_LIBS} )

	if (NOT BASISU_BUILD_X86)
		message(STATUS "Building 64-bit")
	else()
		message(STATUS "Building 32-bit")
	endif()

	if (BASISU_USE_SSE4)
		message(STATUS "SSE4.1 enabled")
	else()
		message(STATUS "SSE4.1 disabled")
	endif()

	if (BASISU_USE_ZSTD)
		message(STATUS "Zstandard enabled")
	else()
		message(STATUS "Zstandard disabled")
	endif()

	if (BASISU_BUILD_EXECUTABLE)
		message(STATUS "Building basisu tool")
	endif()
	
	if (BASISU_BUILD_LIBRARY)
		if (BUILD_ENCODER)
			message(STATUS "Building whole basisu library")
		else()
			message(STATUS "Building only transcoder part of basisu library")
		endif()
	endif()
endif()

set(BASISU_ENCODER_SRC_LIST
	encoder/basisu_backend.cpp
	encoder/basisu_basis_file.cpp
	encoder/basisu_comp.cpp
	encoder/basisu_enc.cpp
	encoder/basisu_etc.cpp
	encoder/basisu_frontend.cpp
	encoder/basisu_global_selector_palette_helpers.cpp
	encoder/basisu_gpu_texture.cpp
	encoder/basisu_pvrtc1_4.cpp
	encoder/basisu_resampler.cpp
	encoder/basisu_resample_filters.cpp
	encoder/basisu_ssim.cpp
	encoder/basisu_astc_decomp.cpp
	encoder/basisu_uastc_enc.cpp
	encoder/basisu_bc7enc.cpp
	encoder/lodepng.cpp
	encoder/apg_bmp.c
	encoder/jpgd.cpp
	encoder/basisu_kernels_sse.cpp
)

set(BASISU_SRC_LIST
	${COMMON_SRC_LIST} 
	transcoder/basisu_transcoder.cpp
)

if (BASISU_BUILD_ENCODER)
	set(BASISU_SRC_LIST ${BASISU_SRC_LIST} ${BASISU_ENCODER_SRC_LIST})
endif()

if (BASISU_BUILD_EXECUTABLE)
	set(BASISU_SRC_LIST ${BASISU_SRC_LIST} basisu_tool.cpp)
endif()

if (BASISU_USE_ZSTD)
	set(BASISU_SRC_LIST ${BASISU_SRC_LIST} zstd/zstd.c)
endif()

if (BASISU_BUILD_LIBRARY)
	add_library(${PROJECT_NAME} ${BASISU_SRC_LIST})
endif()

if (BASISU_BUILD_EXECUTABLE)
	add_executable(${PROJECT_NAME} ${BASISU_SRC_LIST})
endif()

target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_11)

if (CMAKE_BUILD_TYPE STREQUAL "Debug")
	target_compile_definitions(${PROJECT_NAME} PUBLIC -D_DEBUG)
	target_compile_options(${PROJECT_NAME} PRIVATE
		$<$<CXX_COMPILER_ID:MSVC>:/Zi>
		$<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-g>
	)
endif()

if (BASISU_USE_SSE4 AND NOT EMSCRIPTEN)
	target_compile_definitions(${PROJECT_NAME} PRIVATE BASISU_SUPPORT_SSE=1)
else()
	target_compile_definitions(${PROJECT_NAME} PRIVATE BASISU_SUPPORT_SSE=0)
endif()

if (EMSCRIPTEN)
	target_compile_definitions(${PROJECT_NAME} PRIVATE ALLOW_MEMORY_GROWTH=1)
	target_link_options(${PROJECT_NAME} PRIVATE -s)
elseif(NOT MSVC)
	if (BASISU_BUILD_X86)
		target_compile_options(${PROJECT_NAME} PUBLIC -m32)
	endif()

	if (BASISU_USE_SSE4)
		target_compile_options(${PROJECT_NAME} PUBLIC -msse4.1)
	endif()

	if (BUILD_SHARED_LIBS)
		set_property(TARGET ${PROJECT_NAME} PROPERTY POSITION_INDEPENDENT_CODE ON)
	endif()

	set_target_properties(${PROJECT_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)

	target_compile_definitions(${PROJECT_NAME}
		PRIVATE -D_LARGEFILE64_SOURCE=1
		PRIVATE -D_FILE_OFFSET_BITS=64
	)

	target_compile_options(${PROJECT_NAME}
		PUBLIC -fno-strict-aliasing -Wall -Wextra -Wno-unused-local-typedefs -Wno-unused-value -Wno-unused-parameter -Wno-unused-variable
	)  	

	if (BASISU_BUILD_EXECUTABLE)
	  	if (NOT BUILD_SHARED_LIBS)
	  		set(CMAKE_EXE_LINKER_FLAGS  "${CMAKE_EXE_LINKER_FLAGS} ${GCC_LINK_FLAGS} -static-libgcc -static-libstdc++ -static")
		else()
			set(CMAKE_EXE_LINKER_FLAGS  "${CMAKE_EXE_LINKER_FLAGS} ${GCC_LINK_FLAGS} -Wl,-rpath .")
		endif()
	endif()
endif()

if (APPLE)
   set(BIN_DIRECTORY "bin_osx")
else()
   set(BIN_DIRECTORY "bin")
endif()

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/${BIN_DIRECTORY})

if (BASISU_USE_ZSTD)
	target_compile_definitions(${PROJECT_NAME} PRIVATE BASISD_SUPPORT_KTX2_ZSTD=1)
else()
	target_compile_definitions(${PROJECT_NAME} PRIVATE BASISD_SUPPORT_KTX2_ZSTD=0)
endif()

if (NOT MSVC)
   target_link_libraries(${PROJECT_NAME} m pthread)
endif()

if (NOT EMSCRIPTEN AND BASISU_BUILD_EXECUTABLE)
	install(TARGETS ${PROJECT_NAME} DESTINATION bin)
	
	if (UNIX)
		if (CMAKE_BUILD_TYPE STREQUAL Release)
			if (APPLE)
				add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD COMMAND strip -X -x ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${PROJECT_NAME})
			else()
				add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD COMMAND strip -g -X -x ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${PROJECT_NAME})
			endif()
		endif()
	endif()
endif()
