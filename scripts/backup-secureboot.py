#!/usr/bin/env python3
"""Encrypted recovery backup; run as the desktop user, not via sudo."""

import argparse
import fcntl
import hashlib
import os
from pathlib import Path
import pty
import secrets
import select
import shutil
import subprocess
import sys
import tempfile
import termios
import time
from datetime import datetime, timezone


ROOT_UUID = "d5607473-66c6-4336-b908-76c88228c592"
SWAP_UUID = "bdfb9b4b-cbce-42df-9d5b-2a283804122e"
VAULT = "geeky#ben"
ITEM = "em6hppzghpxzlmezdeabuccmyu"
REQUIRED = ["headers/root.header", "headers/swap.header", "metadata/bootctl.txt"]


def collect(repo, tools):
    if os.geteuid() != 0:
        raise RuntimeError("Collection requires root")
    cryptsetup, tar, bootctl, efibootmgr = tools
    # Plaintext LUKS headers only exist in root-only volatile memory storage.
    with tempfile.TemporaryDirectory(prefix="geeky-recovery-", dir="/run") as tmp:
        root = Path(tmp)
        (root / "headers").mkdir()
        (root / "metadata/efivars").mkdir(parents=True)
        for name, uuid in [("root", ROOT_UUID), ("swap", SWAP_UUID)]:
            subprocess.run([
                cryptsetup, "luksHeaderBackup", "/dev/disk/by-uuid/" + uuid,
                "--header-backup-file", str(root / "headers" / (name + ".header")),
            ], check=True, stdout=sys.stderr)
        for name, command in [
            ("bootctl.txt", [bootctl, "status", "--no-pager"]),
            ("efibootmgr.txt", [efibootmgr, "-v"]),
        ]:
            with (root / "metadata" / name).open("wb") as output:
                subprocess.run(command, check=True, stdout=output)
        efivars = Path("/sys/firmware/efi/efivars")
        for prefix in ["PK-", "KEK-", "db-", "dbx-", "Boot"]:
            for source in efivars.glob(prefix + "*"):
                if source.is_file():
                    shutil.copyfile(source, root / "metadata/efivars" / source.name)
        (root / "metadata/README.txt").write_text(
            "EFI variable snapshots include the efivarfs attribute prefix.\n"
            "Do not blindly copy them back to efivarfs.\n"
            "LUKS header restoration can re-enable old key slots.\n"
            "The nixconf directory includes uncommitted changes and Git history.\n"
            "This is a recovery backup, not a complete personal-data backup.\n"
        )
        command = [tar, "--format=pax", "-cf", "-", "-C", tmp, "headers", "metadata",
                   "-C", "/", "boot", "-C", str(repo.parent), repo.name]
        if Path("/var/lib/sbctl").exists():
            command += ["-C", "/", "var/lib/sbctl"]
        subprocess.run(command, check=True)


def start_age(arguments, source, output):
    master, slave = pty.openpty()
    attrs = termios.tcgetattr(slave)
    attrs[3] &= ~(termios.ECHO | termios.ECHONL)
    termios.tcsetattr(slave, termios.TCSANOW, attrs)

    def terminal():
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

    try:
        process = subprocess.Popen(
            [shutil.which("age"), *arguments], stdin=source, stdout=output,
            stderr=slave, pass_fds=(slave,), preexec_fn=terminal,
        )
    finally:
        os.close(slave)
    return process, master


def answer_prompts(process, master, password, expected):
    """Pass secrets through a private PTY, never argv, env or a log."""
    pending = b""
    answered = 0
    deadline = time.monotonic() + 3600
    try:
        while process.poll() is None:
            if time.monotonic() > deadline:
                raise RuntimeError("age timed out")
            ready, _, _ = select.select([master], [], [], 0.2)
            if not ready:
                continue
            try:
                chunk = os.read(master, 4096)
            except OSError:
                break
            if not chunk:
                break
            pending = (pending + chunk)[-8192:]
            if pending.endswith(b": ") and (
                b"passphrase" in pending.lower() or b"confirm" in pending.lower()
            ):
                if answered >= expected:
                    raise RuntimeError("Unexpected repeated age prompt")
                os.write(master, password + b"\n")
                answered += 1
                pending = b""
        code = process.wait(timeout=30)
        if code != 0 or answered != expected:
            # Deliberately do not emit terminal output, which could contain secrets.
            raise RuntimeError("age failed; terminal output suppressed")
    except BaseException:
        if process.poll() is None:
            process.kill()
            process.wait()
        raise
    finally:
        os.close(master)


def encrypt_and_verify(producer, target, password, required):
    stage = target.with_suffix(target.suffix + ".partial")
    if target.exists() or stage.exists():
        raise RuntimeError("Refusing to overwrite an existing backup")
    # Reserve the output filename before age opens it.
    with stage.open("xb"):
        pass
    try:
        enc, tty = start_age(["-p", "-o", str(stage)], producer.stdout, subprocess.DEVNULL)
        producer.stdout.close()
        answer_prompts(enc, tty, password, 2)
        if producer.wait() != 0:
            raise RuntimeError("Backup collection failed; backup is incomplete")
        dec, tty = start_age(["-d", str(stage)], subprocess.DEVNULL, subprocess.PIPE)
        listing = subprocess.Popen(
            [shutil.which("tar"), "-tf", "-", *required],
            stdin=dec.stdout, stdout=subprocess.PIPE,
        )
        dec.stdout.close()
        answer_prompts(dec, tty, password, 1)
        names, _ = listing.communicate(timeout=30)
        if listing.returncode or set(names.decode().splitlines()) != set(required):
            raise RuntimeError("Archive contents failed verification")
        stage.rename(target)
        with target.open("rb") as archive:
            digest = hashlib.file_digest(archive, "sha256").hexdigest()
        target.with_suffix(target.suffix + ".sha256").write_text(digest + "  " + target.name + "\n")
        subprocess.run(["sync", "-f", str(target)], check=True)
    except BaseException:
        if producer.poll() is None:
            producer.terminate()
            producer.wait()
        # Keep incomplete ciphertext for diagnosis; never label it as verified.
        raise


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--destination", default="/run/media/ben/Ventoy")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--collect", nargs=5, metavar=("REPO", "CRYPTSETUP", "TAR", "BOOTCTL", "EFIBOOTMGR"), help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.collect:
        collect(Path(args.collect[0]), args.collect[1:])
        return
    if args.self_test:
        with tempfile.TemporaryDirectory(prefix="age-test-", dir="/tmp/opencode") as tmp:
            source = Path(tmp)
            (source / "sample.txt").write_text("non-secret backup pipeline test\n")
            producer = subprocess.Popen(["tar", "-cf", "-", "-C", tmp, "sample.txt"], stdout=subprocess.PIPE)
            encrypt_and_verify(producer, source / "test.tar.age", secrets.token_hex(32).encode(), ["sample.txt"])
        print("PASS: streaming age encryption, passphrase prompts, decryption and tar verification")
        return
    if os.geteuid() == 0:
        raise RuntimeError("Run as your desktop user, not sudo; 1Password needs your session")
    destination = Path(args.destination).resolve()
    if not destination.is_mount():
        raise RuntimeError("Destination is not a mounted filesystem")
    source = subprocess.check_output(["findmnt", "-n", "-o", "SOURCE", "--target", str(destination)], text=True).strip()
    if source != "/dev/sda1":
        raise RuntimeError("Unexpected destination device; review before proceeding")
    if shutil.disk_usage(destination).free < 2 * 1024**3:
        raise RuntimeError("Less than 2 GiB free on backup device")
    tools = [shutil.which(name) for name in ["cryptsetup", "tar", "bootctl", "efibootmgr"]]
    if not all(tools) or not shutil.which("age"):
        raise RuntimeError("Missing tools; use the documented nix shell")
    subprocess.run(["sudo", "-v"], check=True)
    password = subprocess.check_output(
        ["op", "item", "get", ITEM, "--vault", VAULT, "--fields", "label=password", "--reveal"],
        stdin=subprocess.DEVNULL,
    ).rstrip(b"\r\n")
    if len(password) < 32 or b"\n" in password:
        raise RuntimeError("Unexpected backup passphrase")
    repo = Path(__file__).resolve().parent.parent
    folder = destination / "Backups/geeky/secureboot"
    folder.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    target = folder / (stamp + "-pre-secureboot.tar.age")
    print("Backing up EFI, LUKS headers, boot metadata and", repo, flush=True)
    producer = subprocess.Popen([
        "sudo", "-n", sys.executable, str(Path(__file__).resolve()),
        "--collect", str(repo), *tools,
    ], stdout=subprocess.PIPE)
    encrypt_and_verify(producer, target, password, REQUIRED)
    print("Verified encrypted recovery backup:", target)
    print("Passphrase: 1Password →", VAULT, "→ geeky Secure Boot recovery backup (age)")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.SubprocessError, OSError) as error:
        sys.exit(str(error))
