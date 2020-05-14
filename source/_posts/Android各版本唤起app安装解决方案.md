现在各种APP基本上都会附带自己的检测更新和升级逻辑，前面的检测和下载逻辑都大同小异，也不是本文的讨论重点，而网上后面安装逻辑大部分的实现应该是这样的：
```kotlin
val apkIntent = Intent(Intent.ACTION_VIEW).apply {
    setDataAndType(Uri.fromFile(File(apkLocation)), "application/vnd.android.package-archive")
    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
}
startActivity(apkIntent)
```
也就是直接通过隐式意图（Intent）唤起响应`application/vnd.android.package-archive`这个type的Activity，也就是应用管理器。但是实际上这里会有一些坑，我这里一条一条的列举出来。

## 7.0以下
直接使用上面代码即可

## 7.0-8.0
如果直接使用上面的代码，会产生`android.os.FileUriExposedException: file:///storage/emulated/0/apk/xxx.apk exposed beyond app through Intent.getData()`这样一个异常，这是因为7.0之后系统对于应用间共享文件采用了`strick-mode`API，不允许通过Intent直接暴露`file://`的Uri，只能暴露`content://`的Uri，所以通过`FileProvider`来实现文件共享，所以我们现在把APK文件的下载路径添加到FileProvider的配置中，来让安装程序能够访问到这个文件。
按照[官网教程](https://developer.android.google.cn/reference/androidx/core/content/FileProvider?hl=zh-cn)来一步一步配置

1. 在AndroidManifest.xml中注册`provider`
```xml
<manifest>
  ...
  <application>
    ...
    <provider
        android:name="android.support.v4.content.FileProvider"
        android:authorities="com.halfcup.fileprovider"
        android:exported="false"
        android:grantUriPermissions="true">
        ...
    </provider>
    ...
  </application>
```
2. 在/res/xml下添加file_paths.xml文件
```xml
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <external-path
        name="path_apk"
        path="apk"/>
</paths>
```
最外层的tag用`paths`，表明是添加的路径，内层的tag可以用`external-media-path`、`external-cache-path`、`external-files-path`、`external-path`、`cache-path`、`files-path`，对应关系如下
- `files-path`对应app内部存储中私有目录下的`/files`目录，即通过`Context.getFilesDir()`方法来获取的这个路径
- `cache-path`对应app内部存储中私有目录下的`/cache`目录，即通过`Context.getCacheDir()`方法来获取的这个路径
- `external-path`对应app外部存储的根目录，一般情况下是`/storage/0/`这个目录，也就是通过`Environment.getExternalStorageDirectory()`方法来获取的这个路径
- `external-files-path`对应app外部存储中私有目录下的`/files`目录，也就是通过`Context#getExternalFilesDir(String)`方法来获取的路径
- `external-cache-path`对应app外部存储中私有目录下的`/cache`目录，也就是通过`Context.getExternalCacheDir()`方法来获取的路径
- `external-media-path`对应app外部存储中私有目录下的`/media`目录，也就是通过`Context.getExternalMediaDirs()`方法来获取的路径

3. 完成file_paths.xml文件的编写之后，通过`meta-data`将它添加到我们第一步中注册的provider中
```xml
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="com.halfcup.fileprovider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_paths" />
</provider>
```

4. 构造一个`content://`Uri
我们的APK文件是放在外部存储根目录下的/apk文件夹下的，那么我们可以通过如下代码构建Uri：
```Kotlin
val apkName = "xxx.apk"
val apkFile = File(File(Environment.getExternalStorageDirectory,"apk"),apkName)
val uri = FileProvider.getUriForFile(this@MainActivity,"com.halfcup.fileprovider",file)
```
这样我们就可以用这个uri替代我们之前的uri了

5. 添加访问权限
现在还是不能直接使用，需要添加访问权限才能够让其它应用访问，代码如下：
```kotlin
intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
//如果需要写入权限，添加这个
//intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
```

这样就完成了7.0的适配，现在我们把代码汇总一下：
```kotlin
val apkIntent = Intent(Intent.ACTION_VIEW).apply {
    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    val file = File(apkLocation)
    setDataAndType(FileProvider.getUriForFile(this@MainActivity,"com.halfcup.fileprovider",file), "application/vnd.android.package-archive")
    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION) 

}
startActivity(apkIntent)
```

## 8.0-10.0
添加`<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>`权限声明即可

## 10.0
10之后不再允许使用Intent来直接唤起安装管理器，而是必须通过`PackageInstaller`来安装，所以需要再做处理。
1. 创建一个`SessionParams`，指定mode，`SessionParams.MODE_FULL_INSTALL`用在全量安装的情境下，`SessionParams.MODE_INHERIT_EXISTING`用在增量或者拆分安装的情况下
2. 通过`SessionParams`创建`Session`，得到sessionId，通过sessionId写文件流，把apk文件直接写入
3. 发送PendingIntent
4. 提交Session
5. 处理安装返回
```kotlin
    val inputStream = contentResolver.openInputStream(Uri.fromFile(file))
    val installer = packageManager.packageInstaller
    val params = SessionParams(SessionParams.MODE_FULL_INSTALL)
    val sessionId = installer.createSession(params)
    val session = installer.openSession(sessionId)
    val outputStream = session.openWrite("fileLocation", 0, inputStream!!.available().toLong())
    inputStream.copyTo(outputStream)
    session.fsync(outputStream)
    outputStream.close()
    inputStream.close()
    //自己处理安装结果
    component = ComponentName(this@MainActivity, MainActivity::class.java)
    action = "Action"
    val pi = PendingIntent.getActivity(this@MainActivity, 0x123, this, PendingIntent.FLAG_UPDATE_CURRENT)
    session.commit(pi.intentSender)
    session.close()
} catch (e: IOException) {
    e.printStackTrace()
}
```
这是发起安装的代码，需要再添加处理代码：
```kotlin
override fun onNewIntent(intent: Intent) {
    val extras = intent.extras
    if (extras != null && "Action" == intent.action) {
        val status = extras.getInt(PackageInstaller.EXTRA_STATUS)
        val message = extras.getString(PackageInstaller.EXTRA_STATUS_MESSAGE)
        when (status) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                // This test app isn't privileged, so the user has to confirm the install.
                // 需要继续唤起安装
                val confirmIntent = extras[Intent.EXTRA_INTENT] as Intent?
                startActivity(confirmIntent)
            }
            PackageInstaller.STATUS_SUCCESS -> Log.v("TAG", "安装成功啦--->")
            PackageInstaller.STATUS_FAILURE, PackageInstaller.STATUS_FAILURE_ABORTED, PackageInstaller.STATUS_FAILURE_BLOCKED, PackageInstaller.STATUS_FAILURE_CONFLICT, PackageInstaller.STATUS_FAILURE_INCOMPATIBLE, PackageInstaller.STATUS_FAILURE_INVALID, PackageInstaller.STATUS_FAILURE_STORAGE -> Log.v("TAG", "安装失败啦--->")
            else -> Log.v("TAG", "安装不知道为啥失败啦--->")
        }
```
