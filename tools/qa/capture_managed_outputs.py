from pathlib import Path


COMPACT_ROW_OUTPUT_PATTERNS = (
    "voice-index-fitting-1x.png",
    "voice-index-fitting-1x-dark.png",
    "voice-index-scaled-high-count-2x.png",
    "voice-index-scaled-high-count-2x-dark.png",
    "voice-index-scaled-narrow-2x.png",
    "voice-index-scaled-narrow-2x-dark.png",
    "voice-index-rtl-narrow-2x.png",
    "voice-index-rtl-narrow-2x-dark.png",
)
RESPONSIVE_MEDIA_OUTPUT_PATTERNS = (
    "media-picker-fr-320x640-scale1-light.png",
    "media-picker-fr-320x640-scale3-light.png",
    "media-picker-fr-320x640-scale3-reveal.webm",
    "mermaid-loading-fr-320x640-scale1-light.png",
    "mermaid-loading-fr-320x640-scale3-light.png",
)


class CaptureOutputs:
    def __init__(self, directory, patterns):
        self.directory = Path(directory)
        self.patterns = patterns
        self._names = []

    def clear(self):
        for pattern in self.patterns:
            for path in self.directory.glob(pattern):
                if path.is_file():
                    path.unlink()

    def write(self, name, contents):
        (self.directory / name).write_bytes(contents)
        self._names.append(name)

    def record(self, name):
        self._names.append(name)

    @property
    def names(self):
        return sorted(self._names)
