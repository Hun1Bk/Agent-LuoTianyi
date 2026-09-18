"""Build the Windows-only credential extension against the locked godot-cpp."""
import argparse
import codecs
import encodings.oem
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

parser = argparse.ArgumentParser()
parser.add_argument("--godot-cpp", type=Path, required=True)
args = parser.parse_args()
project = Path(__file__).resolve().parents[1]
lock = json.loads((project / "dependencies.lock.json").read_text())
cpp = args.godot_cpp.absolute()
revision = subprocess.check_output(["git", "-C", str(cpp), "rev-parse", "HEAD"], text=True).strip()
if revision != lock["gd_cubism"]["godot_cpp_commit"]:
    raise RuntimeError("godot-cpp revision differs from dependency lock")
import SCons
if SCons.__version__ != lock["native_build"]["scons"]:
    raise RuntimeError("SCons version differs from dependency lock")
encodings.oem.oem_decode = lambda data, errors="strict", final=False: (bytes(data).decode("utf-8", errors), len(data))
os.chdir(project / "native")
sys.argv = ["scons", "platform=windows", "arch=x86_64", "target=template_release", f"godot_cpp={cpp}", "-j8"]
from SCons.Script import main
try:
    main()
except SystemExit as result:
    if result.code not in (0, None):
        raise
binary = project / "addons/windows_security/bin/windows_security.dll"
print("WindowsSecurity SHA256:", hashlib.file_digest(binary.open("rb"), "sha256").hexdigest())
