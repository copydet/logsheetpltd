const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Cloud Function untuk menghapus user dari Firebase Authentication
 * Hanya dapat dipanggil oleh admin yang sudah ter-autentikasi
 * 
 * Usage:
 * POST /deleteUserAuth
 * Body: { "uid": "user-uid-to-delete" }
 * Headers: Authorization: Bearer <admin-token>
 */
exports.deleteUserAuth = functions.https.onCall(async (data, context) => {
  try {
    // Verifikasi bahwa request berasal dari user yang ter-autentikasi
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Request must be authenticated'
      );
    }

    // Verifikasi bahwa user yang memanggil adalah admin
    const callerUid = context.auth.uid;
    const callerRecord = await admin.firestore()
      .collection('user_profile')
      .doc(callerUid)
      .get();

    if (!callerRecord.exists || callerRecord.data()?.role !== 'admin') {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only admin can delete users'
      );
    }

    // Validasi input
    const { uid } = data;
    if (!uid || typeof uid !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'User UID is required and must be a string'
      );
    }

    // Cegah admin menghapus dirinya sendiri
    if (uid === callerUid) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Cannot delete your own account'
      );
    }

    // Hapus user dari Firebase Authentication
    await admin.auth().deleteUser(uid);

    // Log aktivitas
    console.log(`Admin ${callerUid} deleted user ${uid} from Firebase Auth`);

    return {
      success: true,
      message: 'User berhasil dihapus dari Firebase Authentication'
    };

  } catch (error) {
    console.error('Error deleting user from auth:', error);
    
    // Handle specific Firebase Auth errors
    if (error.code === 'auth/user-not-found') {
      throw new functions.https.HttpsError(
        'not-found',
        'User tidak ditemukan di Firebase Authentication'
      );
    }

    // Re-throw HttpsError yang sudah ada
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    // Handle unexpected errors
    throw new functions.https.HttpsError(
      'internal',
      `Terjadi kesalahan saat menghapus user: ${error.message}`
    );
  }
});

/**
 * HTTP endpoint alternative (jika diperlukan untuk testing)
 * 
 * Usage:
 * POST /deleteUserAuthHTTP
 * Body: { "uid": "user-uid-to-delete" }
 * Headers: 
 *   - Authorization: Bearer <admin-token>
 *   - Content-Type: application/json
 */
exports.deleteUserAuthHTTP = functions.https.onRequest(async (req, res) => {
  // Set CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return res.status(200).send();
  }

  // Only allow POST requests
  if (req.method !== 'POST') {
    return res.status(405).json({
      success: false,
      message: 'Method not allowed. Use POST.'
    });
  }

  try {
    // Verify authorization header
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'Missing or invalid authorization header'
      });
    }

    // Verify the token
    const token = authHeader.split('Bearer ')[1];
    const decodedToken = await admin.auth().verifyIdToken(token);
    const callerUid = decodedToken.uid;

    // Verify admin role
    const callerRecord = await admin.firestore()
      .collection('user_profile')
      .doc(callerUid)
      .get();

    if (!callerRecord.exists || callerRecord.data()?.role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Only admin can delete users'
      });
    }

    // Get UID from request body
    const { uid } = req.body;
    if (!uid || typeof uid !== 'string') {
      return res.status(400).json({
        success: false,
        message: 'User UID is required and must be a string'
      });
    }

    // Prevent admin from deleting themselves
    if (uid === callerUid) {
      return res.status(400).json({
        success: false,
        message: 'Cannot delete your own account'
      });
    }

    // Delete user from Firebase Authentication
    await admin.auth().deleteUser(uid);

    // Log activity
    console.log(`Admin ${callerUid} deleted user ${uid} from Firebase Auth via HTTP`);

    return res.status(200).json({
      success: true,
      message: 'User berhasil dihapus dari Firebase Authentication'
    });

  } catch (error) {
    console.error('Error in HTTP deleteUserAuth:', error);

    let statusCode = 500;
    let message = `Terjadi kesalahan saat menghapus user: ${error.message}`;

    if (error.code === 'auth/user-not-found') {
      statusCode = 404;
      message = 'User tidak ditemukan di Firebase Authentication';
    } else if (error.code === 'auth/id-token-expired') {
      statusCode = 401;
      message = 'Token expired. Please login again.';
    } else if (error.code === 'auth/argument-error') {
      statusCode = 401;
      message = 'Invalid token format';
    }

    return res.status(statusCode).json({
      success: false,
      message: message
    });
  }
});
