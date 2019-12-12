# 使用Intent.createChooser生成处理不同数据类型的Intent的chooser对话框

## 起因
遇到一个需求，需要在选择图片时，能同时选择从相册中选取和拍照来生成，一般来说，可以自己定义一个对话框，不同的按钮对应不同的Intent来处理。但是后来我想起了Intent.createChooser这个方法，发现可以用这个方法直接生成系统样式的对话框。

## 实现
```kotlin
            val newIntent = Intent(Intent.ACTION_GET_CONTENT)
            newIntent.addCategory(Intent.CATEGORY_OPENABLE)
            newIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            newIntent.type = "image/*"

            val cameraIntent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
            val file = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "img.jpg")

            uri = Uri.fromFile(file)
            cameraIntent.putExtra(MediaStore.EXTRA_OUTPUT, uri)
            val chooseIntent = Intent.createChooser(newIntent, "选择上传方式")
            chooseIntent.putExtra(Intent.EXTRA_TITLE, "选择上传方式")
            chooseIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, arrayOf<Parcelable>(cameraIntent))
            startActivityForResult(chooseIntent, 100)
```

可以看到，关键代码就是`chooseIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, arrayOf<Parcelable>(cameraIntent))`，加上了这个参数之后，就可以生成不同类型的Intent了。如果你还有别的需要，比如选择文件既想选择已经存在的，又想直接创建新的文件，那么就可以通过这个参数来拼接生成你需要的Chooser对话框了。

## 补充
如果对应的Intent的action是需要权限的，比如拍照或者录制，同时针对的是Android 6以上的设备，请先动态获取权限，获取之后再继续操作。