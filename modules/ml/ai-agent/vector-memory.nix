# modules/vector-memory.nix
#
# Manages the persistent vector memory layer:
#   1. Qdrant vector database (via the upstream nixpkgs services.qdrant module)
#   2. codebase-indexer — a Python service that walks project directories,
#      parses files with tree-sitter into symbol-level chunks, embeds them
#      with sentence-transformers, and upserts into Qdrant.
#
# The indexer runs as a systemd oneshot service triggered by a timer.
# It keeps a SQLite state file to track file mtimes, so only changed
# files are re-embedded on each run (incremental indexing).
#
# All packages used here are available in nixpkgs:
#   - services.qdrant.*                      (nixos/modules/services/search/qdrant.nix)
#   - python313Packages.sentence-transformers (HuggingFace transformers-based; no GPU required)
#   - python313Packages.qdrant-client        (mynixos.com/nixpkgs/package/python313Packages.qdrant-client)
#   - python313Packages.tree-sitter          (mynixos.com/nixpkgs/package/python313Packages.tree-sitter)
#   - python313Packages.tree-sitter-grammars (per-language grammar packages)
#   - python313Packages.gitpython            (for repo-aware path filtering)
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.services.aiAgent;
  memCfg = cfg.memory;

  # Expand the stateDir option for a specific user at Nix evaluation time.
  # This gives us a concrete absolute path for values that systemd and Nix
  # consume directly (ReadWritePaths, tmpfiles rules), where shell ~ expansion
  # does not occur.  We read the home from users.users.<name>.home and fall
  # back to /home/<name> for users declared outside the NixOS users module
  # (e.g. LDAP users).
  stateDirForUser =
    user:
    let
      home = config.users.users.${user}.home or "/home/${user}";
    in
    builtins.replaceStrings [ "~" ] [ home ] memCfg.stateDir;

  # ── Python environment for the indexer ──────────────────────────────────
  # All packages exist in nixpkgs; no overlays needed.
  indexerPython = pkgs.python313.withPackages (
    ps: with ps; [
      qdrant-client # Qdrant Python SDK
      tree-sitter # Core parsing library
      # Tree-sitter grammars bundled as Python packages in nixpkgs.
      # Add or remove languages for your stack:
      tree-sitter-grammars.tree-sitter-rust
      tree-sitter-grammars.tree-sitter-python
      tree-sitter-grammars.tree-sitter-go
      tree-sitter-grammars.tree-sitter-typescript
      tree-sitter-grammars.tree-sitter-nix
      tree-sitter-grammars.tree-sitter-c
      tree-sitter-grammars.tree-sitter-cpp
      tree-sitter-grammars.tree-sitter-toml
      tree-sitter-grammars.tree-sitter-yaml
      tree-sitter-grammars.tree-sitter-json
      gitpython # Skip files in .gitignore
      tqdm # Progress reporting in journald
    ]
  );

  # ── Indexer script ───────────────────────────────────────────────────────
  # Written as a Nix string so all paths are substituted at build time.
  # The script is installed to the Nix store and called by the systemd service.
  indexerScript = pkgs.writeTextFile {
    name = "codebase-indexer";
    executable = true;
    destination = "/bin/codebase-indexer";
    text = ''
      #!${indexerPython}/bin/python3
      # codebase-indexer: incrementally index source code into Qdrant.
      #
      # State file: $AI_AGENT_STATE_DIR/indexer.db  (SQLite; path set by NixOS module)
      # Collection : "codebase" in Qdrant
      #
      # Chunk strategy: tree-sitter → top-level declarations (functions,
      # classes, impl blocks, structs).  Falls back to line-window chunking
      # for languages without a grammar or for plain-text files.
      import os, sys, time, json, hashlib, sqlite3, fnmatch, pathlib, logging
      from typing import Generator

      logging.basicConfig(
          level  = logging.INFO,
          format = "%(asctime)s %(levelname)s %(message)s",
          stream = sys.stdout,
      )
      log = logging.getLogger("indexer")

      # ── Configuration (injected from Nix) ────────────────────────────────
      QDRANT_URL     = "http://127.0.0.1:${toString memCfg.qdrantHttpPort}"
      EMBEDDINGS_URL = "http://127.0.0.1:${toString memCfg.embeddingsPort}"
      COLLECTION     = "codebase"
      EXCLUDE       = ${builtins.toJSON memCfg.excludePatterns}
      PROJECT_ROOTS = ${builtins.toJSON memCfg.projectRoots}

      # STATE_DIR is injected by the systemd service via AI_AGENT_STATE_DIR,
      # which the NixOS module expands to an absolute path (resolving ~ to the
      # real home directory) so ReadWritePaths and tmpfiles rules are correct.
      # The fallback mirrors the XDG Base Directory default and is a last
      # resort only — systemd-tmpfiles guarantees the directory exists first.
      _xdg_data_home = os.environ.get(
          "XDG_DATA_HOME",
          os.path.join(os.path.expanduser("~"), ".local", "share"),
      )
      STATE_DIR = os.environ.get(
          "AI_AGENT_STATE_DIR",
          os.path.join(_xdg_data_home, "ai-agent"),
      )
      STATE_DB  = os.path.join(STATE_DIR, "indexer.db")

      # ── Tree-sitter language map ─────────────────────────────────────────
      # Maps file extension → tree-sitter Language object.
      # Only languages with grammars listed above are included.
      import tree_sitter_rust, tree_sitter_python, tree_sitter_go
      import tree_sitter_typescript, tree_sitter_nix
      import tree_sitter_c, tree_sitter_cpp
      from tree_sitter import Language, Parser

      LANG_MAP = {
          ".rs"   : Language(tree_sitter_rust.language()),
          ".py"   : Language(tree_sitter_python.language()),
          ".go"   : Language(tree_sitter_go.language()),
          ".ts"   : Language(tree_sitter_typescript.language_typescript()),
          ".tsx"  : Language(tree_sitter_typescript.language_tsx()),
          ".nix"  : Language(tree_sitter_nix.language()),
          ".c"    : Language(tree_sitter_c.language()),
          ".cc"   : Language(tree_sitter_cpp.language()),
          ".cpp"  : Language(tree_sitter_cpp.language()),
          ".h"    : Language(tree_sitter_c.language()),
          ".hpp"  : Language(tree_sitter_cpp.language()),
      }

      # Node types that represent top-level declarations across languages.
      # tree-sitter parses these out; each becomes one vector chunk.
      DECL_TYPES = {
          "function_item", "impl_item", "struct_item", "enum_item",   # Rust
          "function_definition", "class_definition",                   # Python
          "function_declaration", "method_declaration",                # Go/TS
          "function_definition",                                       # C/C++
      }

      MAX_CHUNK_BYTES = 4096   # hard cap per chunk before line-windowing
      LINE_WINDOW     = 60     # fallback chunk size for unrecognised files

      def should_exclude(path: pathlib.Path) -> bool:
          for pat in EXCLUDE:
              if fnmatch.fnmatch(path.name, pat):
                  return True
          return False

      def chunks_from_tree(src: bytes, lang: Language) -> Generator[str, None, None]:
          """Yield declaration-level text chunks via tree-sitter."""
          parser = Parser(lang)
          tree   = parser.parse(src)
          for node in tree.root_node.children:
              if node.type in DECL_TYPES:
                  text = src[node.start_byte : node.end_byte].decode("utf-8", "replace")
                  if len(text) <= MAX_CHUNK_BYTES:
                      yield text
                  else:
                      # Declaration too large; emit line windows
                      yield from line_windows(text)

      def line_windows(text: str) -> Generator[str, None, None]:
          """Fallback: sliding window of LINE_WINDOW lines."""
          lines  = text.splitlines()
          step   = LINE_WINDOW // 2
          for i in range(0, max(1, len(lines) - LINE_WINDOW + 1), step):
              yield "\n".join(lines[i : i + LINE_WINDOW])

      def file_chunks(path: pathlib.Path):
          try:
              src  = path.read_bytes()
          except OSError:
              return
          lang = LANG_MAP.get(path.suffix)
          if lang:
              yield from chunks_from_tree(src, lang)
          else:
              yield from line_windows(src.decode("utf-8", "replace"))

      def file_hash(path: pathlib.Path) -> str:
          h = hashlib.blake2b(digest_size=16)
          h.update(path.read_bytes())
          return h.hexdigest()

      # ── State DB helpers ─────────────────────────────────────────────────
      def open_state_db() -> sqlite3.Connection:
          # systemd-tmpfiles creates STATE_DIR before this service runs.
          # os.makedirs here is a belt-and-suspenders fallback only.
          os.makedirs(STATE_DIR, exist_ok=True)
          db = sqlite3.connect(STATE_DB)
          db.execute("""
              CREATE TABLE IF NOT EXISTS files (
                  path    TEXT PRIMARY KEY,
                  hash    TEXT NOT NULL,
                  indexed INTEGER NOT NULL DEFAULT 0
              )
          """)
          db.commit()
          return db

      def needs_reindex(db: sqlite3.Connection, path: str, h: str) -> bool:
          row = db.execute(
              "SELECT hash FROM files WHERE path=?", (path,)
          ).fetchone()
          return row is None or row[0] != h

      def mark_indexed(db: sqlite3.Connection, path: str, h: str):
          db.execute(
              "INSERT OR REPLACE INTO files (path, hash, indexed) VALUES (?,?,?)",
              (path, h, int(time.time()))
          )
          db.commit()

      # ── Main indexing loop ───────────────────────────────────────────────
      def main():
          from qdrant_client import QdrantClient
          from qdrant_client.models import (
              Distance, VectorParams, PointStruct, UpdateStatus
          )
          import uuid
          import urllib.request
          import urllib.parse

          log.info("Connecting to Qdrant at %s", QDRANT_URL)
          qc = QdrantClient(url=QDRANT_URL)

          log.info("Loading embeddings from llama.cpp server at %s", EMBEDDINGS_URL)

          def get_embeddings(texts):
              nonlocal dim
              payload = {"content": texts}
              data = json.dumps(payload).encode("utf-8")
              req = urllib.request.Request(
                  f"{EMBEDDINGS_URL}/embedding",
                  data=data,
                  headers={"Content-Type": "application/json"},
                  method="POST"
              )
              with urllib.request.urlopen(req) as resp:
                  result = json.loads(resp.read())
              embeddings = result["embeddings"]
              if dim == 0:
                  nonlocal dim
                  dim = len(embeddings[0])
                  log.info("Detected embedding dimension: %d", dim)
              return embeddings

          # Ensure collection exists
          existing = [c.name for c in qc.get_collections().collections]
          if COLLECTION not in existing:
              log.info("Creating collection '%s' (dim=%d)", COLLECTION, dim)
              qc.create_collection(
                  collection_name = COLLECTION,
                  vectors_config  = VectorParams(size=dim, distance=Distance.COSINE),
              )

          db    = open_state_db()
          total = 0
          batch_texts, batch_meta, batch_ids = [], [], []

          BATCH = 32   # upsert every N chunks

          def flush():
              nonlocal total
              if not batch_texts:
                  return
              vecs = get_embeddings(batch_texts)
              points = [
                  PointStruct(id=bid, vector=list(v), payload=meta)
                  for bid, v, meta in zip(batch_ids, vecs, batch_meta)
              ]
              result = qc.upsert(collection_name=COLLECTION, points=points)
              if result.status != UpdateStatus.COMPLETED:
                  log.warning("Upsert returned: %s", result.status)
              total += len(points)
              batch_texts.clear(); batch_meta.clear(); batch_ids.clear()
              log.info("Indexed %d chunks so far", total)

          for root_str in PROJECT_ROOTS:
              root = pathlib.Path(os.path.expanduser(root_str))
              if not root.is_dir():
                  log.warning("Project root not found, skipping: %s", root)
                  continue
              log.info("Scanning %s", root)
              for path in root.rglob("*"):
                  if not path.is_file():
                      continue
                  if should_exclude(path):
                      continue
                  try:
                      h = file_hash(path)
                  except OSError:
                      continue
                  if not needs_reindex(db, str(path), h):
                      continue
                  for chunk in file_chunks(path):
                      if not chunk.strip():
                          continue
                      batch_texts.append(chunk)
                      batch_meta.append({
                          "file"     : str(path),
                          "root"     : str(root),
                          "suffix"   : path.suffix,
                          "preview"  : chunk[:200],
                      })
                      batch_ids.append(str(uuid.uuid4()))
                      if len(batch_texts) >= BATCH:
                          flush()
                  mark_indexed(db, str(path), h)

          flush()
          log.info("Done. Total chunks upserted this run: %d", total)

      if __name__ == "__main__":
          main()
    '';
  };

in
{
  config = lib.mkIf (cfg.enable && memCfg.enable) {

    # ── Qdrant vector database ─────────────────────────────────────────────
    # Uses the upstream NixOS module: services.qdrant.*
    # Options: https://mynixos.com/options/services.qdrant
    services.qdrant = {
      enable = true;
      settings = {
        storage = {
          storage_path = "/var/lib/qdrant/storage";
          snapshots_path = "/var/lib/qdrant/snapshots";
        };
        hnsw_index = {
          on_disk = true; # keep graph on disk, not RAM
        };
        service = {
          host = "127.0.0.1"; # LAN-only; not exposed externally
          http_port = memCfg.qdrantHttpPort;
          grpc_port = memCfg.qdrantGrpcPort;
        };
        telemetry_disabled = true;
      };
    };

    # ── State directory creation ───────────────────────────────────────────
    # systemd-tmpfiles runs at boot (before any service) and creates the
    # per-user state directory if it doesn't already exist.  This guarantees
    # the directory is present when the indexer service starts, even on a
    # freshly deployed machine.
    #
    # Rule format: type path mode user group age
    #   d  = create directory (and parents) if missing; no-op if it exists
    #   -  = age/cleanup field: "-" means never clean up
    systemd.tmpfiles.rules = lib.concatMap (
      user:
      let
        dir = stateDirForUser user;
        group = config.users.users.${user}.group or "users";
      in
      [
        "d ${dir} 0700 ${user} ${group} - -"
      ]
    ) cfg.users;

    # ── Indexer systemd service and timer ─────────────────────────────────
    # One service + timer pair is generated for each user in cfg.users.
    # The service runs as that user so it can read their home directory.
    systemd.services = lib.mkMerge (
      map (user: {
        "ai-agent-indexer-${user}" = {
          description = "AI agent codebase indexer for ${user}";
          after = [
            "qdrant.service"
            "llama-embeddings.service"
            "network.target"
            "systemd-tmpfiles-setup.service"
          ];
          requires = [
            "qdrant.service"
            "llama-embeddings.service"
          ];

          # Run as the target user so PROJECT_ROOTS expand correctly.
          serviceConfig = {
            Type = "oneshot";
            User = user;
            Group = config.users.users.${user}.group or "users";

            # Pass the evaluated (~ already resolved) state directory so the
            # Python script uses the canonical path regardless of how $HOME
            # happens to be set inside the service environment.
            Environment = [
              "AI_AGENT_STATE_DIR=${stateDirForUser user}"
            ];

            ExecStart = "${indexerScript}/bin/codebase-indexer";

            # Hardening — only the state dir needs write access.
            PrivateNetwork = false; # must reach localhost Qdrant
            ProtectSystem = "strict";
            ProtectHome = "read-only";
            ReadWritePaths = [ (stateDirForUser user) ];
            NoNewPrivileges = true;
            TimeoutSec = 3600; # large repos may take a while
          };
        };
      }) cfg.users
    );

    systemd.timers = lib.mkMerge (
      map (user: {
        "ai-agent-indexer-${user}" = {
          description = "Timer for AI agent indexer (${user})";
          wantedBy = [ "timers.target" ];
          # Also run at boot, once Qdrant is up, so the index is fresh on login.
          timerConfig = {
            OnBootSec = "2min";
            OnCalendar = memCfg.indexSchedule;
            Persistent = true; # catch up if machine was off
            Unit = "ai-agent-indexer-${user}.service";
          };
        };
      }) cfg.users
    );
  };
}
