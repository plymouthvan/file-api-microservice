const path = require('path');

/**
 * Validates folder and optional filename paths
 * Rejects paths with parent directory references, absolute paths, hidden files, or special characters
 * 
 * @param {string} folder - The folder name to validate
 * @param {string} [filename] - Optional filename to validate
 * @returns {Object} Object containing validated folder and optional filename
 * @throws {Error} If validation fails
 */
function validatePath(folder, filename = null) {
  // Basic validation
  if (!folder) {
    throw new Error('Folder name is required');
  }

  // Reject absolute paths, parent references, hidden files
  if (path.isAbsolute(folder) || 
      folder.includes('..') || 
      folder.startsWith('.')) {
    throw new Error('Invalid folder path');
  }
  
  // Strict pattern for folder names - alphanumeric, underscore, hyphen only
  const safePattern = /^[a-zA-Z0-9_-]+$/;
  if (!safePattern.test(folder)) {
    throw new Error('Invalid folder name');
  }
  
  // Validate filename if provided
  if (filename) {
    if (!filename) {
      throw new Error('Filename is required');
    }

    if (path.isAbsolute(filename) || 
        filename.includes('..') || 
        filename.startsWith('.')) {
      throw new Error('Invalid file path');
    }
    
    // Allow periods in filenames but only for extensions
    const filenameBase = filename.split('.')[0];
    if (!safePattern.test(filenameBase)) {
      throw new Error('Invalid filename');
    }
    
    return { folder, filename };
  }
  
  return { folder };
}

/**
 * Builds a public URL for a file or folder
 * 
 * @param {string} folder - The folder name
 * @param {string} [filename] - Optional filename
 * @returns {string} The complete public URL
 */
function buildPublicUrl(folder, filename = null) {
  const baseUrl = process.env.PUBLIC_URL;
  
  if (filename) {
    return `${baseUrl}/public/${folder}/${filename}`;
  }
  
  return `${baseUrl}/public/${folder}/`;
}

module.exports = {
  validatePath,
  buildPublicUrl
};
