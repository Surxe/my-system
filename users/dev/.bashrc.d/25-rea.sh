# --- REA (Reverse Engineer Anything) + Ghidra environment (dev user).
# REA's CLI (cloned + built at /srv/dev/repos/rea, npm-linked under nvm Node
# 24.22.1 -- run `nvm use 24` first; the nvm default stays 22) drives Ghidra
# through these. Ghidra is the pinned upstream release zip unpacked as dev
# (no auto-update: download + verify the next zip, then repoint this path).
# JDK 21 is Debian's openjdk-21-jdk. See users/dev/skills/README.md
# (reverse-engineer-anything) for the vendored skill.
export GHIDRA_INSTALL_DIR="$HOME/Applications/ghidra_12.1.4_PUBLIC"
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64

# Provider startup deadline covers import + auto-analysis. Default is 330000 ms
# (5.5 min); a first analysis of a large UE5 shipping exe (~190 MB) takes hours.
export REA_GHIDRA_STARTUP_TIMEOUT_MS=21600000   # 6 h
