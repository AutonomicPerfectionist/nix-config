{
  config,
  pkgs,
  flake-inputs,
  ...
}:
let
  prrte-fixed = pkgs.prrte.overrideAttrs (old: {
    postPatch = old.postPatch + ''
      substituteInPlace src/runtime/prte_mca_params.c --replace-fail \
        "$out/bin/prted" "/run/current-system/sw/bin/prted"
    '';
  });

  openmpi-fixed = pkgs.openmpi.overrideAttrs (old: {
    buildInputs = map
      (x: if x == pkgs.prrte then prrte-fixed else x)
      old.buildInputs;
    configureFlags = map
      (f: if builtins.match "--with-prrte=.*" f != null
          then "--with-prrte=${prrte-fixed}"
          else f)
      old.configureFlags;
  });
in
{
  environment.systemPackages = [
    openmpi-fixed
    prrte-fixed
  ];
}
