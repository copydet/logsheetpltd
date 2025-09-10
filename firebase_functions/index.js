/**
 * Cloud Functions for PLTD Logsheet Application
 * User Management Functions
 * 
 * Import and export all cloud functions here
 */

// Import the delete user authentication function
const { deleteUserAuth, deleteUserAuthHTTP } = require('./delete_user_auth');

// Export functions for Firebase deployment
exports.deleteUserAuth = deleteUserAuth;
exports.deleteUserAuthHTTP = deleteUserAuthHTTP;

// You can add more functions here as needed
// exports.otherFunction = require('./other_function').otherFunction;
