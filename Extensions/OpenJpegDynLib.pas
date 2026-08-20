{
  Dracoola Imaging Library
  by Marek Mauder
  https://github.com/galfar/imaginglib
  https://imaginglib.sourceforge.io
  - - - - -
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0.
}

{ OpenJPEG dynamic library bindings for JPEG 2000 support.
  Uses OpenJPEG 2.x API via dynamic library loading.

  Supported platforms:
    Windows x64: openjp2.dll
    Linux x64: libopenjp2.so.7 or libopenjp2.so
    macOS x64/ARM64: libopenjp2.7.dylib or libopenjp2.dylib
}

unit OpenJpegDynLib;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
{$IFDEF MSWINDOWS}
  Windows,
{$ENDIF}
  SysUtils;

const
  OPENJPEG_VERSION = '2.5.0';

type
  OPJ_BOOL = LongBool;
  OPJ_CHAR = AnsiChar;
  OPJ_FLOAT32 = Single;
  OPJ_FLOAT64 = Double;
  OPJ_BYTE = Byte;
  POPJ_BYTE = ^OPJ_BYTE;
  OPJ_INT8 = ShortInt;
  OPJ_UINT8 = Byte;
  OPJ_INT16 = SmallInt;
  OPJ_UINT16 = Word;
  OPJ_INT32 = LongInt;
  OPJ_UINT32 = LongWord;
  OPJ_INT64 = Int64;
  OPJ_UINT64 = UInt64;
  OPJ_OFF_T = Int64;
  OPJ_SIZE_T = NativeUInt;

{ Constant Definitions }

const
  OPJ_PATH_LEN = 4096;
  OPJ_J2K_MAXRLVLS = 33;
  OPJ_J2K_MAXBANDS = 3 * OPJ_J2K_MAXRLVLS - 2;

  OPJ_TRUE = OPJ_BOOL(True);
  OPJ_FALSE = OPJ_BOOL(False);

  OPJ_J2K_STREAM_CHUNK_SIZE = $100000;
  OPJ_J2K_DEFAULT_NB_SEGS = 10;
  OPJ_J2K_DEFAULT_CBLK_DATA_SIZE = 8192;

{ Library names }
const
{$IF Defined(MSWINDOWS)}
  SLibName = 'openjp2.dll';
  SLibNameAlt = 'libopenjp2.dll';
{$ELSEIF Defined(DARWIN)}
  SLibName = 'libopenjp2.7.dylib';
  SLibNameAlt = 'libopenjp2.dylib';
{$ELSE}
  SLibName = 'libopenjp2.so.7';
  SLibNameAlt = 'libopenjp2.so';
{$IFEND}

{ Enum Definitions }

type
  { Rsiz capabilities }
  OPJ_RSIZ_CAPABILITIES = (
    OPJ_STD_RSIZ = 0,
    OPJ_CINEMA2K = 3,
    OPJ_CINEMA4K = 4,
    OPJ_MCT = $8100
  );

  { Progression order }
  OPJ_PROG_ORDER = (
    OPJ_PROG_UNKNOWN = -1,
    OPJ_LRCP = 0,
    OPJ_RLCP = 1,
    OPJ_RPCL = 2,
    OPJ_PCRL = 3,
    OPJ_CPRL = 4
  );

  { Supported image color spaces }
  OPJ_COLOR_SPACE = (
    OPJ_CLRSPC_UNKNOWN = -1,
    OPJ_CLRSPC_UNSPECIFIED = 0,
    OPJ_CLRSPC_SRGB = 1,
    OPJ_CLRSPC_GRAY = 2,
    OPJ_CLRSPC_SYCC = 3,
    OPJ_CLRSPC_EYCC = 4,
    OPJ_CLRSPC_CMYK = 5
  );
  TOpjColorSpace = OPJ_COLOR_SPACE;

  { Supported codec }
  OPJ_CODEC_FORMAT = (
    OPJ_CODEC_UNKNOWN = -1,
    OPJ_CODEC_J2K = 0,
    OPJ_CODEC_JPT = 1,
    OPJ_CODEC_JP2 = 2,
    OPJ_CODEC_JPP = 3,
    OPJ_CODEC_JPX = 4
  );

{ Codec Type Definitions }

type
  opj_codec_t = Pointer;
  opj_stream_t = Pointer;

  { Progression order changes }
  popj_poc = ^opj_poc;
  opj_poc = record
    resno0, compno0: OPJ_UINT32;
    layno1, resno1, compno1: OPJ_UINT32;
    layno0, precno0, precno1: OPJ_UINT32;
    prg1, prg: OPJ_PROG_ORDER;
    progorder: array[0..4] of OPJ_CHAR;
    tile: OPJ_UINT32;
    tx0, tx1, ty0, ty1: OPJ_INT32;
    layS, resS, compS, prcS: OPJ_UINT32;
    layE, resE, compE, prcE: OPJ_UINT32;
    txS, txE, tyS, tyE, dx, dy: OPJ_UINT32;
    lay_t, res_t, comp_t, prc_t, tx0_t, ty0_t: OPJ_UINT32;
  end;
  opj_poc_t = opj_poc;

  { Compression parameters }
  popj_cparameters = ^opj_cparameters;
  opj_cparameters = record
    tile_size_on: OPJ_BOOL;
    cp_tx0: Integer;
    cp_ty0: Integer;
    cp_tdx: Integer;
    cp_tdy: Integer;
    cp_disto_alloc: Integer;
    cp_fixed_alloc: Integer;
    cp_fixed_quality: Integer;
    cp_matrice: PInteger;
    cp_comment: PAnsiChar;
    csty: Integer;
    prog_order: OPJ_PROG_ORDER;
    POC: array[0..31] of opj_poc_t;
    numpocs: OPJ_UINT32;
    tcp_numlayers: Integer;
    tcp_rates: array[0..99] of Single;
    tcp_distoratio: array[0..99] of Single;
    numresolution: Integer;
    cblockw_init: Integer;
    cblockh_init: Integer;
    mode: Integer;
    irreversible: Integer;
    roi_compno: Integer;
    roi_shift: Integer;
    res_spec: Integer;
    prcw_init: array[0..OPJ_J2K_MAXRLVLS - 1] of Integer;
    prch_init: array[0..OPJ_J2K_MAXRLVLS - 1] of Integer;
    infile: array[0..OPJ_PATH_LEN - 1] of OPJ_CHAR;
    outfile: array[0..OPJ_PATH_LEN - 1] of OPJ_CHAR;
    index_on: Integer;
    index: array[0..OPJ_PATH_LEN - 1] of OPJ_CHAR;
    image_offset_x0: Integer;
    image_offset_y0: Integer;
    subsampling_dx: Integer;
    subsampling_dy: Integer;
    decod_format: Integer;
    cod_format: Integer;
    jpwl_epc_on: OPJ_BOOL;
    jpwl_hprot_MH: Integer;
    jpwl_hprot_TPH_tileno: array[0..15] of Integer;
    jpwl_hprot_TPH: array[0..15] of Integer;
    jpwl_pprot_tileno: array[0..15] of Integer;
    jpwl_pprot_packno: array[0..15] of Integer;
    jpwl_pprot: array[0..15] of Integer;
    jpwl_sens_size: Integer;
    jpwl_sens_addr: Integer;
    jpwl_sens_range: Integer;
    jpwl_sens_MH: Integer;
    jpwl_sens_TPH_tileno: array[0..15] of Integer;
    jpwl_sens_TPH: array[0..15] of Integer;
    cp_cinema: OPJ_UINT16;
    max_comp_size: Integer;
    cp_rsiz: OPJ_UINT16;
    tp_on: OPJ_BYTE;
    tp_flag: OPJ_BYTE;
    tcp_mct: OPJ_BYTE;
    jpip_on: OPJ_BOOL;
    mct_data: Pointer;
    max_cs_size: Integer;
    rsiz: OPJ_UINT16;
  end;
  opj_cparameters_t = opj_cparameters;
  popj_cparameters_t = ^opj_cparameters_t;
  TOpjCParameters = opj_cparameters_t;

  { Decompression parameters }
  popj_dparameters = ^opj_dparameters;
  opj_dparameters = record
    cp_reduce: OPJ_UINT32;
    cp_layer: OPJ_UINT32;
    infile: array[0..OPJ_PATH_LEN - 1] of OPJ_CHAR;
    outfile: array[0..OPJ_PATH_LEN - 1] of OPJ_CHAR;
    decod_format: Integer;
    cod_format: Integer;
    DA_x0: OPJ_UINT32;
    DA_x1: OPJ_UINT32;
    DA_y0: OPJ_UINT32;
    DA_y1: OPJ_UINT32;
    m_verbose: OPJ_BOOL;
    tile_index: OPJ_UINT32;
    nb_tile_to_decode: OPJ_UINT32;
    { JPWL fields are UNCONDITIONAL in the official openjpeg.h - omitting
      them made this record 12 bytes short, so the DLL's
      opj_set_default_decoder_parameters wrote past the caller's stack
      local and opj_setup_decoder then failed on every file. }
    jpwl_correct: OPJ_BOOL;
    jpwl_exp_comps: Integer;
    jpwl_max_tiles: Integer;
    flags: OPJ_UINT32;
  end;
  opj_dparameters_t = opj_dparameters;
  popj_dparameters_t = ^opj_dparameters_t;
  TOpjDParameters = opj_dparameters_t;

{ Image Type Definitions }

type
  PIntegerArray = ^TIntegerArray;
  TIntegerArray = array[0..MaxInt div SizeOf(Integer) - 1] of Integer;

  { Defines a single image component }
  popj_image_comp = ^opj_image_comp;
  opj_image_comp = record
    dx: OPJ_UINT32;
    dy: OPJ_UINT32;
    w: OPJ_UINT32;
    h: OPJ_UINT32;
    x0: OPJ_UINT32;
    y0: OPJ_UINT32;
    prec: OPJ_UINT32;
    bpp: OPJ_UINT32;
    sgnd: OPJ_UINT32;
    resno_decoded: OPJ_UINT32;
    factor: OPJ_UINT32;
    data: PIntegerArray;
    alpha: OPJ_UINT16;
  end;
  opj_image_comp_t = opj_image_comp;
  popj_image_comp_t = ^opj_image_comp_t;
  opj_image_comp_array = array[0..255] of opj_image_comp_t;
  popj_image_comp_array = ^opj_image_comp_array;
  TOpjImageComp = opj_image_comp_t;
  POpjImageComp = popj_image_comp_t;

  { Defines image data and characteristics }
  popj_image = ^opj_image;
  opj_image = record
    x0: OPJ_UINT32;
    y0: OPJ_UINT32;
    x1: OPJ_UINT32;
    y1: OPJ_UINT32;
    numcomps: OPJ_UINT32;
    color_space: OPJ_COLOR_SPACE;
    comps: popj_image_comp_array;
    icc_profile_buf: POPJ_BYTE;
    icc_profile_len: OPJ_UINT32;
  end;
  opj_image_t = opj_image;
  popj_image_t = ^opj_image_t;
  TOpjImage = opj_image_t;
  POpjImage = popj_image_t;

  { Component parameters structure used by the opj_image_create function }
  popj_image_comptparm = ^opj_image_comptparm;
  opj_image_comptparm = record
    dx: OPJ_UINT32;
    dy: OPJ_UINT32;
    w: OPJ_UINT32;
    h: OPJ_UINT32;
    x0: OPJ_UINT32;
    y0: OPJ_UINT32;
    prec: OPJ_UINT32;
    bpp: OPJ_UINT32;
    sgnd: OPJ_UINT32;
  end;
  opj_image_cmptparm_t = opj_image_comptparm;
  popj_image_cmptparm_t = ^opj_image_cmptparm_t;
  opj_image_cmptparm_array = array[0..255] of opj_image_cmptparm_t;
  popj_image_cmptparm_array = ^opj_image_cmptparm_array;
  TOpjImageCompParam = opj_image_cmptparm_t;

{ Stream callbacks }

type
  opj_stream_read_fn = function(p_buffer: Pointer; p_nb_bytes: OPJ_SIZE_T; p_user_data: Pointer): OPJ_SIZE_T; cdecl;
  opj_stream_write_fn = function(p_buffer: Pointer; p_nb_bytes: OPJ_SIZE_T; p_user_data: Pointer): OPJ_SIZE_T; cdecl;
  opj_stream_skip_fn = function(p_nb_bytes: OPJ_OFF_T; p_user_data: Pointer): OPJ_OFF_T; cdecl;
  opj_stream_seek_fn = function(p_nb_bytes: OPJ_OFF_T; p_user_data: Pointer): OPJ_BOOL; cdecl;
  opj_stream_free_user_data_fn = procedure(p_user_data: Pointer); cdecl;

  opj_msg_callback = procedure(msg: PAnsiChar; client_data: Pointer); cdecl;

{ Function declarations as variable pointers for dynamic loading }

var
  { Version }
  opj_version: function(): PAnsiChar; cdecl;

  { Image functions }
  opj_image_create: function(numcmpts: OPJ_UINT32; cmptparms: popj_image_cmptparm_t; clrspc: OPJ_COLOR_SPACE): popj_image_t; cdecl;
  opj_image_destroy: procedure(image: popj_image_t); cdecl;
  opj_image_tile_create: function(numcmpts: OPJ_UINT32; cmptparms: popj_image_cmptparm_t; clrspc: OPJ_COLOR_SPACE): popj_image_t; cdecl;

  { Stream functions }
  opj_stream_default_create: function(p_is_input: OPJ_BOOL): opj_stream_t; cdecl;
  opj_stream_create: function(p_buffer_size: OPJ_SIZE_T; p_is_input: OPJ_BOOL): opj_stream_t; cdecl;
  opj_stream_destroy: procedure(p_stream: opj_stream_t); cdecl;
  opj_stream_set_read_function: procedure(p_stream: opj_stream_t; p_function: opj_stream_read_fn); cdecl;
  opj_stream_set_write_function: procedure(p_stream: opj_stream_t; p_function: opj_stream_write_fn); cdecl;
  opj_stream_set_skip_function: procedure(p_stream: opj_stream_t; p_function: opj_stream_skip_fn); cdecl;
  opj_stream_set_seek_function: procedure(p_stream: opj_stream_t; p_function: opj_stream_seek_fn); cdecl;
  opj_stream_set_user_data: procedure(p_stream: opj_stream_t; p_data: Pointer; p_function: opj_stream_free_user_data_fn); cdecl;
  opj_stream_set_user_data_length: procedure(p_stream: opj_stream_t; data_length: OPJ_UINT64); cdecl;
  opj_stream_create_default_file_stream: function(fname: PAnsiChar; p_is_read_stream: OPJ_BOOL): opj_stream_t; cdecl;
  opj_stream_create_file_stream: function(fname: PAnsiChar; p_buffer_size: OPJ_SIZE_T; p_is_read_stream: OPJ_BOOL): opj_stream_t; cdecl;

  { Codec functions }
  opj_create_decompress: function(format: OPJ_CODEC_FORMAT): opj_codec_t; cdecl;
  opj_destroy_codec: procedure(p_codec: opj_codec_t); cdecl;
  opj_end_decompress: function(p_codec: opj_codec_t; p_stream: opj_stream_t): OPJ_BOOL; cdecl;
  opj_set_default_decoder_parameters: procedure(parameters: popj_dparameters_t); cdecl;
  opj_setup_decoder: function(p_codec: opj_codec_t; parameters: popj_dparameters_t): OPJ_BOOL; cdecl;
  opj_codec_set_threads: function(p_codec: opj_codec_t; num_threads: Integer): OPJ_BOOL; cdecl;
  opj_read_header: function(p_stream: opj_stream_t; p_codec: opj_codec_t; p_image: popj_image_t): OPJ_BOOL; cdecl;
  opj_set_decode_area: function(p_codec: opj_codec_t; p_image: popj_image_t; p_start_x, p_start_y, p_end_x, p_end_y: OPJ_INT32): OPJ_BOOL; cdecl;
  opj_decode: function(p_codec: opj_codec_t; p_stream: opj_stream_t; p_image: popj_image_t): OPJ_BOOL; cdecl;
  opj_get_decoded_tile: function(p_codec: opj_codec_t; p_stream: opj_stream_t; p_image: popj_image_t; tile_index: OPJ_UINT32): OPJ_BOOL; cdecl;
  opj_set_decoded_resolution_factor: function(p_codec: opj_codec_t; res_factor: OPJ_UINT32): OPJ_BOOL; cdecl;

  { Encoder functions }
  opj_create_compress: function(format: OPJ_CODEC_FORMAT): opj_codec_t; cdecl;
  opj_set_default_encoder_parameters: procedure(parameters: popj_cparameters_t); cdecl;
  opj_setup_encoder: function(p_codec: opj_codec_t; parameters: popj_cparameters_t; image: popj_image_t): OPJ_BOOL; cdecl;
  opj_start_compress: function(p_codec: opj_codec_t; p_image: popj_image_t; p_stream: opj_stream_t): OPJ_BOOL; cdecl;
  opj_end_compress: function(p_codec: opj_codec_t; p_stream: opj_stream_t): OPJ_BOOL; cdecl;
  opj_encode: function(p_codec: opj_codec_t; p_stream: opj_stream_t): OPJ_BOOL; cdecl;
  opj_write_tile: function(p_codec: opj_codec_t; p_tile_index: OPJ_UINT32; p_data: POPJ_BYTE; p_data_size: OPJ_UINT32; p_stream: opj_stream_t): OPJ_BOOL; cdecl;

  { Message handlers }
  opj_set_info_handler: function(p_codec: opj_codec_t; p_callback: opj_msg_callback; p_user_data: Pointer): OPJ_BOOL; cdecl;
  opj_set_warning_handler: function(p_codec: opj_codec_t; p_callback: opj_msg_callback; p_user_data: Pointer): OPJ_BOOL; cdecl;
  opj_set_error_handler: function(p_codec: opj_codec_t; p_callback: opj_msg_callback; p_user_data: Pointer): OPJ_BOOL; cdecl;

{ Library loading functions }

function LoadOpenJpegLibrary: Boolean;
procedure FreeOpenJpegLibrary;
function IsOpenJpegLoaded: Boolean;

implementation

{$IFDEF FPC}
uses
  dynlibs;
{$ENDIF}

var
  OpenJpegLibHandle: {$IFDEF FPC}TLibHandle{$ELSE}THandle{$ENDIF} = 0;

function GetProcAddr(const AProcName: PAnsiChar): Pointer;
begin
  Result := GetProcAddress(OpenJpegLibHandle, AProcName);
end;

function TryLoadLibrary(const ALibName: string): Boolean;
begin
  Result := False;
  OpenJpegLibHandle := LoadLibrary(PChar(ALibName));
{$IF Defined(DARWIN)}
  if OpenJpegLibHandle = 0 then
    OpenJpegLibHandle := LoadLibrary(PChar('@executable_path/' + ALibName));
  if OpenJpegLibHandle = 0 then
    OpenJpegLibHandle := LoadLibrary(PChar('/opt/homebrew/lib/' + ALibName));
  if OpenJpegLibHandle = 0 then
    OpenJpegLibHandle := LoadLibrary(PChar('/usr/local/lib/' + ALibName));
{$IFEND}
  Result := OpenJpegLibHandle <> 0;
end;

function LoadOpenJpegLibrary: Boolean;
begin
  Result := False;

  if OpenJpegLibHandle <> 0 then
  begin
    Result := True;
    Exit;
  end;

  // Try primary library name first, then alternative
  if not TryLoadLibrary(SLibName) then
    if not TryLoadLibrary(SLibNameAlt) then
      Exit;

  // Load all function pointers
  @opj_version := GetProcAddr('opj_version');

  // Image functions
  @opj_image_create := GetProcAddr('opj_image_create');
  @opj_image_destroy := GetProcAddr('opj_image_destroy');
  @opj_image_tile_create := GetProcAddr('opj_image_tile_create');

  // Stream functions
  @opj_stream_default_create := GetProcAddr('opj_stream_default_create');
  @opj_stream_create := GetProcAddr('opj_stream_create');
  @opj_stream_destroy := GetProcAddr('opj_stream_destroy');
  @opj_stream_set_read_function := GetProcAddr('opj_stream_set_read_function');
  @opj_stream_set_write_function := GetProcAddr('opj_stream_set_write_function');
  @opj_stream_set_skip_function := GetProcAddr('opj_stream_set_skip_function');
  @opj_stream_set_seek_function := GetProcAddr('opj_stream_set_seek_function');
  @opj_stream_set_user_data := GetProcAddr('opj_stream_set_user_data');
  @opj_stream_set_user_data_length := GetProcAddr('opj_stream_set_user_data_length');
  @opj_stream_create_default_file_stream := GetProcAddr('opj_stream_create_default_file_stream');
  @opj_stream_create_file_stream := GetProcAddr('opj_stream_create_file_stream');

  // Decoder functions
  @opj_create_decompress := GetProcAddr('opj_create_decompress');
  @opj_destroy_codec := GetProcAddr('opj_destroy_codec');
  @opj_end_decompress := GetProcAddr('opj_end_decompress');
  @opj_set_default_decoder_parameters := GetProcAddr('opj_set_default_decoder_parameters');
  @opj_setup_decoder := GetProcAddr('opj_setup_decoder');
  @opj_codec_set_threads := GetProcAddr('opj_codec_set_threads');
  @opj_read_header := GetProcAddr('opj_read_header');
  @opj_set_decode_area := GetProcAddr('opj_set_decode_area');
  @opj_decode := GetProcAddr('opj_decode');
  @opj_get_decoded_tile := GetProcAddr('opj_get_decoded_tile');
  @opj_set_decoded_resolution_factor := GetProcAddr('opj_set_decoded_resolution_factor');

  // Encoder functions
  @opj_create_compress := GetProcAddr('opj_create_compress');
  @opj_set_default_encoder_parameters := GetProcAddr('opj_set_default_encoder_parameters');
  @opj_setup_encoder := GetProcAddr('opj_setup_encoder');
  @opj_start_compress := GetProcAddr('opj_start_compress');
  @opj_end_compress := GetProcAddr('opj_end_compress');
  @opj_encode := GetProcAddr('opj_encode');
  @opj_write_tile := GetProcAddr('opj_write_tile');

  // Message handlers
  @opj_set_info_handler := GetProcAddr('opj_set_info_handler');
  @opj_set_warning_handler := GetProcAddr('opj_set_warning_handler');
  @opj_set_error_handler := GetProcAddr('opj_set_error_handler');

  // Check if essential functions were loaded
  Result := Assigned(opj_version) and
            Assigned(opj_image_create) and
            Assigned(opj_image_destroy) and
            Assigned(opj_create_decompress) and
            Assigned(opj_decode) and
            Assigned(opj_create_compress) and
            Assigned(opj_encode);

  if not Result then
    FreeOpenJpegLibrary;
end;

procedure FreeOpenJpegLibrary;
begin
  if OpenJpegLibHandle <> 0 then
  begin
    FreeLibrary(OpenJpegLibHandle);
    OpenJpegLibHandle := 0;
  end;

  // Clear all function pointers
  @opj_version := nil;
  @opj_image_create := nil;
  @opj_image_destroy := nil;
  @opj_image_tile_create := nil;
  @opj_stream_default_create := nil;
  @opj_stream_create := nil;
  @opj_stream_destroy := nil;
  @opj_stream_set_read_function := nil;
  @opj_stream_set_write_function := nil;
  @opj_stream_set_skip_function := nil;
  @opj_stream_set_seek_function := nil;
  @opj_stream_set_user_data := nil;
  @opj_stream_set_user_data_length := nil;
  @opj_stream_create_default_file_stream := nil;
  @opj_stream_create_file_stream := nil;
  @opj_create_decompress := nil;
  @opj_destroy_codec := nil;
  @opj_end_decompress := nil;
  @opj_set_default_decoder_parameters := nil;
  @opj_setup_decoder := nil;
  @opj_codec_set_threads := nil;
  @opj_read_header := nil;
  @opj_set_decode_area := nil;
  @opj_decode := nil;
  @opj_get_decoded_tile := nil;
  @opj_set_decoded_resolution_factor := nil;
  @opj_create_compress := nil;
  @opj_set_default_encoder_parameters := nil;
  @opj_setup_encoder := nil;
  @opj_start_compress := nil;
  @opj_end_compress := nil;
  @opj_encode := nil;
  @opj_write_tile := nil;
  @opj_set_info_handler := nil;
  @opj_set_warning_handler := nil;
  @opj_set_error_handler := nil;
end;

function IsOpenJpegLoaded: Boolean;
begin
  Result := OpenJpegLibHandle <> 0;
end;

finalization
  FreeOpenJpegLibrary;

end.
