/*
 * Copyright (c) 2019 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

package com.raywenderlich.imagepickerflutter

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Bundle
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.app.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import java.io.File
import android.media.ExifInterface
import java.io.ByteArrayOutputStream


class MainActivity : FlutterActivity() {
  private val permissionCode = 21441

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    val permissionCheck = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE)

    if (permissionCheck != PackageManager.PERMISSION_GRANTED) {
      ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE), permissionCode)
    } else {
      checkGallery()
    }

    GeneratedPluginRegistrant.registerWith(this)

    val channel = MethodChannel(flutterView, "/gallery")
    channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "getItemCount" -> result.success(getGalleryImageCount())
        "getItem" -> {
          val index = (call.arguments as? Int) ?: 0
          dataForGalleryItem(index) { data, id, created, location ->
            result.success(mapOf<String, Any>(
                "data" to data,
                "id" to id,
                "created" to created,
                "location" to location
            ))
          }
        }
      }
    }
  }

  private fun checkGallery() {
    println("number of items ${getGalleryImageCount()}")
    dataForGalleryItem(0) { data, id, created, location ->
      println("first item $data $id $created $location")
    }
  }

  override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
    if (requestCode == permissionCode
        && grantResults.isNotEmpty()
        && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
      checkGallery()
    }
  }


  private fun dataForGalleryItem(index: Int, completion: (ByteArray, String, Int, String) -> Unit) {
    val uri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
    val orderBy = MediaStore.Images.Media.DATE_TAKEN

    val cursor = contentResolver.query(uri, columns, null, null, "$orderBy DESC")
    cursor?.apply {
      moveToPosition(index)

      val idIndex = getColumnIndexOrThrow(MediaStore.Images.Media._ID)
      val dataIndex = getColumnIndexOrThrow(MediaStore.Images.Media.DATA)
      val createdIndex = getColumnIndexOrThrow(MediaStore.Images.Media.DATE_ADDED)
      val latitudeIndex = getColumnIndexOrThrow(MediaStore.Images.Media.LATITUDE)
      val longitudeIndex = getColumnIndexOrThrow(MediaStore.Images.Media.LONGITUDE)

      val id = getString(idIndex)
      val filePath = getString(dataIndex)

      val file = File(filePath)
      val bmp = MediaStore.Images.Thumbnails.getThumbnail(contentResolver, id.toLong(), MediaStore.Images.Thumbnails.MINI_KIND, null)
      val stream = ByteArrayOutputStream()
      bmp.compress(Bitmap.CompressFormat.JPEG, 90, stream)
      val data = stream.toByteArray()

      val created = getInt(createdIndex)
      val latitude = getDouble(latitudeIndex)
      val longitude = getDouble(longitudeIndex)

      completion(data, id, created, "$latitude, $longitude")
    }
  }

  private val columns = arrayOf(
      MediaStore.Images.Media.DATA,
      MediaStore.Images.Media._ID,
      MediaStore.Images.Media.DATE_ADDED,
      MediaStore.Images.Media.LATITUDE,
      MediaStore.Images.Media.LONGITUDE)

  private fun getGalleryImageCount(): Int {
    val uri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI

    val cursor = contentResolver.query(uri, columns, null, null, null);

    return cursor?.count ?: 0
  }
}
