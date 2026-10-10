{
  lib,
  fetchFromGitHub,
  python3Packages,
  makeWrapper,
  ipmitool,
}:
python3Packages.buildPythonApplication rec {
  pname = "smfc";
  version = "6.4.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "petersulyok";
    repo = "smfc";
    tag = "v${version}";
    hash = "sha256-2YRQnHiG+4vWKJ3CZ+jyra5A6i+wAz2x+1ET1gas41o=";
  };

  build-system = [ python3Packages.setuptools ];

  dependencies = [ python3Packages.pyudev ];

  nativeBuildInputs = [ makeWrapper ];

  # smfc and smfc-client both shell out to `ipmitool` on $PATH. GPU
  # monitoring (nvidia-smi/rocm-smi) is hardware-specific, so that's left
  # to be added to the service's PATH by the NixOS module instead of baked
  # in here.
  postFixup = ''
    wrapProgram $out/bin/smfc \
      --prefix PATH : ${lib.makeBinPath [ ipmitool ]}
    wrapProgram $out/bin/smfc-client \
      --prefix PATH : ${lib.makeBinPath [ ipmitool ]}
  '';

  # No network/hardware access in the sandbox; upstream's test suite also
  # expects to run under its own pytest fixtures/mocks via uv, not plain
  # pytest discovery.
  doCheck = false;

  meta = {
    description = "Supermicro Fan Control: IPMI fan control daemon driven by CPU/HD/NVMe/GPU temperatures";
    homepage = "https://github.com/petersulyok/smfc";
    changelog = "https://github.com/petersulyok/smfc/blob/v${version}/CHANGELOG.md";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "smfc";
  };
}
