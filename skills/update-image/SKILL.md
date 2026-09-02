---
name: update-image
description: Update Docker image versions in dockerfile-deps. Use when adding or bumping an image, Dockerfile dependency, version, or revision and opening an update/<image>/<version> PR that must pass Build Only CI.
---

# Update An Image

Use this process to add or update an image without publishing it. Do not create
or push a release tag as part of an update PR; tags run the Build and Publish
workflow and publish to Docker Hub.

## Choose The Image Tag

Image tags use this format:

```text
<Image>/<version>(-<revision>)?
```

Examples:

```text
Bitcoin/31.1
Bitcoin/31.1-1
```

Match the image name's case to its top-level directory. The optional revision
is part of the image tag but not the source directory: both examples above use
files from `Bitcoin/31.1/`. The scripts treat everything after the first `-` in
the version component as the revision.

## Prepare The Change

1. Check `git status` and preserve changes that are not part of the update.
2. Start from an up-to-date `master` unless the user specifies another base.
3. Create a branch whose name is exactly the image tag prefixed with `update/`:

```bash
git switch master
git pull --ff-only
git switch -c update/Bitcoin/31.1-1
```

The branch must have exactly these three slash-separated components:
`update/<Image>/<version>(-<revision>)?`. The Build Only workflow uses the
branch name to determine which image to build.

4. Inspect the previous version and the upstream project's release artifacts
before editing. Do not guess artifact URLs, checksums, signatures, platforms,
or build arguments.
5. Add or update `<Image>/<version>/`. Reuse the repository's existing layout
for that image. Supported Dockerfile names are:

```text
linuxamd64.Dockerfile
linuxarm32v7.Dockerfile
linuxarm64v8.Dockerfile
Dockerfile
```

Architecture-specific Dockerfiles produce separate images. A plain
`Dockerfile` is built with Buildx for `linux/amd64`, `linux/arm64`, and
`linux/arm/v7`. Missing variants are skipped by CI, so only add platforms that
the upstream release and image genuinely support.

6. Keep architecture variants consistent where applicable. Verify download
URLs, version values, checksums, entrypoints, copied files, and executable bits.
7. Review the full diff and run relevant local syntax or static checks. If a
local Docker build is practical, build the affected Dockerfile using the same
directory as its build context.

## Open And Verify The PR

1. Commit only files belonging to the image update.
2. Push the `update/<Image>/<version>(-<revision>)?` branch and open a PR to
`master`. Summarize the upstream version, supported architectures, provenance,
and local validation.
3. Wait for every Build Only matrix job to finish:

```bash
gh pr checks --watch
```

4. If a build fails, inspect the failed logs, fix the image files on the same
branch, push the fix, and watch the rerun:

```bash
gh run view <run-id> --log-failed
gh pr checks --watch
```

5. Do not report the update as complete until all required Build Only checks
pass. Explicitly report intentionally skipped architectures and any checks that
could not be run.

The PR workflow only builds images. Merging the PR does not publish them;
publishing is a separate maintainer action performed by pushing the matching
`<Image>/<version>(-<revision>)?` tag.
