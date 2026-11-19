package com.amosnudel.flashcards

import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Adds one native method for importing a folder of decks.
 *
 * The system folder picker returns a `content://` tree URI, which Dart's
 * file APIs can't open. `readJsonTree` walks that tree through the Storage
 * Access Framework and returns {relative path: file text} for every .json
 * file in it, including subfolders.
 */
class MainActivity : FlutterActivity() {
    private val io = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "flashcards/folder")
            .setMethodCallHandler { call, result ->
                if (call.method != "readJsonTree") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val uri = Uri.parse(call.argument<String>("uri"))
                io.execute {
                    try {
                        val files = readJsonTree(uri)
                        runOnUiThread { result.success(files) }
                    } catch (e: Exception) {
                        runOnUiThread { result.error("read_failed", e.message, null) }
                    }
                }
            }
    }

    private fun readJsonTree(treeUri: Uri): Map<String, String> {
        val files = mutableMapOf<String, String>()
        val rootId = DocumentsContract.getTreeDocumentId(treeUri)
        // (documentId, path relative to the picked folder)
        val pending = ArrayDeque(listOf(rootId to ""))
        while (pending.isNotEmpty()) {
            val (parentId, parentPath) = pending.removeFirst()
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentId)
            contentResolver.query(
                children,
                arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_MIME_TYPE,
                ),
                null, null, null,
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    val id = cursor.getString(0)
                    val name = cursor.getString(1) ?: continue
                    val path = if (parentPath.isEmpty()) name else "$parentPath/$name"
                    if (cursor.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR) {
                        pending.addLast(id to path)
                    } else if (name.lowercase().endsWith(".json")) {
                        val doc = DocumentsContract.buildDocumentUriUsingTree(treeUri, id)
                        contentResolver.openInputStream(doc)?.use { stream ->
                            files[path] = stream.bufferedReader().readText()
                        }
                    }
                }
            }
        }
        return files
    }
}
