此目录可选。将 FFmpeg 二进制文件放在此处可在构建时打包进应用，
避免首次使用时从网络下载。参见 lib/utils/ffmpeg_resolver.dart。

Windows: ffmpeg_windows.exe
Linux:   ffmpeg_linux

若不留在此处，应用会在首次使用时自动从 CDN 下载。
