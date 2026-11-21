"""Export After Silence using Godot's installed 4.7.2 desktop templates."""
from argparse import ArgumentParser
from pathlib import Path
import os
import shutil
import subprocess
import sys
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
TARGETS = {
    "windows": ("After Silence Windows", "AfterSilence.exe"),
    "linux": ("After Silence Linux", "AfterSilence.x86_64"),
    "pack": ("After Silence Linux", "AfterSilence.pck"),
}


def run_build(engine, *args):
    subprocess.run([engine, "--headless", "--path", str(ROOT), *args], check=True)


def package(target, binary, destination):
    docs = [(ROOT / "README_RU.md", "README_RU.md"),
            (ROOT / "BUILD_RU.md", "BUILD_RU.md"),
            (ROOT / "LICENSE", "Licenses/Little-Adventure-LICENSE.txt"),
            (ROOT / "after_silence/ASSET_PROVENANCE.md", "Licenses/ASSET_PROVENANCE.md")]
    for subdir, pattern, name in (
        ("after_silence/third_party", "*.txt", "Licenses"),
        ("after_silence/assets/fonts", "*OFL.txt", "Licenses/fonts"),
        ("addons/beehave", "LICENSE", "Licenses/beehave"),
        ("addons/npc_talkkit", "LICENSE", "Licenses/npc_talkkit"),
    ):
        docs.extend((item, f"{name}/{item.name}") for item in sorted((ROOT / subdir).glob(pattern)))
    for name in ("CHANGELOG.md", "PLAYTEST_RU.md", "PRE_RELEASE_AUDIT.md", "QA_PRE_RELEASE.md",
                 "SAVE_COMPATIBILITY.md", "PERFORMANCE_PRE_RELEASE.md", "KNOWN_ISSUES.md"):
        if (ROOT / name).is_file():
            docs.append((ROOT / name, name))
    items = [(binary, binary.name), *docs]
    if target == "linux":
        binary.chmod(binary.stat().st_mode | 0o111)
        with tarfile.open(destination / "AfterSilence-linux-x86_64.tar.gz", "w:gz") as archive:
            for item, name in items:
                archive.add(item, arcname=name)
    elif target == "windows":
        with zipfile.ZipFile(destination / "AfterSilence-windows-x86_64.zip", "w", zipfile.ZIP_DEFLATED) as archive:
            for item, name in items:
                archive.write(item, name)


def main():
    if os.name == "nt" and hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="backslashreplace")
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("target", choices=[*TARGETS, "all"])
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--output", type=Path, default=ROOT / "after_silence/build")
    args = parser.parse_args()
    engine = shutil.which(args.godot)
    if not engine:
        parser.error("Godot editor not found. Set --godot to its executable.")
    engine = str(Path(engine).resolve())
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    targets = ("windows", "linux") if args.target == "all" else (args.target,)
    run_build(engine, "--editor", "--import")
    for target in targets:
        preset, filename = TARGETS[target]
        destination = output / target
        destination.mkdir(parents=True, exist_ok=True)
        binary = destination / filename
        mode = "--export-pack" if target == "pack" else "--export-release"
        run_build(engine, mode, preset, str(binary))
        if not binary.is_file() or not binary.stat().st_size:
            raise RuntimeError(f"Godot did not create {binary}")
        package(target, binary, destination)
        print(binary)


if __name__ == "__main__":
    main()
