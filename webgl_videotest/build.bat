@REM -O0 -s ASSERTIONS=1 -s DEMANGLE_SUPPORT=1
@REM -O2 -s ASSERTIONS=0
emcc -s EXPORTED_FUNCTIONS="['allocate', '_malloc', '_free', '_basis_init','_basis_open','_basis_close','_basis_get_has_alpha','_basis_get_num_images','_basis_get_num_levels','_basis_get_image_width','_basis_get_image_height','_basis_get_image_transcoded_size_in_bytes','_basis_transcode_image','_basis_start_transcoding','_basis_get_debug_flags','_basis_set_debug_flags']" -o basis.js ../transcoder/basisu_transcoder.cpp basis_wrappers.cpp -s TOTAL_MEMORY=80000000 -O2 -s ASSERTIONS=0 -I ../transcoder
