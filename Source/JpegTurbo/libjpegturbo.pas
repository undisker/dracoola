{
  Vampyre Imaging Library - LibJpeg-turbo Bindings
  FreePascal bindings for libjpeg-turbo library

  libjpeg-turbo is a JPEG image codec that uses SIMD instructions (MMX, SSE2,
  AVX2, Neon, AltiVec) to accelerate baseline JPEG compression and decompression.

  This unit provides dynamic linking to libjpeg-turbo, which must be available
  at runtime:
    - Windows: jpeg62.dll
    - Linux: libjpeg.so.62
    - macOS: libjpeg.62.dylib

  IMPORTANT: Structure definitions must match JPEG_LIB_VERSION 62.
  On Windows, boolean is unsigned char (1 byte), not int.
}
unit libjpegturbo;

{$I ..\ImagingOptions.inc}

{ Use C record packing to match libjpeg struct layouts }
{$PACKRECORDS C}

interface

uses
  SysUtils, Classes;

const
  { Library names for different platforms }
  {$IFDEF MSWINDOWS}
  LIBJPEG_LIB = 'jpeg62.dll';
  {$ENDIF}
  {$IFDEF LINUX}
  LIBJPEG_LIB = 'libjpeg.so.62';
  {$ENDIF}
  {$IFDEF DARWIN}
  LIBJPEG_LIB = 'libjpeg.62.dylib';
  {$ENDIF}

  { JPEG library version (matches IJG libjpeg 6b API) }
  JPEG_LIB_VERSION = 62;

  { Maximum dimensions supported }
  JPEG_MAX_DIMENSION = 65500;

  { Memory pool IDs }
  JPOOL_PERMANENT = 0;
  JPOOL_IMAGE     = 1;

  { JPEG compression constants }
  DCTSIZE             = 8;    { The basic DCT block is 8x8 samples }
  DCTSIZE2            = 64;   { DCTSIZE squared }
  NUM_QUANT_TBLS      = 4;    { Quantization tables are numbered 0..3 }
  NUM_HUFF_TBLS       = 4;    { Huffman tables are numbered 0..3 }
  NUM_ARITH_TBLS      = 16;   { Arith-coding tables are numbered 0..15 }
  MAX_COMPS_IN_SCAN   = 4;    { JPEG limit on # of components in one scan }
  MAX_SAMP_FACTOR     = 4;    { JPEG limit on sampling factors }
  C_MAX_BLOCKS_IN_MCU = 10;   { Compressor's limit on blocks per MCU }
  D_MAX_BLOCKS_IN_MCU = 10;   { Decompressor's limit on blocks per MCU }

  { Boolean constants for C compatibility }
  CTRUE  = 1;
  CFALSE = 0;

  { Marker codes }
  JPEG_RST0 = $D0;
  JPEG_EOI  = $D9;
  JPEG_APP0 = $E0;
  JPEG_COM  = $FE;

type
  { Basic types matching libjpeg }
  JSAMPLE = Byte;
  JSAMPROW = ^JSAMPLE;
  JSAMPARRAY = ^JSAMPROW;
  JSAMPIMAGE = ^JSAMPARRAY;

  JCOEF = SmallInt;
  JBLOCK = array[0..DCTSIZE2-1] of JCOEF;
  JBLOCKROW = ^JBLOCK;
  JBLOCKARRAY = ^JBLOCKROW;

  JDIMENSION = Cardinal;

  JOCTET = Byte;
  JOCTETPTR = ^JOCTET;

  { Platform-specific boolean type
    On Windows: unsigned char (1 byte)
    On other platforms: int (4 bytes) }
  {$IFDEF MSWINDOWS}
  CBoolean = Byte;
  {$ELSE}
  CBoolean = Integer;
  {$ENDIF}

  { Color space definitions }
  J_COLOR_SPACE = (
    JCS_UNKNOWN,        { error/unspecified }
    JCS_GRAYSCALE,      { monochrome }
    JCS_RGB,            { red/green/blue }
    JCS_YCbCr,          { Y/Cb/Cr (also known as YUV) }
    JCS_CMYK,           { C/M/Y/K }
    JCS_YCCK,           { Y/Cb/Cr/K }
    JCS_EXT_RGB,        { red/green/blue }
    JCS_EXT_RGBX,       { red/green/blue/x }
    JCS_EXT_BGR,        { blue/green/red }
    JCS_EXT_BGRX,       { blue/green/red/x }
    JCS_EXT_XBGR,       { x/blue/green/red }
    JCS_EXT_XRGB,       { x/red/green/blue }
    JCS_EXT_RGBA,       { red/green/blue/alpha }
    JCS_EXT_BGRA,       { blue/green/red/alpha }
    JCS_EXT_ABGR,       { alpha/blue/green/red }
    JCS_EXT_ARGB,       { alpha/red/green/blue }
    JCS_RGB565          { 5-bit red/6-bit green/5-bit blue }
  );

  { DCT/IDCT algorithm options }
  J_DCT_METHOD = (
    JDCT_ISLOW,         { slow but accurate integer algorithm }
    JDCT_IFAST,         { faster, less accurate integer method }
    JDCT_FLOAT          { floating-point: accurate, fast on fast HW }
  );

  { Dithering options }
  J_DITHER_MODE = (
    JDITHER_NONE,       { no dithering }
    JDITHER_ORDERED,    { simple ordered dither }
    JDITHER_FS          { Floyd-Steinberg error diffusion dither }
  );

  { Forward declarations }
  j_common_ptr = ^jpeg_common_struct;
  j_compress_ptr = ^jpeg_compress_struct;
  j_decompress_ptr = ^jpeg_decompress_struct;

  { Error manager structure - must match C struct exactly }
  jpeg_error_mgr = record
    error_exit: procedure(cinfo: j_common_ptr); cdecl;
    emit_message: procedure(cinfo: j_common_ptr; msg_level: Integer); cdecl;
    output_message: procedure(cinfo: j_common_ptr); cdecl;
    format_message: procedure(cinfo: j_common_ptr; buffer: PAnsiChar); cdecl;
    reset_error_mgr: procedure(cinfo: j_common_ptr); cdecl;

    msg_code: Integer;
    msg_parm: record
      case Integer of
        0: (i: array[0..7] of Integer);
        1: (s: array[0..79] of AnsiChar);
    end;

    trace_level: Integer;
    num_warnings: LongInt;

    jpeg_message_table: Pointer;
    last_jpeg_message: Integer;
    addon_message_table: Pointer;
    first_addon_message: Integer;
    last_addon_message: Integer;
  end;
  jpeg_error_mgr_ptr = ^jpeg_error_mgr;

  { Progress monitor structure }
  jpeg_progress_mgr = record
    progress_monitor: procedure(cinfo: j_common_ptr); cdecl;
    pass_counter: LongInt;
    pass_limit: LongInt;
    completed_passes: Integer;
    total_passes: Integer;
  end;
  jpeg_progress_mgr_ptr = ^jpeg_progress_mgr;

  { Memory manager structure }
  jpeg_memory_mgr = record
    alloc_small: function(cinfo: j_common_ptr; pool_id: Integer; sizeofobject: NativeUInt): Pointer; cdecl;
    alloc_large: function(cinfo: j_common_ptr; pool_id: Integer; sizeofobject: NativeUInt): Pointer; cdecl;
    alloc_sarray: function(cinfo: j_common_ptr; pool_id: Integer; samplesperrow: JDIMENSION; numrows: JDIMENSION): JSAMPARRAY; cdecl;
    alloc_barray: function(cinfo: j_common_ptr; pool_id: Integer; blocksperrow: JDIMENSION; numrows: JDIMENSION): JBLOCKARRAY; cdecl;
    request_virt_sarray: Pointer;
    request_virt_barray: Pointer;
    realize_virt_arrays: Pointer;
    access_virt_sarray: Pointer;
    access_virt_barray: Pointer;
    free_pool: procedure(cinfo: j_common_ptr; pool_id: Integer); cdecl;
    self_destruct: procedure(cinfo: j_common_ptr); cdecl;
    max_memory_to_use: LongInt;
    max_alloc_chunk: LongInt;
  end;
  jpeg_memory_mgr_ptr = ^jpeg_memory_mgr;

  { Source manager for decompression }
  jpeg_source_mgr = record
    next_input_byte: JOCTETPTR;
    bytes_in_buffer: NativeUInt;

    init_source: procedure(cinfo: j_decompress_ptr); cdecl;
    fill_input_buffer: function(cinfo: j_decompress_ptr): CBoolean; cdecl;
    skip_input_data: procedure(cinfo: j_decompress_ptr; num_bytes: LongInt); cdecl;
    resync_to_restart: function(cinfo: j_decompress_ptr; desired: Integer): CBoolean; cdecl;
    term_source: procedure(cinfo: j_decompress_ptr); cdecl;
  end;
  jpeg_source_mgr_ptr = ^jpeg_source_mgr;

  { Destination manager for compression }
  jpeg_destination_mgr = record
    next_output_byte: JOCTETPTR;
    free_in_buffer: NativeUInt;

    init_destination: procedure(cinfo: j_compress_ptr); cdecl;
    empty_output_buffer: function(cinfo: j_compress_ptr): CBoolean; cdecl;
    term_destination: procedure(cinfo: j_compress_ptr); cdecl;
  end;
  jpeg_destination_mgr_ptr = ^jpeg_destination_mgr;

  { Component info structure - JPEG_LIB_VERSION 62 layout }
  jpeg_component_info = record
    component_id: Integer;
    component_index: Integer;
    h_samp_factor: Integer;
    v_samp_factor: Integer;
    quant_tbl_no: Integer;
    dc_tbl_no: Integer;
    ac_tbl_no: Integer;
    width_in_blocks: JDIMENSION;
    height_in_blocks: JDIMENSION;
    { Version 62 uses single DCT_scaled_size, not separate h/v }
    DCT_scaled_size: Integer;
    downsampled_width: JDIMENSION;
    downsampled_height: JDIMENSION;
    component_needed: CBoolean;
    MCU_width: Integer;
    MCU_height: Integer;
    MCU_blocks: Integer;
    MCU_sample_width: Integer;
    last_col_width: Integer;
    last_row_height: Integer;
    quant_table: Pointer;
    dct_table: Pointer;
  end;
  jpeg_component_info_ptr = ^jpeg_component_info;

  { Common fields between compress and decompress }
  jpeg_common_struct = record
    err: jpeg_error_mgr_ptr;
    mem: jpeg_memory_mgr_ptr;
    progress: jpeg_progress_mgr_ptr;
    client_data: Pointer;
    is_decompressor: CBoolean;
    global_state: Integer;
  end;

  { Compression structure - JPEG_LIB_VERSION 62 layout }
  jpeg_compress_struct = record
    { Common fields - must match jpeg_common_struct }
    err: jpeg_error_mgr_ptr;
    mem: jpeg_memory_mgr_ptr;
    progress: jpeg_progress_mgr_ptr;
    client_data: Pointer;
    is_decompressor: CBoolean;
    global_state: Integer;

    { Destination for compressed data }
    dest: jpeg_destination_mgr_ptr;

    { Image dimensions and format }
    image_width: JDIMENSION;
    image_height: JDIMENSION;
    input_components: Integer;
    in_color_space: J_COLOR_SPACE;

    { Compression parameters }
    input_gamma: Double;

    { Note: scale_num/scale_denom and jpeg_width/jpeg_height only exist
      in JPEG_LIB_VERSION >= 70, not in 62 }

    data_precision: Integer;
    num_components: Integer;
    jpeg_color_space: J_COLOR_SPACE;
    comp_info: jpeg_component_info_ptr;
    quant_tbl_ptrs: array[0..NUM_QUANT_TBLS-1] of Pointer;
    { Note: q_scale_factor only exists in JPEG_LIB_VERSION >= 70 }
    dc_huff_tbl_ptrs: array[0..NUM_HUFF_TBLS-1] of Pointer;
    ac_huff_tbl_ptrs: array[0..NUM_HUFF_TBLS-1] of Pointer;
    arith_dc_L: array[0..NUM_ARITH_TBLS-1] of Byte;
    arith_dc_U: array[0..NUM_ARITH_TBLS-1] of Byte;
    arith_ac_K: array[0..NUM_ARITH_TBLS-1] of Byte;
    num_scans: Integer;
    scan_info: Pointer;
    raw_data_in: CBoolean;
    arith_code: CBoolean;
    optimize_coding: CBoolean;
    CCIR601_sampling: CBoolean;
    { Note: do_fancy_downsampling only exists in JPEG_LIB_VERSION >= 70 }
    smoothing_factor: Integer;
    dct_method: J_DCT_METHOD;
    restart_interval: Cardinal;
    restart_in_rows: Integer;
    write_JFIF_header: CBoolean;
    JFIF_major_version: Byte;
    JFIF_minor_version: Byte;
    density_unit: Byte;
    X_density: Word;
    Y_density: Word;
    write_Adobe_marker: CBoolean;
    next_scanline: JDIMENSION;
    progressive_mode: CBoolean;
    max_h_samp_factor: Integer;
    max_v_samp_factor: Integer;
    { Note: min_DCT_h_scaled_size/min_DCT_v_scaled_size only exist in >= 70 }
    total_iMCU_rows: JDIMENSION;
    comps_in_scan: Integer;
    cur_comp_info: array[0..MAX_COMPS_IN_SCAN-1] of jpeg_component_info_ptr;
    MCUs_per_row: JDIMENSION;
    MCU_rows_in_scan: JDIMENSION;
    blocks_in_MCU: Integer;
    MCU_membership: array[0..C_MAX_BLOCKS_IN_MCU-1] of Integer;
    Ss: Integer;
    Se: Integer;
    Ah: Integer;
    Al: Integer;
    { Note: block_size, natural_order, lim_Se only exist in >= 80 }
    { Module pointers }
    master: Pointer;
    main: Pointer;
    prep: Pointer;
    coef: Pointer;
    marker: Pointer;
    cconvert: Pointer;
    downsample: Pointer;
    fdct: Pointer;
    entropy: Pointer;
    script_space: Pointer;
    script_space_size: Integer;
  end;

  { Decompression structure - JPEG_LIB_VERSION 62 layout }
  jpeg_decompress_struct = record
    { Common fields - must match jpeg_common_struct }
    err: jpeg_error_mgr_ptr;
    mem: jpeg_memory_mgr_ptr;
    progress: jpeg_progress_mgr_ptr;
    client_data: Pointer;
    is_decompressor: CBoolean;
    global_state: Integer;

    { Source for compressed data }
    src: jpeg_source_mgr_ptr;

    { Image dimensions from JPEG header }
    image_width: JDIMENSION;
    image_height: JDIMENSION;
    num_components: Integer;
    jpeg_color_space: J_COLOR_SPACE;

    { Decompression parameters }
    out_color_space: J_COLOR_SPACE;
    scale_num: Cardinal;
    scale_denom: Cardinal;
    output_gamma: Double;
    buffered_image: CBoolean;
    raw_data_out: CBoolean;
    dct_method: J_DCT_METHOD;
    do_fancy_upsampling: CBoolean;
    do_block_smoothing: CBoolean;
    quantize_colors: CBoolean;
    dither_mode: J_DITHER_MODE;
    two_pass_quantize: CBoolean;
    desired_number_of_colors: Integer;
    enable_1pass_quant: CBoolean;
    enable_external_quant: CBoolean;
    enable_2pass_quant: CBoolean;

    { Output dimensions }
    output_width: JDIMENSION;
    output_height: JDIMENSION;
    out_color_components: Integer;
    output_components: Integer;
    rec_outbuf_height: Integer;

    { Colormap (if quantizing) }
    actual_number_of_colors: Integer;
    colormap: JSAMPARRAY;

    { Scan processing state }
    output_scanline: JDIMENSION;
    input_scan_number: Integer;
    input_iMCU_row: JDIMENSION;
    output_scan_number: Integer;
    output_iMCU_row: JDIMENSION;
    coef_bits: Pointer;
    quant_tbl_ptrs: array[0..NUM_QUANT_TBLS-1] of Pointer;
    dc_huff_tbl_ptrs: array[0..NUM_HUFF_TBLS-1] of Pointer;
    ac_huff_tbl_ptrs: array[0..NUM_HUFF_TBLS-1] of Pointer;

    { Internal data precision }
    data_precision: Integer;
    comp_info: jpeg_component_info_ptr;

    { Progressive mode info }
    { Note: is_baseline only exists in >= 80 }
    progressive_mode: CBoolean;
    arith_code: CBoolean;
    arith_dc_L: array[0..NUM_ARITH_TBLS-1] of Byte;
    arith_dc_U: array[0..NUM_ARITH_TBLS-1] of Byte;
    arith_ac_K: array[0..NUM_ARITH_TBLS-1] of Byte;
    restart_interval: Cardinal;

    { Markers detected }
    saw_JFIF_marker: CBoolean;
    JFIF_major_version: Byte;
    JFIF_minor_version: Byte;
    density_unit: Byte;
    X_density: Word;
    Y_density: Word;
    saw_Adobe_marker: CBoolean;
    Adobe_transform: Byte;

    CCIR601_sampling: CBoolean;
    marker_list: Pointer;

    { Sampling factors }
    max_h_samp_factor: Integer;
    max_v_samp_factor: Integer;
    { Version 62 uses single min_DCT_scaled_size }
    min_DCT_scaled_size: Integer;
    total_iMCU_rows: JDIMENSION;
    sample_range_limit: Pointer;

    { Current scan info }
    comps_in_scan: Integer;
    cur_comp_info: array[0..MAX_COMPS_IN_SCAN-1] of jpeg_component_info_ptr;
    MCUs_per_row: JDIMENSION;
    MCU_rows_in_scan: JDIMENSION;
    blocks_in_MCU: Integer;
    MCU_membership: array[0..D_MAX_BLOCKS_IN_MCU-1] of Integer;

    { Spectral selection }
    Ss: Integer;
    Se: Integer;
    Ah: Integer;
    Al: Integer;

    { Note: block_size, natural_order, lim_Se only exist in >= 80 }

    { Unread marker code }
    unread_marker: Integer;

    { Module pointers }
    master: Pointer;
    main: Pointer;
    coef: Pointer;
    post: Pointer;
    inputctl: Pointer;
    marker: Pointer;
    entropy: Pointer;
    idct: Pointer;
    upsample: Pointer;
    cconvert: Pointer;
    cquantize: Pointer;
  end;

{ Library loading and initialization }
{ Why the libjpeg library could not be loaded - '' while it is fine. }
function JpegLoadError: string;

function LoadJpegLibrary: Boolean;
procedure UnloadJpegLibrary;
function IsJpegLibraryLoaded: Boolean;

{ Error handling }
function jpeg_std_error(var err: jpeg_error_mgr): jpeg_error_mgr_ptr; cdecl;

{ Compression functions }
procedure jpeg_CreateCompress(cinfo: j_compress_ptr; version: Integer; structsize: NativeUInt); cdecl;
procedure jpeg_destroy_compress(cinfo: j_compress_ptr); cdecl;
procedure jpeg_set_defaults(cinfo: j_compress_ptr); cdecl;
procedure jpeg_set_colorspace(cinfo: j_compress_ptr; colorspace: J_COLOR_SPACE); cdecl;
procedure jpeg_set_quality(cinfo: j_compress_ptr; quality: Integer; force_baseline: CBoolean); cdecl;
procedure jpeg_simple_progression(cinfo: j_compress_ptr); cdecl;
procedure jpeg_start_compress(cinfo: j_compress_ptr; write_all_tables: CBoolean); cdecl;
function jpeg_write_scanlines(cinfo: j_compress_ptr; scanlines: JSAMPARRAY; num_lines: JDIMENSION): JDIMENSION; cdecl;
procedure jpeg_finish_compress(cinfo: j_compress_ptr); cdecl;

{ Decompression functions }
procedure jpeg_CreateDecompress(cinfo: j_decompress_ptr; version: Integer; structsize: NativeUInt); cdecl;
procedure jpeg_destroy_decompress(cinfo: j_decompress_ptr); cdecl;
function jpeg_read_header(cinfo: j_decompress_ptr; require_image: CBoolean): Integer; cdecl;
function jpeg_start_decompress(cinfo: j_decompress_ptr): CBoolean; cdecl;
function jpeg_read_scanlines(cinfo: j_decompress_ptr; scanlines: JSAMPARRAY; max_lines: JDIMENSION): JDIMENSION; cdecl;
function jpeg_finish_decompress(cinfo: j_decompress_ptr): CBoolean; cdecl;
function jpeg_finish_output(cinfo: j_decompress_ptr): CBoolean; cdecl;
function jpeg_resync_to_restart(cinfo: j_decompress_ptr; desired: Integer): CBoolean; cdecl;

{ Common functions }
procedure jpeg_destroy(cinfo: j_common_ptr); cdecl;

implementation

uses
  dynlibs{$IFDEF MSWINDOWS}, Windows{$ENDIF};

var
  JpegLibHandle: TLibHandle = NilHandle;
  GJpegLoadError: string = '';

  { Function pointers }
  _jpeg_std_error: function(var err: jpeg_error_mgr): jpeg_error_mgr_ptr; cdecl;
  _jpeg_CreateCompress: procedure(cinfo: j_compress_ptr; version: Integer; structsize: NativeUInt); cdecl;
  _jpeg_destroy_compress: procedure(cinfo: j_compress_ptr); cdecl;
  _jpeg_set_defaults: procedure(cinfo: j_compress_ptr); cdecl;
  _jpeg_set_colorspace: procedure(cinfo: j_compress_ptr; colorspace: J_COLOR_SPACE); cdecl;
  _jpeg_set_quality: procedure(cinfo: j_compress_ptr; quality: Integer; force_baseline: CBoolean); cdecl;
  _jpeg_simple_progression: procedure(cinfo: j_compress_ptr); cdecl;
  _jpeg_start_compress: procedure(cinfo: j_compress_ptr; write_all_tables: CBoolean); cdecl;
  _jpeg_write_scanlines: function(cinfo: j_compress_ptr; scanlines: JSAMPARRAY; num_lines: JDIMENSION): JDIMENSION; cdecl;
  _jpeg_finish_compress: procedure(cinfo: j_compress_ptr); cdecl;
  _jpeg_CreateDecompress: procedure(cinfo: j_decompress_ptr; version: Integer; structsize: NativeUInt); cdecl;
  _jpeg_destroy_decompress: procedure(cinfo: j_decompress_ptr); cdecl;
  _jpeg_read_header: function(cinfo: j_decompress_ptr; require_image: CBoolean): Integer; cdecl;
  _jpeg_start_decompress: function(cinfo: j_decompress_ptr): CBoolean; cdecl;
  _jpeg_read_scanlines: function(cinfo: j_decompress_ptr; scanlines: JSAMPARRAY; max_lines: JDIMENSION): JDIMENSION; cdecl;
  _jpeg_finish_decompress: function(cinfo: j_decompress_ptr): CBoolean; cdecl;
  _jpeg_finish_output: function(cinfo: j_decompress_ptr): CBoolean; cdecl;
  _jpeg_resync_to_restart: function(cinfo: j_decompress_ptr; desired: Integer): CBoolean; cdecl;
  _jpeg_destroy: procedure(cinfo: j_common_ptr); cdecl;

{$I ../libloaderror.inc}

function LoadJpegLibrary: Boolean;
begin
  if JpegLibHandle <> NilHandle then
  begin
    Result := True;
    Exit;
  end;

  JpegLibHandle := LoadLibrary(LIBJPEG_LIB);
  if JpegLibHandle = NilHandle then
  begin
    GJpegLoadError := DescribeLibLoadFailure(LIBJPEG_LIB);
    Result := False;
    Exit;
  end;

  @_jpeg_std_error := GetProcAddress(JpegLibHandle, 'jpeg_std_error');
  @_jpeg_CreateCompress := GetProcAddress(JpegLibHandle, 'jpeg_CreateCompress');
  @_jpeg_destroy_compress := GetProcAddress(JpegLibHandle, 'jpeg_destroy_compress');
  @_jpeg_set_defaults := GetProcAddress(JpegLibHandle, 'jpeg_set_defaults');
  @_jpeg_set_colorspace := GetProcAddress(JpegLibHandle, 'jpeg_set_colorspace');
  @_jpeg_set_quality := GetProcAddress(JpegLibHandle, 'jpeg_set_quality');
  @_jpeg_simple_progression := GetProcAddress(JpegLibHandle, 'jpeg_simple_progression');
  @_jpeg_start_compress := GetProcAddress(JpegLibHandle, 'jpeg_start_compress');
  @_jpeg_write_scanlines := GetProcAddress(JpegLibHandle, 'jpeg_write_scanlines');
  @_jpeg_finish_compress := GetProcAddress(JpegLibHandle, 'jpeg_finish_compress');
  @_jpeg_CreateDecompress := GetProcAddress(JpegLibHandle, 'jpeg_CreateDecompress');
  @_jpeg_destroy_decompress := GetProcAddress(JpegLibHandle, 'jpeg_destroy_decompress');
  @_jpeg_read_header := GetProcAddress(JpegLibHandle, 'jpeg_read_header');
  @_jpeg_start_decompress := GetProcAddress(JpegLibHandle, 'jpeg_start_decompress');
  @_jpeg_read_scanlines := GetProcAddress(JpegLibHandle, 'jpeg_read_scanlines');
  @_jpeg_finish_decompress := GetProcAddress(JpegLibHandle, 'jpeg_finish_decompress');
  @_jpeg_finish_output := GetProcAddress(JpegLibHandle, 'jpeg_finish_output');
  @_jpeg_resync_to_restart := GetProcAddress(JpegLibHandle, 'jpeg_resync_to_restart');
  @_jpeg_destroy := GetProcAddress(JpegLibHandle, 'jpeg_destroy');

  { Check if all essential functions were loaded }
  Result := Assigned(_jpeg_std_error) and
            Assigned(_jpeg_CreateCompress) and
            Assigned(_jpeg_CreateDecompress) and
            Assigned(_jpeg_read_header) and
            Assigned(_jpeg_start_decompress) and
            Assigned(_jpeg_read_scanlines) and
            Assigned(_jpeg_write_scanlines);

  if not Result then
    UnloadJpegLibrary;
end;

procedure UnloadJpegLibrary;
begin
  if JpegLibHandle <> NilHandle then
  begin
    FreeLibrary(JpegLibHandle);
    JpegLibHandle := NilHandle;
  end;

  @_jpeg_std_error := nil;
  @_jpeg_CreateCompress := nil;
  @_jpeg_destroy_compress := nil;
  @_jpeg_set_defaults := nil;
  @_jpeg_set_colorspace := nil;
  @_jpeg_set_quality := nil;
  @_jpeg_simple_progression := nil;
  @_jpeg_start_compress := nil;
  @_jpeg_write_scanlines := nil;
  @_jpeg_finish_compress := nil;
  @_jpeg_CreateDecompress := nil;
  @_jpeg_destroy_decompress := nil;
  @_jpeg_read_header := nil;
  @_jpeg_start_decompress := nil;
  @_jpeg_read_scanlines := nil;
  @_jpeg_finish_decompress := nil;
  @_jpeg_finish_output := nil;
  @_jpeg_resync_to_restart := nil;
  @_jpeg_destroy := nil;
end;

function IsJpegLibraryLoaded: Boolean;
begin
  Result := JpegLibHandle <> NilHandle;
end;

{ Wrapper functions }

function jpeg_std_error(var err: jpeg_error_mgr): jpeg_error_mgr_ptr; cdecl;
begin
  if Assigned(_jpeg_std_error) then
    Result := _jpeg_std_error(err)
  else
    Result := nil;
end;

procedure jpeg_CreateCompress(cinfo: j_compress_ptr; version: Integer; structsize: NativeUInt); cdecl;
begin
  if Assigned(_jpeg_CreateCompress) then
    _jpeg_CreateCompress(cinfo, version, structsize);
end;

procedure jpeg_destroy_compress(cinfo: j_compress_ptr); cdecl;
begin
  if Assigned(_jpeg_destroy_compress) then
    _jpeg_destroy_compress(cinfo);
end;

procedure jpeg_set_defaults(cinfo: j_compress_ptr); cdecl;
begin
  if Assigned(_jpeg_set_defaults) then
    _jpeg_set_defaults(cinfo);
end;

procedure jpeg_set_colorspace(cinfo: j_compress_ptr; colorspace: J_COLOR_SPACE); cdecl;
begin
  if Assigned(_jpeg_set_colorspace) then
    _jpeg_set_colorspace(cinfo, colorspace);
end;

procedure jpeg_set_quality(cinfo: j_compress_ptr; quality: Integer; force_baseline: CBoolean); cdecl;
begin
  if Assigned(_jpeg_set_quality) then
    _jpeg_set_quality(cinfo, quality, force_baseline);
end;

procedure jpeg_simple_progression(cinfo: j_compress_ptr); cdecl;
begin
  if Assigned(_jpeg_simple_progression) then
    _jpeg_simple_progression(cinfo);
end;

procedure jpeg_start_compress(cinfo: j_compress_ptr; write_all_tables: CBoolean); cdecl;
begin
  if Assigned(_jpeg_start_compress) then
    _jpeg_start_compress(cinfo, write_all_tables);
end;

function jpeg_write_scanlines(cinfo: j_compress_ptr; scanlines: JSAMPARRAY; num_lines: JDIMENSION): JDIMENSION; cdecl;
begin
  if Assigned(_jpeg_write_scanlines) then
    Result := _jpeg_write_scanlines(cinfo, scanlines, num_lines)
  else
    Result := 0;
end;

procedure jpeg_finish_compress(cinfo: j_compress_ptr); cdecl;
begin
  if Assigned(_jpeg_finish_compress) then
    _jpeg_finish_compress(cinfo);
end;

procedure jpeg_CreateDecompress(cinfo: j_decompress_ptr; version: Integer; structsize: NativeUInt); cdecl;
begin
  if Assigned(_jpeg_CreateDecompress) then
    _jpeg_CreateDecompress(cinfo, version, structsize);
end;

procedure jpeg_destroy_decompress(cinfo: j_decompress_ptr); cdecl;
begin
  if Assigned(_jpeg_destroy_decompress) then
    _jpeg_destroy_decompress(cinfo);
end;

function jpeg_read_header(cinfo: j_decompress_ptr; require_image: CBoolean): Integer; cdecl;
begin
  if Assigned(_jpeg_read_header) then
    Result := _jpeg_read_header(cinfo, require_image)
  else
    Result := -1;
end;

function jpeg_start_decompress(cinfo: j_decompress_ptr): CBoolean; cdecl;
begin
  if Assigned(_jpeg_start_decompress) then
    Result := _jpeg_start_decompress(cinfo)
  else
    Result := CFALSE;
end;

function jpeg_read_scanlines(cinfo: j_decompress_ptr; scanlines: JSAMPARRAY; max_lines: JDIMENSION): JDIMENSION; cdecl;
begin
  if Assigned(_jpeg_read_scanlines) then
    Result := _jpeg_read_scanlines(cinfo, scanlines, max_lines)
  else
    Result := 0;
end;

function jpeg_finish_decompress(cinfo: j_decompress_ptr): CBoolean; cdecl;
begin
  if Assigned(_jpeg_finish_decompress) then
    Result := _jpeg_finish_decompress(cinfo)
  else
    Result := CFALSE;
end;

function jpeg_finish_output(cinfo: j_decompress_ptr): CBoolean; cdecl;
begin
  if Assigned(_jpeg_finish_output) then
    Result := _jpeg_finish_output(cinfo)
  else
    Result := CFALSE;
end;

function jpeg_resync_to_restart(cinfo: j_decompress_ptr; desired: Integer): CBoolean; cdecl;
begin
  if Assigned(_jpeg_resync_to_restart) then
    Result := _jpeg_resync_to_restart(cinfo, desired)
  else
    Result := CFALSE;
end;

procedure jpeg_destroy(cinfo: j_common_ptr); cdecl;
begin
  if Assigned(_jpeg_destroy) then
    _jpeg_destroy(cinfo);
end;

function JpegLoadError: string;
begin
  Result := GJpegLoadError;
end;

initialization
  LoadJpegLibrary;

finalization
  UnloadJpegLibrary;


end.
