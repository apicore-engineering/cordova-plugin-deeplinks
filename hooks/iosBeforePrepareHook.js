/*
Hook executed before the 'prepare' stage. Only for iOS project.
It will check if project name has changed. If so - it will change the name of the .entitlements file to remove that file duplicates.
If file name has no changed - hook will do nothing.
*/

var path = require('path');
var fs = require('fs');
var ConfigXmlHelper = require('./lib/configXmlHelper.js');

module.exports = function(ctx) {
  run(ctx);
};

/**
 * Run the hook logic.
 *
 * @param {Object} ctx - cordova context object
 */
function run(ctx) {
  var projectRoot = ctx.opts.projectRoot;
  var iosProjectFilePath = path.join(projectRoot, 'platforms', 'ios');
  var configXmlHelper = new ConfigXmlHelper(ctx);
  var newProjectName = configXmlHelper.getProjectName();

  // Find actual project folder (cordova-ios 8.x uses "App" instead of project name)
  var projectFolder = getProjectFolder(iosProjectFilePath);
  if (!projectFolder) {
    return;
  }

  // In cordova-ios 8.x, the project folder is "App" and entitlements should stay as App.entitlements
  // Don't try to rename based on config.xml name as that's not how cordova-ios 8.x works
  if (projectFolder === 'App') {
    return;
  }

  var oldProjectName = getOldProjectName(iosProjectFilePath);

  // if name has not changed - do nothing
  if (oldProjectName.length && oldProjectName === newProjectName) {
    return;
  }

  console.log('Project name has changed. Renaming .entitlements file.');

  // Use actual project folder path
  var oldEntitlementsFilePath = path.join(iosProjectFilePath, projectFolder, 'Resources', oldProjectName + '.entitlements');
  var newEntitlementsFilePath = path.join(iosProjectFilePath, projectFolder, 'Resources', newProjectName + '.entitlements');

  try {
    fs.renameSync(oldEntitlementsFilePath, newEntitlementsFilePath);
  } catch (err) {
    console.warn('Failed to rename .entitlements file.');
    console.warn(err);
  }
}

/**
 * Find the actual project folder (App in cordova-ios 8.x, or project name in older versions)
 *
 * @param {String} projectDir absolute path to ios project directory
 * @return {String} project folder name or null
 */
function getProjectFolder(projectDir) {
  var files = [];
  try {
    files = fs.readdirSync(projectDir);
  } catch (err) {
    return null;
  }

  // Check for "App" folder first (cordova-ios 8.x)
  if (files.indexOf('App') !== -1) {
    var resourcesPath = path.join(projectDir, 'App', 'Resources');
    if (fs.existsSync(resourcesPath)) {
      return 'App';
    }
  }

  // Fallback: find folder with Resources subdirectory
  for (var i = 0; i < files.length; i++) {
    var folderPath = path.join(projectDir, files[i]);
    var resourcesPath = path.join(folderPath, 'Resources');
    try {
      if (fs.statSync(folderPath).isDirectory() && fs.existsSync(resourcesPath)) {
        return files[i];
      }
    } catch (err) {
      continue;
    }
  }

  return null;
}

// region Private API

/**
 * Get old name of the project.
 * Name is detected by the name of the .xcodeproj file.
 *
 * @param {String} projectDir absolute path to ios project directory
 * @return {String} old project name
 */
function getOldProjectName(projectDir) {
  var files = [];
  try {
    files = fs.readdirSync(projectDir);
  } catch (err) {
    return '';
  }

  var projectFile = '';
  files.forEach(function(fileName) {
    if (path.extname(fileName) === '.xcodeproj') {
      projectFile = path.basename(fileName, '.xcodeproj');
    }
  });

  return projectFile;
}

// endregion
