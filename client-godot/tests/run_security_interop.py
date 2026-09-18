"""Offline CNG/DPAPI verification; imports the existing server decrypt function."""
import argparse
import ast
import base64
import json
import logging
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography.hazmat.primitives import serialization, hashes
from fastapi import HTTPException

PROJECT = Path(__file__).resolve().parents[1]

def server_crypto():
    # account.py also imports database/provider packages. Compile its exact
    # crypto functions without executing unrelated module initialization.
    source = PROJECT.parent / "server/src/system/user_interface/account.py"
    tree = ast.parse(source.read_text(encoding="utf-8"))
    names = {"generate_keys", "get_public_key_pem", "decrypt_password"}
    functions = [node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name in names]
    assert {node.name for node in functions} == names
    namespace = dict(rsa=rsa, padding=padding, serialization=serialization, hashes=hashes,
                     base64=base64, HTTPException=HTTPException, logger=logging.getLogger("interop"))
    exec(compile(ast.Module(body=functions, type_ignores=[]), str(source), "exec"), namespace)
    return SimpleNamespace(**namespace)


def run(godot: str) -> None:
    account = server_crypto()
    account.generate_keys()
    passwords = ["local-test-password", "测试密码 🎵", "x" * 190, "same-input", "same-input"]
    with tempfile.TemporaryDirectory(prefix="godot-security-") as directory:
        fixture = Path(directory) / "fixture.json"
        fixture.write_text(json.dumps({"public_key": account.get_public_key_pem(), "passwords": passwords}), encoding="utf-8")
        result = subprocess.run([godot, "--headless", "--path", str(PROJECT), "--script",
                                 "res://tests/test_windows_security.gd", "--", f"--fixture={fixture}"],
                                capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=45)
        print(result.stdout)
        if result.returncode or "ERROR:" in result.stdout + result.stderr:
            raise RuntimeError("Godot native contract failed; no server decryption attempted")
        ciphertexts = json.loads(Path(str(fixture) + ".out").read_text(encoding="utf-8"))
        assert len(ciphertexts) == len(passwords)
        for cipher, expected in zip(ciphertexts, passwords):
            assert account.decrypt_password(cipher) == expected, "Server decrypt mismatch"
        assert ciphertexts[-1] != ciphertexts[-2], "OAEP must be randomized"
    print("Existing Python decrypt_password interoperability: PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    arguments = parser.parse_args()
    run(arguments.godot)
