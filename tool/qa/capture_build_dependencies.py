"""Track project-owned Dart inputs for isolated QA capture web builds."""

import re
from pathlib import Path


_DART_DIRECTIVE = re.compile(r"^(?:import|export|part)\b(.*?);", re.M | re.S)
_DART_URI = re.compile(r"['\"]([^'\"]+)['\"]")


def _local_dart_dependencies(root: Path, entrypoint: Path) -> set[Path]:
    root = root.resolve()
    pending = [entrypoint.resolve()]
    dependencies = set()

    while pending:
        source = pending.pop()
        if source in dependencies:
            continue
        dependencies.add(source)
        if not source.is_file():
            continue

        for directive in _DART_DIRECTIVE.findall(source.read_text(encoding="utf-8")):
            for uri in _DART_URI.findall(directive):
                if uri.startswith("package:stroom/"):
                    dependency = root / "lib" / uri.removeprefix("package:stroom/")
                elif ":" not in uri:
                    dependency = source.parent / uri
                else:
                    continue

                dependency = dependency.resolve()
                if dependency == root or root in dependency.parents:
                    pending.append(dependency)

    return dependencies


def _build_configuration_inputs(root: Path, dependencies: set[Path]) -> set[Path]:
    inputs = {
        root / "pubspec.yaml",
        root / "pubspec.lock",
        root / "l10n.yaml",
        root / "web/index.html",
    }
    if any(path.parent == root / "lib/l10n" for path in dependencies):
        inputs.update((root / "lib/l10n").glob("*.arb"))
    return {path.resolve() for path in inputs if path.is_file()}


def capture_build_inputs(root: Path, entrypoint: Path) -> set[Path]:
    """Return the capture's transitive Dart sources and Flutter build inputs."""
    root = root.resolve()
    entrypoint = entrypoint.resolve()
    dependencies = _local_dart_dependencies(root, entrypoint)
    return dependencies | _build_configuration_inputs(root, dependencies)


def needs_rebuild(root: Path, entrypoint: Path, bundle: Path) -> bool:
    """Check whether any source input is newer than the bundle sentinel."""
    bundle = bundle.resolve()
    if not bundle.is_file():
        return True

    bundle_mtime = bundle.stat().st_mtime_ns
    for dependency in capture_build_inputs(root, entrypoint):
        if not dependency.is_file() or dependency.stat().st_mtime_ns > bundle_mtime:
            return True
    return False
