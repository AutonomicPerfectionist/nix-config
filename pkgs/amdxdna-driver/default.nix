{
  lib,
  stdenv,
  fetchFromGitHub,
  kernel,
}:

stdenv.mkDerivation {
  pname = "amdxdna";
  version = "unstable-2026-07-20";

  src = fetchFromGitHub {
    owner = "amd";
    repo = "xdna-driver";
    rev = "ed8fb2dd172bde623d7112a1bd674fc0e3c4cae4";
    hash = "sha256-gImGiezSjZMGxt0yJgQD7mujBcgjwwIbk+Oo1L5wu+o=";
  };

  sourceRoot = "source/src/driver/amdxdna";

  postUnpack = ''
    chmod -R u+w source
  '';

  nativeBuildInputs = kernel.moduleBuildDependencies;

  preBuild = ''
    mkdir -p ../../include/uapi
    cp -r $src/src/include/uapi/drm_local ../../include/uapi/

    cp $src/src/driver/tools/configure_kernel.sh $TMPDIR/configure_kernel.sh
    sed -i 's|KERNEL_CMN="''${KERNEL_DIR}/source"|KERNEL_CMN="''${KERNEL_CMN:-''${KERNEL_DIR}/source}"|' $TMPDIR/configure_kernel.sh

    export KERNEL_SRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build
    export KERNEL_CMN=${kernel.dev}/lib/modules/${kernel.modDirVersion}/source
    export KERNEL_VER=${kernel.modDirVersion}
    export OUT=config_kernel.h
    bash $TMPDIR/configure_kernel.sh

    makeFlagsArray+=(
      ${lib.concatMapStringsSep " " (f: "\"${f}\"")
        (lib.filter (f: !(lib.hasPrefix "O=" f || lib.hasPrefix "--eval=" f)) kernel.makeFlags)}
      "-C" "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      "M=$(pwd)"
      "OFT_CONFIG_AMDXDNA_PCI=y"
      "CFLAGS_MODULE=-DAMDXDNA_DEVEL"
      "modules"
    )
  '';

  installPhase = ''
    install -D amdxdna.ko $out/lib/modules/${kernel.modDirVersion}/extra/amdxdna.ko
  '';

  meta = {
    description = "AMD XDNA driver for Ryzen AI NPUs (out-of-tree)";
    homepage = "https://github.com/amd/xdna-driver";
    license = lib.licenses.gpl2Only;
    platforms = ["x86_64-linux"];
  };
}
