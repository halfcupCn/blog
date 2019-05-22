## 从使用流程开始分析
### 构建`Retrofit`实例
我们先采用最简单的构建方式：
```kotlin
val retrofit = Retrofit.Builder().build()
```
一步一步地深入源码去看，第一步是创建了`Retrofit.Builder`
```kotlin
public Builder() {
  this(Platform.get());
}
```
在这里调用了`Platform.get()`，这个方法是获取一个`Platform`实例，也就是为了指定Retrofit当前的平台，对我现在的情境来说，会返回一个`Android`实例。而判断当前平台的方法是通过反射去获取`android.os.Build`类，如果有这个类，那么就会通过无参构造方法返回一个`Android`实例
```Java
private static final Platform PLATFORM = findPlatform();

static Platform get() {
  return PLATFORM;
}

private static Platform findPlatform() {
  try {
    Class.forName("android.os.Build");
    if (Build.VERSION.SDK_INT != 0) {
      return new Android();
    }
  } catch (ClassNotFoundException ignored) {
  }
  try {
    Class.forName("java.util.Optional");
    return new Java8();
  } catch (ClassNotFoundException ignored) {
  }
  return new Platform();
}
```
但是具体这个实例有什么作用呢，暂时还看不出来，先继续顺着流程往后面看。
刚才我们已经获得了`Retrofit.Builder`的实例，通过它的`build()`方法，我们可以得到`Retrofit`实例，那这个方法里面做了什么呢？
```Java
public Retrofit build() {
  if (baseUrl == null) {
    throw new IllegalStateException("Base URL required.");
  }
  okhttp3.Call.Factory callFactory = this.callFactory;
  if (callFactory == null) {
    callFactory = new OkHttpClient();
  }

  Executor callbackExecutor = this.callbackExecutor;
  if (callbackExecutor == null) {
    callbackExecutor = platform.defaultCallbackExecutor();
  }

  // Make a defensive copy of the adapters and add the default Call adapter.
  List<CallAdapter.Factory> callAdapterFactories = new ArrayList<>(this.callAdapterFactories);
  callAdapterFactories.addAll(platform.defaultCallAdapterFactories(callbackExecutor));

  // Make a defensive copy of the converters.
  List<Converter.Factory> converterFactories = new ArrayList<>(
      1 + this.converterFactories.size() + platform.defaultConverterFactoriesSize());

  // Add the built-in converter factory first. This prevents overriding its behavior but also
  // ensures correct behavior when using converters that consume all types.
  converterFactories.add(new BuiltInConverters());
  converterFactories.addAll(this.converterFactories);
  converterFactories.addAll(platform.defaultConverterFactories());

  return new Retrofit(callFactory, baseUrl, unmodifiableList(converterFactories),
      unmodifiableList(callAdapterFactories), callbackExecutor, validateEagerly);
}
```
可以看到做了几件事情：
1. 检查`baseUrl`，如果没有设置就会抛出`IllegalStateException`异常
2. 使用Builder的callFactory为Retrofit构造，如果没有设置，则会构造一个`okhttp3.OkHttpClient`实例作为callFactory
3. 使用Builder的callbackExecutor为Retrofit构造，如果没有设置，则会调用`platform.defaultCallbackExecutor()`生成callbackExecutor
4. 使用Builder的callAdapterFactories作为Retrofit构造，但先调用`platform.defaultCallAdapterFactories(callbackExecutor)`添加一些callAdapter
5. 创建一个converterFactories的List
	- 添加`BuiltInConverters`
	- 添加Builder的converterFactories
	- 添加`platform.defaultConverterFactories()`
6. 调用Retrofit的有参构造创建实例并返回

### 使用
```kotlin
retrofit.create(GithubApi::class.java).listRepos("")
```
分为`create(service)`和`listRepos`两个过程
1. create
	1. 检查service是不是接口，并且没有继承其它 的接口
	2. 通过Java的`Proxy.newInstance()`方法，使用反射生成对应的service实例
		1. 实际的实现方法是在`InvocationHandler.invoke`中，在这之中又调用了`loadServiceMethod`，而最后又是传递给了`ServiceMethod.parseAnnotations`去做
		2. 在`ServiceMethod.parseAnnotations`中，构造了`RequestFactory`来执行拼装，但是调用又传递给了`HttpServiceMethod.parseAnnotations`
		3. 最后创建了一个`HttpServiceMethod`的实例，它来通过callAdapter来最后实现，callAdapter中使用了代理类来实现，默认的实现是`OkHttpCall`
2. listRepos，也就是实际的方法调用

### 关键点
可以看到，上面有几个关键点
1. CallAdapter
2. Converter
3. CallExcuter
CallAdapter来创建Call，Converter来转换返回结果，CallExcuter来执行Call的逻辑

### TODO：后续找时间补上调用方法的流程图