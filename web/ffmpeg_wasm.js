/**
 * FFmpeg.wasm Bridge - loads @ffmpeg/ffmpeg from CDN and exposes
 * a simple global API for Dart interop.
 */
(function () {
  'use strict';

  let ffmpeg = null;
  let isLoaded = false;
  let progressCallback = null;
  let logCallback = null;

  // Load @ffmpeg/ffmpeg from CDN
  async function loadFFmpegPackage() {
    const { FFmpeg } = await import(
      'https://cdn.jsdelivr.net/npm/@ffmpeg/ffmpeg@0.12.10/+esm'
    );
    const { toBlobURL, fetchFile } = await import(
      'https://cdn.jsdelivr.net/npm/@ffmpeg/util@0.12.10/+esm'
    );
    return { FFmpeg, toBlobURL, fetchFile };
  }

  // Initialize and load ffmpeg-core (WASM)
  window.ffmpegWasmLoad = async function () {
    if (isLoaded) return true;

    try {
      const { FFmpeg, toBlobURL } = await loadFFmpegPackage();

      ffmpeg = new FFmpeg();

      // Set up log callback
      ffmpeg.on('log', ({ message }) => {
        console.log('[ffmpeg.wasm]', message);
        if (logCallback) {
          logCallback(message);
        }
      });

      // Set up progress callback
      ffmpeg.on('progress', ({ progress, time }) => {
        if (progressCallback) {
          progressCallback(progress, time);
        }
      });

      // Load ffmpeg-core WASM from CDN
      const baseURL = 'https://cdn.jsdelivr.net/npm/@ffmpeg/core@0.12.10/dist/umd';
      await ffmpeg.load({
        coreURL: await toBlobURL(`${baseURL}/ffmpeg-core.js`, 'text/javascript'),
        wasmURL: await toBlobURL(`${baseURL}/ffmpeg-core.wasm`, 'application/wasm'),
      });

      isLoaded = true;
      return true;
    } catch (err) {
      console.error('[ffmpeg.wasm] Failed to load:', err);
      isLoaded = false;
      return false;
    }
  };

  // Check if ffmpeg.wasm is loaded
  window.ffmpegWasmIsLoaded = function () {
    return isLoaded;
  };

  // Write a file to ffmpeg.wasm virtual filesystem
  window.ffmpegWasmWriteFile = async function (fileName, uint8Array) {
    if (!ffmpeg || !isLoaded) throw new Error('FFmpeg not loaded');
    await ffmpeg.writeFile(fileName, new Uint8Array(uint8Array));
    return true;
  };

  // Execute ffmpeg command
  window.ffmpegWasmExec = async function (args) {
    if (!ffmpeg || !isLoaded) throw new Error('FFmpeg not loaded');
    const exitCode = await ffmpeg.exec(args);
    return exitCode;
  };

  // Read a file from ffmpeg.wasm virtual filesystem
  window.ffmpegWasmReadFile = async function (fileName) {
    if (!ffmpeg || !isLoaded) throw new Error('FFmpeg not loaded');
    const data = await ffmpeg.readFile(fileName);
    // data is Uint8Array, return it as plain array for Dart interop
    return Array.from(data);
  };

  // Delete a file from virtual filesystem
  window.ffmpegWasmDeleteFile = async function (fileName) {
    if (!ffmpeg || !isLoaded) return false;
    try {
      await ffmpeg.deleteFile(fileName);
      return true;
    } catch {
      return false;
    }
  };

  // Set progress callback (receives progress 0.0-1.0 and time in microseconds)
  window.ffmpegWasmOnProgress = function (callback) {
    progressCallback = callback;
  };

  // Set log callback
  window.ffmpegWasmOnLog = function (callback) {
    logCallback = callback;
  };

  // Terminate ffmpeg.wasm (cleanup)
  window.ffmpegWasmTerminate = function () {
    if (ffmpeg) {
      try { ffmpeg.terminate(); } catch (_) {}
    }
    ffmpeg = null;
    isLoaded = false;
    progressCallback = null;
    logCallback = null;
  };
})();
