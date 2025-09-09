/// Configuration constants for Google Drive integration
class GoogleDriveConfig {
  // Template file IDs - These are the master templates to copy from
  static const String defaultTemplateFileId =
      '17bXUXVnETMzqzQ7JtlVPpm8p6Y2vMf8MpbyKxE2gyy8';

  // Target folder IDs - Where new logsheets will be created
  static const String defaultTargetFolderId =
      '1tJHamjKGq6KmXlhAVrmIEKze6ARLteGO';

  // Alternative templates for different generators (if needed)
  static const Map<String, String> generatorTemplates = {
    'Mitsubishi #1': '17bXUXVnETMzqzQ7JtlVPpm8p6Y2vMf8MpbyKxE2gyy8',
    'Mitsubishi #2': '17bXUXVnETMzqzQ7JtlVPpm8p6Y2vMf8MpbyKxE2gyy8',
    'Mitsubishi #3': '17bXUXVnETMzqzQ7JtlVPpm8p6Y2vMf8MpbyKxE2gyy8',
    'Mitsubishi #4': '17bXUXVnETMzqzQ7JtlVPpm8p6Y2vMf8MpbyKxE2gyy8',
  };

  // Folder structure for organizing by date/generator (if needed)
  static const Map<String, String> organizationFolders = {
    'daily': '1tJHamjKGq6KmXlhAVrmIEKze6ARLteGO',
    'archive': '1tJHamjKGq6KmXlhAVrmIEKze6ARLteGO',
  };

  /// Get template file ID for specific generator
  static String getTemplateFileId(String generatorName) {
    return generatorTemplates[generatorName] ?? defaultTemplateFileId;
  }

  /// Get target folder ID (can be extended for date-based organization)
  static String getTargetFolderId({
    String? dateFolder,
    String? organizationType,
  }) {
    // Future: Could organize by date or generator type
    return organizationFolders[organizationType] ?? defaultTargetFolderId;
  }
}
