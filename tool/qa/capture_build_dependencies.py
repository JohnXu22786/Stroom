"""Track project-owned Dart inputs for isolated QA capture web builds."""

import re
from pathlib import Path


_DART_DIRECTIVES = {"import", "export", "part"}
_LOCAL_DEPENDENCY_SECTIONS = {"dependencies", "dev_dependencies", "dependency_overrides"}


def _skip_comment(source: str, index: int) -> int:
    if source.startswith("//", index):
        newline = source.find("\n", index + 2)
        return len(source) if newline == -1 else newline + 1
    if source.startswith("/*", index):
        depth = 1
        index += 2
        while index < len(source) and depth:
            if source.startswith("/*", index):
                depth += 1
                index += 2
            elif source.startswith("*/", index):
                depth -= 1
                index += 2
            else:
                index += 1
        return index
    return index


def _read_string(source: str, index: int) -> tuple[str, int]:
    quote = source[index]
    delimiter = quote * 3 if source.startswith(quote * 3, index) else quote
    index += len(delimiter)
    start = index
    while index < len(source):
        if source[index] == "\\":
            index += 2
        elif source.startswith(delimiter, index):
            return source[start:index], index + len(delimiter)
        else:
            index += 1
    return source[start:], len(source)


def _skip_trivia(source: str, index: int) -> int:
    while index < len(source):
        if source[index].isspace():
            index += 1
        elif source.startswith(("//", "/*"), index):
            index = _skip_comment(source, index)
        else:
            break
    return index


def _parse_directive(source: str, index: int, keyword: str):
    uri_start = _skip_trivia(source, index)
    if keyword == "part" and source.startswith("of", uri_start):
        after_of = uri_start + 2
        if after_of == len(source) or not (
            source[after_of].isalnum() or source[after_of] == "_"
        ):
            uri_start = _skip_trivia(source, after_of)
    if uri_start >= len(source):
        return None
    if source[uri_start] not in "'\"" and not (
        source[uri_start] in "rR"
        and uri_start + 1 < len(source)
        and source[uri_start + 1] in "'\""
    ):
        return None

    uris = []
    while index < len(source):
        if source.startswith(("//", "/*"), index):
            index = _skip_comment(source, index)
        elif source[index] == ";":
            return uris, index + 1
        elif source[index] in "'\"":
            uri, index = _read_string(source, index)
            uris.append(uri)
        else:
            index += 1
    return uris, index


def _dart_directive_uris(source: str):
    index = 0
    statement_start = True
    while index < len(source):
        if source.startswith(("//", "/*"), index):
            end = _skip_comment(source, index)
            if "\n" in source[index:end]:
                statement_start = True
            index = end
            continue
        if source[index].isspace():
            if source[index] == "\n":
                statement_start = True
            index += 1
            continue
        if source[index] in "'\"":
            _, index = _read_string(source, index)
            statement_start = False
            continue
        if source[index].isalpha() or source[index] in "_$":
            start = index
            index += 1
            while index < len(source) and (
                source[index].isalnum() or source[index] in "_$"
            ):
                index += 1
            keyword = source[start:index]
            if keyword in _DART_DIRECTIVES and statement_start:
                parsed = _parse_directive(source, index, keyword)
                if parsed is not None:
                    uris, index = parsed
                    yield from uris
                    statement_start = True
                    continue
            statement_start = False
            continue
        statement_start = source[index] == ";"
        index += 1


def _local_path_packages(root: Path) -> dict[str, Path]:
    pubspec = root / "pubspec.yaml"
    if not pubspec.is_file():
        return {}

    section = None
    package_key = None
    packages = {}
    for line in pubspec.read_text(encoding="utf-8").splitlines():
        top_level = re.match(r"^([A-Za-z_][\w-]*):(?:\s|$)", line)
        if top_level:
            section = top_level.group(1)
            package_key = None
            continue
        if section not in _LOCAL_DEPENDENCY_SECTIONS:
            continue

        inline_dependency = re.match(
            r"^  ([A-Za-z0-9_-]+):\s*\{(.*)\}\s*(?:#.*)?$", line
        )
        if inline_dependency:
            inline_path = re.search(
                r"(?:^|,)\s*path:\s*([^,}]+)", inline_dependency.group(2)
            )
            if inline_path:
                _register_local_path_package(
                    root,
                    inline_dependency.group(1),
                    inline_path.group(1),
                    packages,
                )
            continue

        dependency = re.match(r"^  ([A-Za-z0-9_-]+):\s*$", line)
        if dependency:
            package_key = dependency.group(1)
            continue

        path = re.match(r"^    path:\s*(.+?)\s*(?:#.*)?$", line)
        if not path or not package_key:
            continue
        _register_local_path_package(root, package_key, path.group(1), packages)
        package_key = None

    return packages


def _register_local_path_package(
    root: Path, package_key: str, path: str, packages: dict[str, Path]
) -> None:
    package_root = (root / path.strip(" '\" ")).resolve()
    if root not in package_root.parents:
        return

    package_pubspec = package_root / "pubspec.yaml"
    if not package_pubspec.is_file():
        return
    declared_name = re.search(
        r"^name:\s*['\"]?([A-Za-z0-9_-]+)",
        package_pubspec.read_text(encoding="utf-8"),
        re.M,
    )
    if declared_name and declared_name.group(1) == package_key:
        packages[package_key] = package_root


def _local_dart_dependencies(
    root: Path, entrypoint: Path, local_packages: dict[str, Path]
) -> set[Path]:
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

        for uri in _dart_directive_uris(source.read_text(encoding="utf-8")):
            if uri.startswith("package:"):
                package_name, separator, package_path = uri[8:].partition("/")
                if package_name == "stroom":
                    dependency = root / "lib" / package_path
                elif package_name in local_packages:
                    dependency = local_packages[package_name] / "lib" / package_path
                else:
                    continue
            elif ":" not in uri:
                dependency = source.parent / uri
            else:
                continue

            dependency = dependency.resolve()
            if dependency == root or root in dependency.parents:
                pending.append(dependency)

    return dependencies


def _build_configuration_inputs(
    root: Path, dependencies: set[Path], local_packages: dict[str, Path]
) -> set[Path]:
    inputs = {
        root / "pubspec.yaml",
        root / "pubspec.lock",
        root / "l10n.yaml",
        root / "web/index.html",
    }
    if any(path.parent == root / "lib/l10n" for path in dependencies):
        inputs.update((root / "lib/l10n").glob("*.arb"))
    for package_root in local_packages.values():
        package_lib = package_root / "lib"
        if any(path == package_lib or package_lib in path.parents for path in dependencies):
            inputs.add(package_root / "pubspec.yaml")
    return {path.resolve() for path in inputs if path.is_file()}


def capture_build_inputs(root: Path, entrypoint: Path) -> set[Path]:
    """Return the capture's transitive Dart sources and Flutter build inputs."""
    root = root.resolve()
    entrypoint = entrypoint.resolve()
    local_packages = _local_path_packages(root)
    dependencies = _local_dart_dependencies(root, entrypoint, local_packages)
    return dependencies | _build_configuration_inputs(root, dependencies, local_packages)


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
