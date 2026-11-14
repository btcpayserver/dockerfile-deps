import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
IMAGE = "application/vnd.oci.image.manifest.v1+json"
INDEX = "application/vnd.oci.image.index.v1+json"
DOCKER_IMAGE = "application/vnd.docker.distribution.manifest.v2+json"
DOCKER_INDEX = "application/vnd.docker.distribution.manifest.list.v2+json"
SUFFIXES = {"amd64": "linuxamd64", "arm64v8": "linuxarm64v8", "arm32v7": "linuxarm32v7"}
DIGESTS = {suffix: "sha256:" + str(i) * 64 for i, suffix in enumerate(SUFFIXES, 1)}
TAG = "btcpayserver/example:1.0"


def index(suffix, media_type=INDEX):
    return {
        "mediaType": media_type,
        "manifests": [
            {
                "mediaType": IMAGE,
                "digest": DIGESTS[suffix],
                # Cross-compiled images can inherit the builder's platform metadata.
                "platform": {"os": "linux", "architecture": "amd64"},
            },
            {
                "mediaType": IMAGE,
                "digest": "sha256:" + "a" * 64,
                "platform": {"os": "unknown", "architecture": "unknown"},
                "annotations": {"vnd.docker.reference.type": "attestation-manifest"},
            },
        ],
    }


class PublishManifestTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        shutil.copytree(ROOT / ".github/scripts", self.root / ".github/scripts")
        self.image_dir = self.root / "Example/1.0"
        self.image_dir.mkdir(parents=True)
        self.bin_dir = self.root / "bin"
        self.bin_dir.mkdir()
        # Intercept all sudo/docker invocations: tests never log in or publish.
        sudo = self.bin_dir / "sudo"
        sudo.write_text("""#!/usr/bin/env python3
import json, os, pathlib, sys
args = sys.argv[1:]
with open(os.environ["CALL_LOG"], "a") as log:
    log.write(json.dumps(args) + "\\n")
assert args.pop(0) == "docker"
assert args.pop(0) == "-H=unix:///test.sock"
if args[:4] == ["buildx", "imagetools", "inspect", "--raw"]:
    if os.environ.get("FAIL_INSPECT"):
        sys.exit(1)
    fixtures = json.loads(pathlib.Path(os.environ["FIXTURES"]).read_text())
    print(json.dumps(fixtures[args[4]]))
elif args[:2] == ["manifest", "annotate"] and os.environ.get("FAIL_ANNOTATE"):
    sys.exit(1)
""")
        sudo.chmod(0o755)

    def run_publisher(self, manifests, **extra_env):
        for suffix in manifests:
            (self.image_dir / f"{SUFFIXES[suffix]}.Dockerfile").touch()
        fixtures = self.root / "fixtures.json"
        fixtures.write_text(json.dumps({f"{TAG}-{suffix}": value for suffix, value in manifests.items()}))
        log = self.root / "calls.jsonl"
        result = subprocess.run(
            ["bash", ".github/scripts/publish-manifest.sh"],
            cwd=self.root,
            env=dict(
                os.environ,
                PATH=str(self.bin_dir) + os.pathsep + os.environ["PATH"],
                CI_TAG="Example/1.0",
                DOCKER_HOST="unix:///test.sock",
                DOCKERHUB_USER="test-user",
                DOCKERHUB_PASS="test-password",
                FIXTURES=str(fixtures),
                CALL_LOG=str(log),
                **extra_env,
            ),
            capture_output=True,
            text=True,
        )
        calls = [json.loads(line)[2:] for line in log.read_text().splitlines()]
        return result, calls

    def assert_publication(self, calls, images, suffixes):
        self.assertIn(["manifest", "create", "--amend", TAG, *images], calls)
        for image, suffix in zip(images, suffixes):
            arch, variant = {
                "amd64": ("amd64", None),
                "arm64v8": ("arm64", "v8"),
                "arm32v7": ("arm", "v7"),
            }[suffix]
            annotation = ["manifest", "annotate", TAG, image, "--os", "linux", "--arch", arch]
            if variant:
                annotation += ["--variant", variant]
            self.assertIn(annotation, calls)
        self.assertEqual(calls[-1], ["manifest", "push", TAG, "-p"])

    def test_oci_indexes_with_attestations(self):
        result, calls = self.run_publisher({suffix: index(suffix) for suffix in SUFFIXES})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_publication(
            calls, [f"btcpayserver/example@{DIGESTS[s]}" for s in SUFFIXES], SUFFIXES
        )

    def test_docker_manifest_list(self):
        result, calls = self.run_publisher({"arm64v8": index("arm64v8", DOCKER_INDEX)})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_publication(calls, [f"btcpayserver/example@{DIGESTS['arm64v8']}"], ["arm64v8"])

    def test_legacy_plain_manifests(self):
        result, calls = self.run_publisher(
            {"amd64": {"mediaType": DOCKER_IMAGE}, "arm32v7": {"mediaType": IMAGE}}
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_publication(calls, [f"{TAG}-amd64", f"{TAG}-arm32v7"], ["amd64", "arm32v7"])

    def test_no_architecture_dockerfiles(self):
        result, calls = self.run_publisher({})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Skipping", result.stdout)
        self.assertFalse(any(c[:1] == ["manifest"] for c in calls))

    def test_ambiguous_or_invalid_indexes_fail_before_creation(self):
        valid = index("amd64")["manifests"][0]
        for descriptors in ([], [valid, valid], [{**valid, "digest": "invalid"}]):
            with self.subTest(descriptors=descriptors):
                result, calls = self.run_publisher({"amd64": {"mediaType": INDEX, "manifests": descriptors}})
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(any(c[:1] == ["manifest"] for c in calls))

    def test_unsupported_format_fails_before_creation(self):
        result, calls = self.run_publisher({"amd64": {"mediaType": "unexpected"}})
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(c[:1] == ["manifest"] for c in calls))

    def test_inspection_failure_aborts(self):
        result, calls = self.run_publisher({"amd64": index("amd64")}, FAIL_INSPECT="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(c[:1] == ["manifest"] for c in calls))

    def test_annotation_failure_prevents_push(self):
        result, calls = self.run_publisher({"amd64": index("amd64")}, FAIL_ANNOTATE="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(c[:2] == ["manifest", "push"] for c in calls))


if __name__ == "__main__":
    unittest.main()
