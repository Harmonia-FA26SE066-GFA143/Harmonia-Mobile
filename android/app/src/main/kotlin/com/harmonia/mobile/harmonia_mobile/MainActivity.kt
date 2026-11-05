package com.harmonia.mobile.harmonia_mobile

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

class MainActivity : FlutterActivity() {
    private var pendingPickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AVATAR_PICKER_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "pickImage" && call.method != "pickEvidence") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingPickerResult != null) {
                    result.error("PICKER_BUSY", "An image picker is already open.", null)
                    return@setMethodCallHandler
                }

                pendingPickerResult = result
                val requestCode = if (call.method == "pickImage") {
                    AVATAR_PICKER_REQUEST_CODE
                } else {
                    EVIDENCE_PICKER_REQUEST_CODE
                }
                val intent = if (call.method == "pickImage") {
                    Intent(
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            MediaStore.ACTION_PICK_IMAGES
                        } else {
                            Intent.ACTION_GET_CONTENT
                        },
                    ).apply {
                        type = "image/*"
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                            addCategory(Intent.CATEGORY_OPENABLE)
                        }
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                } else {
                    Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        type = "*/*"
                        putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("audio/*", "video/*"))
                        addCategory(Intent.CATEGORY_OPENABLE)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                }
                startActivityForResult(intent, requestCode)
            }
    }

    @Deprecated("FlutterActivity still routes legacy picker activity results here.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != AVATAR_PICKER_REQUEST_CODE && requestCode != EVIDENCE_PICKER_REQUEST_CODE) return

        val result = pendingPickerResult ?: return
        pendingPickerResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        try {
            val file = if (requestCode == AVATAR_PICKER_REQUEST_CODE) {
                copySelectedImage(data.data!!)
            } else {
                copySelectedEvidence(data.data!!)
            }
            result.success(file.absolutePath)
        } catch (error: AvatarPickerException) {
            result.error(error.code, error.message, null)
        } catch (_: Exception) {
            result.error("PICKER_FAILED", "Could not read the selected image.", null)
        }
    }

    private fun copySelectedImage(uri: Uri): File {
        val mimeType = contentResolver.getType(uri)
        val displayName = contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIndex >= 0) cursor.getString(nameIndex) else null
            } else null
        }
        val nameExtension = displayName?.substringAfterLast('.', "")?.lowercase()
        val mimeExtension = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType)?.lowercase()
        val extension = nameExtension?.takeIf { it in ALLOWED_EXTENSIONS }
            ?: mimeExtension?.takeIf { it in ALLOWED_EXTENSIONS }
            ?: throw AvatarPickerException("AVATAR_FILE_TYPE_NOT_ALLOWED", "Unsupported image format.")

        val destination = File(cacheDir, "avatar-${UUID.randomUUID()}.$extension")
        val input = contentResolver.openInputStream(uri)
            ?: throw AvatarPickerException("PICKER_FAILED", "Could not read the selected image.")
        try {
            input.use { source ->
                destination.outputStream().use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    var totalBytes = 0L
                    while (true) {
                        val bytesRead = source.read(buffer)
                        if (bytesRead < 0) break
                        totalBytes += bytesRead
                        if (totalBytes > MAX_AVATAR_BYTES) {
                            throw AvatarPickerException(
                                "AVATAR_FILE_TOO_LARGE",
                                "Avatar images must be 2 MB or smaller.",
                            )
                        }
                        output.write(buffer, 0, bytesRead)
                    }
                    if (totalBytes == 0L) {
                        throw AvatarPickerException("AVATAR_FILE_REQUIRED", "The selected image is empty.")
                    }
                }
            }
        } catch (error: Exception) {
            destination.delete()
            throw error
        }
        return destination
    }

    private fun copySelectedEvidence(uri: Uri): File {
        val mimeType = contentResolver.getType(uri)
        val displayName = contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIndex >= 0) cursor.getString(nameIndex) else null
            } else null
        }
        val nameExtension = displayName?.substringAfterLast('.', "")?.lowercase()
        val mimeExtension = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType)?.lowercase()
        val extension = nameExtension?.takeIf { it in EVIDENCE_EXTENSIONS }
            ?: mimeExtension?.takeIf { it in EVIDENCE_EXTENSIONS }
            ?: throw AvatarPickerException(
                "MEMBER_SKILL_EVIDENCE_TYPE_NOT_ALLOWED",
                "Unsupported skill evidence format.",
            )
        val maxBytes = if (extension in VOICE_EXTENSIONS) MAX_VOICE_BYTES else MAX_CLIP_BYTES
        val destination = File(cacheDir, "skill-evidence-${UUID.randomUUID()}.$extension")
        val input = contentResolver.openInputStream(uri)
            ?: throw AvatarPickerException("PICKER_FAILED", "Could not read the selected file.")
        try {
            input.use { source ->
                destination.outputStream().use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    var totalBytes = 0L
                    while (true) {
                        val bytesRead = source.read(buffer)
                        if (bytesRead < 0) break
                        totalBytes += bytesRead
                        if (totalBytes > maxBytes) {
                            throw AvatarPickerException(
                                "MEMBER_SKILL_EVIDENCE_TOO_LARGE",
                                "Skill evidence exceeds the allowed file size.",
                            )
                        }
                        output.write(buffer, 0, bytesRead)
                    }
                    if (totalBytes == 0L) {
                        throw AvatarPickerException(
                            "MEMBER_SKILL_EVIDENCE_REQUIRED",
                            "The selected file is empty.",
                        )
                    }
                }
            }
        } catch (error: Exception) {
            destination.delete()
            throw error
        }
        return destination
    }

    private class AvatarPickerException(val code: String, override val message: String) : Exception(message)

    companion object {
        private const val AVATAR_PICKER_CHANNEL = "harmonia/avatar_picker"
        private const val AVATAR_PICKER_REQUEST_CODE = 6827
        private const val EVIDENCE_PICKER_REQUEST_CODE = 6828
        private const val MAX_AVATAR_BYTES = 2L * 1024 * 1024
        private const val MAX_VOICE_BYTES = 20L * 1024 * 1024
        private const val MAX_CLIP_BYTES = 100L * 1024 * 1024
        private val ALLOWED_EXTENSIONS = setOf("jpg", "jpeg", "png", "webp")
        private val VOICE_EXTENSIONS = setOf("mp3", "m4a", "wav")
        private val EVIDENCE_EXTENSIONS = VOICE_EXTENSIONS + setOf("mp4", "mov")
    }
}
