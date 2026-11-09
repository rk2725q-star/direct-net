import 'package:equatable/equatable.dart';

/// Real-time bandwidth statistics for a tunnel or peer
class BandwidthStat extends Equatable {
  final double uploadBytesPerSec;
  final double downloadBytesPerSec;
  final int totalUploadBytes;
  final int totalDownloadBytes;
  final DateTime? timestamp;

  const BandwidthStat({
    required this.uploadBytesPerSec,
    required this.downloadBytesPerSec,
    required this.totalUploadBytes,
    required this.totalDownloadBytes,
    this.timestamp,
  });

  static const zero = BandwidthStat(
    uploadBytesPerSec: 0,
    downloadBytesPerSec: 0,
    totalUploadBytes: 0,
    totalDownloadBytes: 0,
    timestamp: null,
  );

  /// Format bytes/sec to human-readable string (e.g. "2.4 MB/s")
  static String formatSpeed(double bytesPerSec) {
    if (bytesPerSec < 1024) return '${bytesPerSec.toStringAsFixed(0)} B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  /// Format bytes to human-readable string (e.g. "150 MB")
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get uploadSpeedFormatted => formatSpeed(uploadBytesPerSec);
  String get downloadSpeedFormatted => formatSpeed(downloadSpeedFormattedValue);
  double get downloadSpeedFormattedValue => downloadBytesPerSec;
  String get totalUploadFormatted => formatBytes(totalUploadBytes);
  String get totalDownloadFormatted => formatBytes(totalDownloadBytes);

  /// Create an empty/zero stat with the current timestamp
  factory BandwidthStat.empty() => BandwidthStat(
        uploadBytesPerSec: 0,
        downloadBytesPerSec: 0,
        totalUploadBytes: 0,
        totalDownloadBytes: 0,
        timestamp: DateTime.now(),
      );

  @override
  List<Object?> get props =>
      [uploadBytesPerSec, downloadBytesPerSec, timestamp];
}
