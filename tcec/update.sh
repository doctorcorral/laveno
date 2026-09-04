#!/usr/bin/env bash
# TCEC build script. Produces a Linux x86_64 UCI binary named `laveno`
# in the repository root. Cute Chess should be pointed at that file.
#
# Usage (from anywhere):
#   export VERSION=main          # optional git ref, default: current tree
#   ./tcec/update.sh
#
# The TCEC compile hosts have gcc/clang/java/python/rust, not Elixir.
# This script installs a local OTP + Elixir toolchain under ./vendor
# when `mix` is not already on PATH.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${VERSION:-}"
OTP_VERSION="${OTP_VERSION:-27.3.4}"
ELIXIR_VERSION="${ELIXIR_VERSION:-1.18.4}"
VENDOR="$ROOT/vendor"

if [[ -n "$VERSION" ]] && [[ -d "$ROOT/.git" ]]; then
  git fetch --tags --force origin 2>/dev/null || true
  git checkout "$VERSION"
fi

have_mix() {
  command -v mix >/dev/null 2>&1 && command -v erl >/dev/null 2>&1
}

install_toolchain() {
  mkdir -p "$VENDOR"
  export PATH="$VENDOR/elixir/bin:$VENDOR/otp/bin:$PATH"

  if have_mix; then
    return 0
  fi

  echo "mix/erl not found; installing OTP ${OTP_VERSION} and Elixir ${ELIXIR_VERSION} into vendor/"

  if [[ ! -x "$VENDOR/otp/bin/erl" ]]; then
    otp_tarball="otp_src_${OTP_VERSION}.tar.gz"
    # Prefer prebuilt Ubuntu/Debian OTP when possible; otherwise compile from source.
    if command -v apt-get >/dev/null 2>&1 && [[ "$(id -u)" -eq 0 ]]; then
      apt-get update
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        erlang elixir git make curl ca-certificates
      return 0
    fi

    if [[ ! -d "$VENDOR/otp" ]]; then
      curl -fsSL "https://github.com/erlang/otp/releases/download/OTP-${OTP_VERSION}/otp_src_${OTP_VERSION}.tar.gz" \
        -o "$VENDOR/${otp_tarball}"
      tar -C "$VENDOR" -xzf "$VENDOR/${otp_tarball}"
      (
        cd "$VENDOR/otp_src_${OTP_VERSION}"
        ./configure --prefix="$VENDOR/otp" --without-javac --without-odbc
        make -j"$(nproc 2>/dev/null || echo 4)"
        make install
      )
    fi
  fi

  if [[ ! -x "$VENDOR/elixir/bin/mix" ]]; then
    curl -fsSL "https://github.com/elixir-lang/elixir/releases/download/v${ELIXIR_VERSION}/elixir-otp-27.zip" \
      -o "$VENDOR/elixir.zip"
    mkdir -p "$VENDOR/elixir"
    VENDOR="$VENDOR" python3 - <<'PY' || unzip -q -o "$VENDOR/elixir.zip" -d "$VENDOR/elixir"
import zipfile, os
root = os.environ["VENDOR"]
z = zipfile.ZipFile(os.path.join(root, "elixir.zip"))
z.extractall(os.path.join(root, "elixir"))
PY
  fi

  export PATH="$VENDOR/elixir/bin:$VENDOR/otp/bin:$PATH"
}

install_toolchain

if ! have_mix; then
  echo "error: could not find or install mix/erl" >&2
  exit 1
fi

export MIX_ENV=prod
mix local.hex --force
mix local.rebar --force
mix deps.get --only prod
mix escript.build

chmod +x "$ROOT/laveno"
ln -sfn "$ROOT/laveno" "$ROOT/laveno_linux_x64"

echo "Built $ROOT/laveno"
"$ROOT/laveno" <<'EOF' || true
uci
isready
bench
quit
EOF
