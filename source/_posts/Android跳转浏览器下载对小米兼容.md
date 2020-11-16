# 对小米跳转浏览器下载的兼容

## 一般情况
Android里面有些时候想把一些关键下载托管给系统，又不想自己处理下载流程，那就可以跳转浏览器来下载，下面的代码就可以实现这个效果：
```java
Uri uri = Uri.parse(url);
Intent intent = new Intent(Intent.ACTION_VIEW, uri);
activity.startActivity(intent);
```

一般情况下这个代码就足够了，但是如果你下载的是apk文件，你使用这段代码在小米/红米手机上去跳转的话，就会惊喜地发现，它没有唤起浏览器去下载，而是直接唤起了下载管理器去下载，这样子虽然能够下载，但是下载完成之后并不能像在其它rom上那样弹出apk安装界面，而是弹出文本查看器的选择框。

## 原因
经过很多次尝试，我终于发现和miui的下载管理器有关系。我们可以注意到，当调用上面的代码进行下载时，通知栏会出现一个下载进度的通知，下面还有一行小字：通过迅雷引擎加速，那如果我们关闭这个引擎呢？直接动手一试，果然下载之后可以自动唤起安装了。不过具体代码层面的原因还是没有找到，如果有人找到的话请告诉我。

## 解决方案
很明显，虽然知道是这个迅雷引擎的问题，但是我们肯定控制不了用户关闭或开启它，那么就只能想办法绕过它。绕过的办法就是直接指定浏览器来打开：
```java
Uri uri = Uri.parse(url);
Intent intent = new Intent(Intent.ACTION_VIEW, uri);
if (Build.BRAND.toLowerCase().contains("mi")) {
  intent.setClassName("com.android.browser", "com.android.browser.BrowserActivity");
}
activity.startActivity(intent);
```
这样就可以唤起浏览器，然后在浏览器中加载apk下载链接，并进行下载了。请注意因为对应的`Class`可能在不同的rom上并**不存在**，请记得做好异常处理。