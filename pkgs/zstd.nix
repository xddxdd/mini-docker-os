{ pkgs
, lib
, stdenv
, fetchFromGitHub
, cmake
, busybox
}:

let
  static = true;
in
stdenv.mkDerivation rec {
  inherit (pkgs.zstd) pname version src patches;

  nativeBuildInputs = [ cmake ];

  postPatch = lib.optionalString (!static) ''
    substituteInPlace build/cmake/CMakeLists.txt \
      --replace 'message(SEND_ERROR "You need to build static library to build tests")' ""
    substituteInPlace build/cmake/tests/CMakeLists.txt \
      --replace 'libzstd_static' 'libzstd_shared'
    sed -i \
      "1aexport ${lib.optionalString stdenv.isDarwin "DY"}LD_LIBRARY_PATH=$PWD/build_/lib" \
      tests/playTests.sh
  '';

  cmakeFlags = lib.attrsets.mapAttrsToList
    (name: value: "-DZSTD_${name}:BOOL=${if value then "ON" else "OFF"}")
    {
      BUILD_SHARED = !static;
      BUILD_STATIC = static;
      BUILD_CONTRIB = false;
      PROGRAMS_LINK_SHARED = !static;
      LEGACY_SUPPORT = false;
      BUILD_TESTS = false;
    };

  cmakeDir = "../build/cmake";
  dontUseCmakeBuildDir = true;
  preConfigure = ''
    mkdir -p build_ && cd $_
  '';

  doCheck = false;

  preInstall = ''
    mkdir -p $bin/bin
    substituteInPlace ../programs/zstdgrep \
      --replace ":-zstdcat" ":-$bin/bin/zstdcat"

    substituteInPlace ../programs/zstdless \
      --replace "zstdcat" "$bin/bin/zstdcat"
  '';

  outputs = [ "bin" "dev" ]
    ++ lib.optional stdenv.hostPlatform.isUnix "man"
    ++ [ "out" ];

  meta = with lib; {
    description = "Zstandard real-time compression algorithm";
    longDescription = ''
      Zstd, short for Zstandard, is a fast lossless compression algorithm,
      targeting real-time compression scenarios at zlib-level compression
      ratio. Zstd can also offer stronger compression ratio at the cost of
      compression speed. Speed/ratio trade-off is configurable by small
      increment, to fit different situations. Note however that decompression
      speed is preserved and remain roughly the same at all settings, a
      property shared by most LZ compression algorithms, such as zlib.
    '';
    homepage = "https://facebook.github.io/zstd/";
    changelog = "https://github.com/facebook/zstd/blob/v${version}/CHANGELOG";
    license = with licenses; [ bsd3 ]; # Or, at your opinion, GPL-2.0-only.

    platforms = platforms.all;
    maintainers = with maintainers; [ orivej ];
  };
}
