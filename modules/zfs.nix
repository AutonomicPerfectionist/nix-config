{
  config,
  lib,
  pkgs,
  ...
}:

let
  zfsCompatibleKernelPackages = lib.filterAttrs (
    name: kernelPackages:
    (builtins.match "linux_[0-9]+_[0-9]+" name) != null
    && (builtins.tryEval kernelPackages).success
    && (!kernelPackages.${config.boot.zfs.package.kernelModuleAttribute}.meta.broken)
  ) pkgs.linuxKernel.packages;

  # Parse "6.6.123" -> "6.6"
  parseMajorMinor = v:
    let
      parts = lib.splitString "." v;
    in
    if builtins.length parts >= 2 then
      builtins.elemAt parts 0 + "." + builtins.elemAt parts 1
    else
      v;

  # Compare major.minor versions: returns true if a <= b
  majorMinorOlderOrEqual = a: b:
    let
      aMajor = lib.head (lib.splitString "." a);
      aMinor = lib.elemAt (lib.splitString "." a) 1;
      bMajor = lib.head (lib.splitString "." b);
      bMinor = lib.elemAt (lib.splitString "." b) 1;
    in
    if aMajor < bMajor then true
    else if aMajor > bMajor then false
    else aMinor <= bMinor;

  # Select the newest ZFS-compatible kernel not newer than maxKernelVersion.
  # maxKernelVersion is a major.minor string like "6.6" or "6.8",
  # or omitted/default "99.99" to get the absolute latest.
  # Returns the kernelPackages attribute set, or null if none match.
  selectZfsCompatibleKernel = { maxKernelVersion ? "99.99" }:
    let
      maxMM = parseMajorMinor maxKernelVersion;
      compatible = lib.filter (k:
        let
          kMM = parseMajorMinor k.kernel.version;
        in
        majorMinorOlderOrEqual kMM maxMM
      ) (builtins.attrValues zfsCompatibleKernelPackages);
    in
    if compatible == [] then
      null
    else
      lib.last (lib.sort (a: b: (lib.versionOlder a.kernel.version b.kernel.version)) compatible);

  latestKernelPackage = selectZfsCompatibleKernel { };
in
{
  # Note this might jump back and forth as kernels are added or removed.
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;

  # Exported for use in host/user configurations
  _module.args.zfs = {
    inherit selectZfsCompatibleKernel;
    inherit zfsCompatibleKernelPackages;
  };
}
