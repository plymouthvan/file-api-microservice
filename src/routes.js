const express = require('express');
const fs = require('fs-extra');
const path = require('path');
const { validatePath, buildPublicUrl } = require('./pathUtils');
const { authMiddleware } = require('./middleware');

const router = express.Router();

/**
 * Upload endpoint - handles both binary and JSON base64 uploads
 * Creates folders if needed and handles exposure logic
 */
router.post('/upload', authMiddleware, async (req, res) => {
  try {
    let folder, filename, expose = false, fileData, mimetype;
    
    // Handle binary upload
    if (req.headers['content-type'] === 'application/octet-stream') {
      folder = req.headers['x-folder'];
      filename = req.headers['x-filename'];
      expose = req.headers['x-expose'] === 'true';
      
      if (!folder || !filename) {
        return res.status(400).json({
          status: 'error',
          message: 'Missing required headers: X-Folder, X-Filename'
        });
      }
      
      // Collect binary data
      const chunks = [];
      for await (const chunk of req) {
        chunks.push(chunk);
      }
      fileData = Buffer.concat(chunks);
    } 
    // Handle JSON base64 upload
    else {
      const { folder: reqFolder, filename: reqFilename, base64, mimetype: reqMimetype, expose: reqExpose } = req.body;
      
      if (!reqFolder || !reqFilename || !base64) {
        return res.status(400).json({
          status: 'error',
          message: 'Missing required fields: folder, filename, base64'
        });
      }
      
      folder = reqFolder;
      filename = reqFilename;
      expose = reqExpose || false;
      mimetype = reqMimetype;
      fileData = Buffer.from(base64, 'base64');
    }
    
    try {
      // Validate paths
      const { folder: safeFolder, filename: safeFilename } = validatePath(folder, filename);
      
      // Determine storage location based on exposure
      const baseDir = expose ? 'public' : 'private';
      
      // Create folder structure
      const folderPath = path.join(baseDir, safeFolder);
      await fs.ensureDir(folderPath);
      
      // Save file
      const filePath = path.join(folderPath, safeFilename);
      await fs.writeFile(filePath, fileData);
      
      // Handle exposure
      let visibility = expose ? 'exposed' : 'hidden';
      let url = expose ? buildPublicUrl(safeFolder, safeFilename) : null;
      
      return res.json({
        status: 'ok',
        action: 'file_uploaded',
        visibility,
        url,
        folder: safeFolder,
        file: safeFilename,
        message: 'File uploaded'
      });
    } catch (validationError) {
      return res.status(400).json({
        status: 'error',
        message: validationError.message
      });
    }
  } catch (error) {
    console.error('Upload error:', error);
    return res.status(500).json({
      status: 'error',
      message: 'Internal server error'
    });
  }
});

// Create folder endpoint
router.post('/mkdir', authMiddleware, async (req, res) => {
  try {
    const { folder, expose = false } = req.body;
    
    if (!folder) {
      return res.status(400).json({
        status: 'error',
        message: 'Folder name is required'
      });
    }
    
    try {
      // Validate folder path
      const { folder: safeFolder } = validatePath(folder);
      
      // Determine storage location based on exposure
      const baseDir = expose ? 'public' : 'private';
      
      // Create folder
      const folderPath = path.join(baseDir, safeFolder);
      await fs.ensureDir(folderPath);
      
      // Handle exposure
      let visibility = expose ? 'exposed' : 'hidden';
      let url = expose ? buildPublicUrl(safeFolder) : null;
      
      return res.json({
        status: 'ok',
        action: 'folder_created',
        visibility,
        url,
        folder: safeFolder,
        file: null,
        message: 'Folder created'
      });
    } catch (validationError) {
      return res.status(400).json({
        status: 'error',
        message: validationError.message
      });
    }
  } catch (error) {
    console.error('Create folder error:', error);
    return res.status(500).json({
      status: 'error',
      message: 'Internal server error'
    });
  }
});

// Delete file or folder endpoint
router.delete('/delete/:folder/:filename?', authMiddleware, async (req, res) => {
  try {
    const { folder, filename } = req.params;
    
    try {
      // If filename is provided, delete file
      if (filename) {
        const { folder: safeFolder, filename: safeFilename } = validatePath(folder, filename);
        
        // Check both public and private directories
        const publicPath = path.join('public', safeFolder, safeFilename);
        const privatePath = path.join('private', safeFolder, safeFilename);
        
        // Check if file exists in either location
        let filePath = null;
        if (await fs.pathExists(publicPath)) {
          filePath = publicPath;
        } else if (await fs.pathExists(privatePath)) {
          filePath = privatePath;
        }
        
        if (!filePath) {
          return res.status(404).json({
            status: 'error',
            message: 'File not found'
          });
        }
        
        // Delete file
        await fs.remove(filePath);
        
        return res.json({
          status: 'ok',
          action: 'file_deleted',
          visibility: 'hidden',
          url: null,
          folder: safeFolder,
          file: safeFilename,
          message: 'File deleted'
        });
      } 
      // Otherwise delete folder
      else {
        const { folder: safeFolder } = validatePath(folder);
        
        // Check both public and private directories
        const publicPath = path.join('public', safeFolder);
        const privatePath = path.join('private', safeFolder);
        
        // Check if folder exists in either location
        let folderExists = false;
        if (await fs.pathExists(publicPath)) {
          await fs.remove(publicPath);
          folderExists = true;
        }
        
        if (await fs.pathExists(privatePath)) {
          await fs.remove(privatePath);
          folderExists = true;
        }
        
        if (!folderExists) {
          return res.status(404).json({
            status: 'error',
            message: 'Folder not found'
          });
        }
        
        return res.json({
          status: 'ok',
          action: 'folder_deleted',
          visibility: 'hidden',
          url: null,
          folder: safeFolder,
          file: null,
          message: 'Folder and contents deleted'
        });
      }
    } catch (validationError) {
      return res.status(400).json({
        status: 'error',
        message: validationError.message
      });
    }
  } catch (error) {
    console.error('Delete error:', error);
    return res.status(500).json({
      status: 'error',
      message: 'Internal server error'
    });
  }
});

// Expose folder endpoint
router.post('/expose/:folder', authMiddleware, async (req, res) => {
  try {
    const { folder } = req.params;
    
    try {
      const { folder: safeFolder } = validatePath(folder);
      const privatePath = path.join('private', safeFolder);
      const publicPath = path.join('public', safeFolder);
      
      // Check if folder exists in private directory
      if (await fs.pathExists(privatePath)) {
        // Move folder from private to public
        await fs.ensureDir(path.dirname(publicPath));
        await fs.move(privatePath, publicPath, { overwrite: true });
      } 
      // Check if it already exists in public directory
      else if (await fs.pathExists(publicPath)) {
        // Already exposed, do nothing
      } 
      else {
        return res.status(404).json({
          status: 'error',
          message: 'Folder not found'
        });
      }
      
      // Build public URL
      const url = buildPublicUrl(safeFolder);
      
      return res.json({
        status: 'ok',
        action: 'folder_exposed',
        visibility: 'exposed',
        url,
        folder: safeFolder,
        file: null,
        message: 'Folder is now public'
      });
    } catch (validationError) {
      return res.status(400).json({
        status: 'error',
        message: validationError.message
      });
    }
  } catch (error) {
    console.error('Expose folder error:', error);
    return res.status(500).json({
      status: 'error',
      message: 'Internal server error'
    });
  }
});

// Unexpose folder endpoint
router.post('/unexpose/:folder', authMiddleware, async (req, res) => {
  try {
    const { folder } = req.params;
    
    try {
      const { folder: safeFolder } = validatePath(folder);
      const publicPath = path.join('public', safeFolder);
      const privatePath = path.join('private', safeFolder);
      
      // Check if folder exists in public directory
      if (await fs.pathExists(publicPath)) {
        // Move folder from public to private
        await fs.ensureDir(path.dirname(privatePath));
        await fs.move(publicPath, privatePath, { overwrite: true });
      } 
      // Check if it already exists in private directory
      else if (await fs.pathExists(privatePath)) {
        // Already unexposed, do nothing
      } 
      else {
        return res.status(404).json({
          status: 'error',
          message: 'Folder not found'
        });
      }
      
      return res.json({
        status: 'ok',
        action: 'folder_unexposed',
        visibility: 'hidden',
        url: null,
        folder: safeFolder,
        file: null,
        message: 'Folder is no longer public'
      });
    } catch (validationError) {
      return res.status(400).json({
        status: 'error',
        message: validationError.message
      });
    }
  } catch (error) {
    console.error('Unexpose folder error:', error);
    return res.status(500).json({
      status: 'error',
      message: 'Internal server error'
    });
  }
});

// Rename file or folder endpoint
router.patch('/rename', authMiddleware, async (req, res) => {
  try {
    const { type, folder, filename, newName } = req.body;
    
    if (!type || !folder || !newName) {
      return res.status(400).json({
        status: 'error',
        message: 'Missing required fields: type, folder, newName'
      });
    }
    
    if (type !== 'file' && type !== 'folder') {
      return res.status(400).json({
        status: 'error',
        message: 'Type must be "file" or "folder"'
      });
    }
    
    if (type === 'file' && !filename) {
      return res.status(400).json({
        status: 'error',
        message: 'Filename is required when type is "file"'
      });
    }
    
    try {
      // Rename file
      if (type === 'file') {
        const { folder: safeFolder, filename: safeFilename } = validatePath(folder, filename);
        const { filename: safeNewName } = validatePath(folder, newName);
        
        // Check both public and private directories
        const publicOldPath = path.join('public', safeFolder, safeFilename);
        const privateOldPath = path.join('private', safeFolder, safeFilename);
        
        // Determine which path to use
        let oldPath;
        let isExposed = false;
        
        if (await fs.pathExists(publicOldPath)) {
          oldPath = publicOldPath;
          isExposed = true;
        } else if (await fs.pathExists(privateOldPath)) {
          oldPath = privateOldPath;
        } else {
          return res.status(404).json({
            status: 'error',
            message: 'File not found'
          });
        }
        
        // Set new path in the same directory (public or private)
        const baseDir = isExposed ? 'public' : 'private';
        const newPath = path.join(baseDir, safeFolder, safeNewName);
        
        // Rename file
        await fs.move(oldPath, newPath, { overwrite: true });
        
        // Set visibility and URL
        const visibility = isExposed ? 'exposed' : 'hidden';
        const url = isExposed ? buildPublicUrl(safeFolder, safeNewName) : null;
        
        return res.json({
          status: 'ok',
          action: 'renamed',
          visibility,
          url,
          folder: safeFolder,
          file: safeNewName,
          message: 'File renamed successfully'
        });
      } 
      // Rename folder
      else {
        const { folder: safeFolder } = validatePath(folder);
        const { folder: safeNewName } = validatePath(newName);
        
        // Check both public and private directories
        const publicOldPath = path.join('public', safeFolder);
        const privateOldPath = path.join('private', safeFolder);
        
        // Determine which path to use
        let oldPath;
        let isExposed = false;
        
        if (await fs.pathExists(publicOldPath)) {
          oldPath = publicOldPath;
          isExposed = true;
        } else if (await fs.pathExists(privateOldPath)) {
          oldPath = privateOldPath;
        } else {
          return res.status(404).json({
            status: 'error',
            message: 'Folder not found'
          });
        }
        
        // Set new path in the same directory (public or private)
        const baseDir = isExposed ? 'public' : 'private';
        const newPath = path.join(baseDir, safeNewName);
        
        // Rename folder
        await fs.move(oldPath, newPath, { overwrite: true });
        
        // Set visibility and URL
        const visibility = isExposed ? 'exposed' : 'hidden';
        const url = isExposed ? buildPublicUrl(safeNewName) : null;
        
        return res.json({
          status: 'ok',
          action: 'renamed',
          visibility,
          url,
          folder: safeNewName,
          file: null,
          message: 'Folder renamed successfully'
        });
      }
    } catch (validationError) {
      return res.status(400).json({
        status: 'error',
        message: validationError.message
      });
    }
  } catch (error) {
    console.error('Rename error:', error);
    return res.status(500).json({
      status: 'error',
      message: 'Internal server error'
    });
  }
});

// List folder contents endpoint
router.get('/list/:folder', authMiddleware, async (req, res) => {
  try {
    const { folder } = req.params;
    
    try {
      const { folder: safeFolder } = validatePath(folder);
      
      // Check both public and private directories
      const publicPath = path.join('public', safeFolder);
      const privatePath = path.join('private', safeFolder);
      
      // Determine which path to use
      let folderPath;
      let isExposed = false;
      
      if (await fs.pathExists(publicPath)) {
        folderPath = publicPath;
        isExposed = true;
      } else if (await fs.pathExists(privatePath)) {
        folderPath = privatePath;
      } else {
        return res.status(404).json({
          status: 'error',
          message: 'Folder not found'
        });
      }
      
      // Get folder contents
      const files = await fs.readdir(folderPath);
      const fileDetails = await Promise.all(
        files.map(async (file) => {
          const filePath = path.join(folderPath, file);
          const stats = await fs.stat(filePath);
          
          // Only include files, not directories
          if (stats.isFile()) {
            return {
              name: file,
              size: stats.size,
              modified: stats.mtime.toISOString()
            };
          }
          return null;
        })
      );
      
      // Filter out null values (directories)
      const fileList = fileDetails.filter(Boolean);
      
      // Set visibility and URL
      const visibility = isExposed ? 'exposed' : 'hidden';
      const url = isExposed ? buildPublicUrl(safeFolder) : null;
      
      return res.json({
        status: 'ok',
        action: 'folder_listed',
        visibility,
        url,
        folder: safeFolder,
        file: null,
        message: 'Folder listed',
        files: fileList
      });
    } catch (validationError) {
      return res.status(400).json({
        status: 'error',
        message: validationError.message
      });
    }
  } catch (error) {
    console.error('List folder error:', error);
    return res.status(500).json({
      status: 'error',
      message: 'Internal server error'
    });
  }
});

// List all folders endpoint
router.get('/list', authMiddleware, async (req, res) => {
  try {
    const publicPath = path.join('public');
    const privatePath = path.join('private');
    
    // Ensure directories exist
    await fs.ensureDir(publicPath);
    await fs.ensureDir(privatePath);
    
    // Get all folders from both directories
    const publicItems = await fs.readdir(publicPath);
    const privateItems = await fs.readdir(privatePath);
    
    // Process public folders
    const publicFolders = await Promise.all(
      publicItems.map(async (item) => {
        const itemPath = path.join(publicPath, item);
        const stats = await fs.stat(itemPath);
        
        // Only include directories, not files
        if (stats.isDirectory()) {
          return {
            name: item,
            visibility: 'exposed',
            url: buildPublicUrl(item)
          };
        }
        return null;
      })
    );
    
    // Process private folders
    const privateFolders = await Promise.all(
      privateItems.map(async (item) => {
        const itemPath = path.join(privatePath, item);
        const stats = await fs.stat(itemPath);
        
        // Only include directories, not files
        if (stats.isDirectory()) {
          return {
            name: item,
            visibility: 'hidden',
            url: null
          };
        }
        return null;
      })
    );
    
    // Combine and filter out null values (files)
    const allFolders = [...publicFolders, ...privateFolders].filter(Boolean);
    
    // Remove duplicates (folders that exist in both directories)
    const folderMap = new Map();
    allFolders.forEach(folder => {
      // Public folders take precedence
      if (!folderMap.has(folder.name) || folder.visibility === 'exposed') {
        folderMap.set(folder.name, folder);
      }
    });
    
    const folderList = Array.from(folderMap.values());
    
    return res.json({
      status: 'ok',
      action: 'root_listed',
      visibility: null,
      url: null,
      folder: null,
      file: null,
      message: 'Folders listed',
      folders: folderList
    });
  } catch (error) {
    console.error('List all folders error:', error);
    return res.status(500).json({
      status: 'error',
      message: 'Internal server error'
    });
  }
});

// Serve public file endpoint
router.get('/public/:folder/:filename', async (req, res) => {
  try {
    const { folder, filename } = req.params;
    
    try {
      const { folder: safeFolder, filename: safeFilename } = validatePath(folder, filename);
      const filePath = path.join('public', safeFolder, safeFilename);
      
      // Check if file exists
      if (!await fs.pathExists(filePath)) {
        return res.status(404).json({
          status: 'error',
          message: 'File not found'
        });
      }
      
      // Send file
      return res.sendFile(path.resolve(filePath));
    } catch (validationError) {
      return res.status(400).json({
        status: 'error',
        message: validationError.message
      });
    }
  } catch (error) {
    console.error('Serve public file error:', error);
    return res.status(500).json({
      status: 'error',
      message: 'Internal server error'
    });
  }
});

module.exports = router;
