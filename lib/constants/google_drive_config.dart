/// Configuration constants for Google Drive integration
class GoogleDriveConfig {
  // Template file IDs - These are the master templates to copy from
  static const String defaultTemplateFileId =
      '1ZElJZHe1oMUXN1aGcM0-n8i5vXZNYT-V';

  // Target folder IDs - Where new logsheets will be created
  static const String defaultTargetFolderId =
      '1Q7Vp2k4U8YxM9Nz3L6JhK2MpR4YvW7Tc';

  // Alternative templates for different generators (if needed)
  static const Map<String, String> generatorTemplates = {
    'Mitsubishi #1': '1ZElJZHe1oMUXN1aGcM0-n8i5vXZNYT-V',
    'Mitsubishi #2': '1ZElJZHe1oMUXN1aGcM0-n8i5vXZNYT-V',
    'Mitsubishi #3': '1ZElJZHe1oMUXN1aGcM0-n8i5vXZNYT-V',
    'Mitsubishi #4': '1ZElJZHe1oMUXN1aGcM0-n8i5vXZNYT-V',
  };

  // Folder structure for organizing by date/generator (if needed)
  static const Map<String, String> organizationFolders = {
    'daily': '1Q7Vp2k4U8YxM9Nz3L6JhK2MpR4YvW7Tc',
    'archive': '1Q7Vp2k4U8YxM9Nz3L6JhK2MpR4YvW7Tc',
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
