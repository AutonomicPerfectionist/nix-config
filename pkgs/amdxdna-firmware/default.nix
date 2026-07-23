{
  lib,
  fetchurl,
  stdenvNoCC,
}:

let
  firmwares = [
    {
      pciDir = "1502_00";
      url = "https://gitlab.com/kernel-firmware/drm-firmware/-/raw/amd-ipu-staging/amdnpu/1502_00/1.5_npu.sbin.1.5.5.391";
      hash = "sha256-0T/5+5XGzqQCE/pp5aNGVSnwC7Z8CYTWI0PG4xgI+54=";
    }
    {
      pciDir = "17f0_10";
      url = "https://gitlab.com/kernel-firmware/drm-firmware/-/raw/amd-ipu-staging/amdnpu/17f0_10/1.7_npu.sbin.1.1.2.64";
      hash = "sha256-ftDyQvJTtYHrdcjIs0Y42S+6WYBjtjWlQb65SGkkVGk=";
    }
    {
      pciDir = "17f0_11";
      url = "https://gitlab.com/kernel-firmware/drm-firmware/-/raw/amd-ipu-staging/amdnpu/17f0_11/1.7_npu.sbin.1.1.2.65";
      hash = "sha256-PjyZbvHlYulu5MTZD6qfrxEyxy2jrxvPNdWSzDSQP+0=";
    }
  ];

  sources = map (fw: {
    inherit (fw) pciDir;
    src = fetchurl {
      inherit (fw) url hash;
      name = "npu.dev.sbin-${fw.pciDir}";
    };
  }) firmwares;

in
stdenvNoCC.mkDerivation {
  name = "amdxdna-firmware";

  dontUnpack = true;

  installPhase = ''
    ${lib.concatMapStringsSep "\n" (fw: ''
      install -Dm444 ${fw.src} $out/lib/firmware/amdnpu/${fw.pciDir}/npu.dev.sbin
    '') sources}
  '';

  meta = {
    description = "Firmware for AMD XDNA NPU (from amd-ipu-staging branch)";
    homepage = "https://gitlab.com/kernel-firmware/drm-firmware/-/tree/amd-ipu-staging/amdnpu";
    license = lib.licenses.unfreeRedistributableFirmware;
    platforms = ["x86_64-linux"];
  };
}
