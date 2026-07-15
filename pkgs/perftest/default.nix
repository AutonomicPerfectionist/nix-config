{
  lib,
  stdenv,
  fetchFromGitHub,
  libtool,
  automake,
  autoconf,
  rdma-core,
  pciutils,
}:
stdenv.mkDerivation rec {
  pname = "perftest";
  version = "24.04.0-0.41";

  src = fetchFromGitHub {
    owner = "linux-rdma";
    repo = pname;
    rev = version;
    hash = "sha256-TRIJYbe+9K/6wIq5bPU5vfND8enYfrzRJRKbb4jWlMc=";
  };

  nativeBuildInputs = [
    libtool
    automake
    autoconf
  ];

  buildInputs = [
    rdma-core
    pciutils
  ];

  configurePhase = ''
    runHook preConfigure
    ./autogen.sh
    ./configure --prefix=$out
    runHook postConfigure
  '';

  meta = with lib; {
    description = "IB/RDMA userspace benchmarks (ib_write_bw, ib_send_bw, etc.)";
    homepage = "https://github.com/linux-rdma/perftest";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
  };
}
