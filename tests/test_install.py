import os
from pathlib import Path
import subprocess
import tempfile
import textwrap
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
INSTALLER = REPO_ROOT / "install.sh"


class InstallScriptTests(unittest.TestCase):
    def test_installs_with_pipx_ensures_path_and_verifies_launcher(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            home = temp / "home"
            bin_dir = home / ".local" / "bin"
            home.mkdir()
            fake_pipx = temp / "pipx"
            log = temp / "pipx.log"
            fake_pipx.write_text(
                textwrap.dedent(
                    """\
                    #!/usr/bin/env bash
                    set -euo pipefail
                    printf '%s\\n' "$*" >> "$FAKE_PIPX_LOG"
                    case "${1:-}" in
                      --version)
                        printf '%s\\n' '1.7.1'
                        ;;
                      ensurepath)
                        printf '%s\\n' 'PATH updated'
                        ;;
                      install)
                        install_source="${@: -1}"
                        mkdir -p "$install_source/build" "$install_source/channel_surfer.egg-info"
                        mkdir -p "$PIPX_BIN_DIR"
                        cat > "$PIPX_BIN_DIR/channel-surfer" <<'EOF'
                    #!/usr/bin/env bash
                    exit 0
                    EOF
                        chmod +x "$PIPX_BIN_DIR/channel-surfer"
                        ;;
                      *)
                        exit 2
                        ;;
                    esac
                    """
                )
            )
            fake_pipx.chmod(0o755)

            env = os.environ.copy()
            env.update(
                {
                    "HOME": str(home),
                    "PIPX_BIN_DIR": str(bin_dir),
                    "CHANNEL_SURFER_PIPX": str(fake_pipx),
                    "FAKE_PIPX_LOG": str(log),
                    "PATH": "/usr/bin:/bin",
                }
            )
            result = subprocess.run(
                ["bash", str(INSTALLER)],
                cwd=REPO_ROOT,
                env=env,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
            )

            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertTrue((bin_dir / "channel-surfer").is_file())
            self.assertTrue(os.access(bin_dir / "channel-surfer", os.X_OK))
            calls = log.read_text().splitlines()
            self.assertIn("--version", calls)
            self.assertIn("ensurepath --force", calls)
            install_call = next(call for call in calls if call.startswith("install --force "))
            install_source = Path(install_call.removeprefix("install --force "))
            self.assertNotEqual(install_source, REPO_ROOT)
            self.assertFalse(install_source.exists())
            self.assertFalse((REPO_ROOT / "build").exists())
            self.assertFalse((REPO_ROOT / "channel_surfer.egg-info").exists())
            self.assertIn("Channel Surfer installed successfully", result.stdout)
            self.assertIn(str(bin_dir / "channel-surfer"), result.stdout)


if __name__ == "__main__":
    unittest.main()
