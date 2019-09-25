# OKHttp 4.x版本源码分析总结
>当前基于4.1.0版本分析

## 流程分析
>暂时只考虑最简单的情况

### 用户端
```kotlin
        val client = OkHttpClient.Builder()
                .build()
        val request = Request.Builder()
                .url("https://square.github.io/okhttp/")
                .build()
        val call = client.newCall(request)
        val response = call.execute()
```
这是一个最简单情况下使用`OkHttp`库去完成一个网络请求的代码，可以看到，这里有几个关键类，`OkHttpClient`、`Request`、`Call`、`Response`。

从名字简单去理解，OkHttpClient是客户端预设参数的包装，使用这个类可以生成Call；Call是请求的包装，使用这类可以完成请求；Request是请求参数的包装，包括请求的url、header、body等一系列参数；而Response是返回参数的包装，同时还会携带对应的Request。

### 实现
但是正像上文中提到的，这些类都是包装而已，实际上的请求并不是这些类来完成的，我们去查看OkHttpClient的newCall方法实现：
```kotlin
  override fun newCall(request: Request): Call {
    return RealCall.newRealCall(this, request, forWebSocket = false)
  }
```
可以看到实际上是调用了`RealCall.newRealCall`，我们继续跟进：
```kotlin
    fun newRealCall(
      client: OkHttpClient,
      originalRequest: Request,
      forWebSocket: Boolean
    ): RealCall {
      // Safely publish the Call instance to the EventListener.
      // 安全地把Call实例发布给EventListener
      return RealCall(client, originalRequest, forWebSocket).apply {
        transmitter = Transmitter(client, this)
      }
    }
```
所以实际上`OkHttpClient.newCall`是返回的`RealCall`实例，同时这个实例还初始化了自己的`Transmitter`。

继续去看execute方法：
```kotlin
  override fun execute(): Response {
    synchronized(this) {
      check(!executed) { "Already Executed" }
      executed = true
    }
    transmitter.timeoutEnter()
    transmitter.callStart()
    try {
      client.dispatcher.executed(this)
      return getResponseWithInterceptorChain()
    } finally {
      client.dispatcher.finished(this)
    }
  }
```
一开始检查了一下这个Call实例是否已经执行过了，之后启动了一个线程来检查超时？，然后使用`eventListener.callStart(call)`记录了请求的开始，之后又将请求发给了Dispatcher去执行，再去看Dispatcher中的实现：
```kotlin
  /** Used by `Call#execute` to signal it is in-flight. */
  @Synchronized internal fun executed(call: RealCall) {
    runningSyncCalls.add(call)
  }
```
这里也没有实际发出请求，而是只把请求加入了队列中，那实际上的请求就并没有在这里执行，我们接着往下去看`getResponseWithInterceptorChain()`：
```kotlin
  @Throws(IOException::class)
  fun getResponseWithInterceptorChain(): Response {
    // Build a full stack of interceptors.
    val interceptors = mutableListOf<Interceptor>()
    interceptors += client.interceptors
    interceptors += RetryAndFollowUpInterceptor(client)
    interceptors += BridgeInterceptor(client.cookieJar)
    interceptors += CacheInterceptor(client.cache)
    interceptors += ConnectInterceptor
    if (!forWebSocket) {
      interceptors += client.networkInterceptors
    }
    interceptors += CallServerInterceptor(forWebSocket)

    val chain = RealInterceptorChain(interceptors, transmitter, null, 0, originalRequest, this,
        client.connectTimeoutMillis, client.readTimeoutMillis, client.writeTimeoutMillis)

    var calledNoMoreExchanges = false
    try {
      val response = chain.proceed(originalRequest)
      if (transmitter.isCanceled) {
        response.closeQuietly()
        throw IOException("Canceled")
      }
      return response
    } catch (e: IOException) {
      calledNoMoreExchanges = true
      throw transmitter.noMoreExchanges(e) as Throwable
    } finally {
      if (!calledNoMoreExchanges) {
        transmitter.noMoreExchanges(null)
      }
    }
  }
```
可以看到`RealInterceptorChain`，调用了`chain.proceed`方法，再去看它的proceed实现：
```kotlin
  @Throws(IOException::class)
  fun proceed(request: Request, transmitter: Transmitter, exchange: Exchange?): Response {
    if (index >= interceptors.size) throw AssertionError()

    calls++

    // If we already have a stream, confirm that the incoming request will use it.
    check(this.exchange == null || this.exchange.connection()!!.supportsUrl(request.url)) {
      "network interceptor ${interceptors[index - 1]} must retain the same host and port"
    }

    // If we already have a stream, confirm that this is the only call to chain.proceed().
    check(this.exchange == null || calls <= 1) {
      "network interceptor ${interceptors[index - 1]} must call proceed() exactly once"
    }

    // Call the next interceptor in the chain.
    val next = RealInterceptorChain(interceptors, transmitter, exchange,
        index + 1, request, call, connectTimeout, readTimeout, writeTimeout)
    val interceptor = interceptors[index]

    @Suppress("USELESS_ELVIS")
    val response = interceptor.intercept(next) ?: throw NullPointerException(
        "interceptor $interceptor returned null")

    // Confirm that the next interceptor made its required call to chain.proceed().
    check(exchange == null || index + 1 >= interceptors.size || next.calls == 1) {
      "network interceptor $interceptor must call proceed() exactly once"
    }

    check(response.body != null) { "interceptor $interceptor returned a response with no body" }

    return response
  }
```
在它的实现中，它会迭代拦截器的list，然后执行每个拦截器的`interceptor.intercept(next)`方法，可以猜测应该就是在最后的拦截器中执行了实际的请求，找到最后一个拦截器`CallServerInterceptor`，根据类的说明文档来看，确实就是它来实际执行了请求的发出和响应的接收，我们再来看一下它的intercept方法：
```kotlin
  @Throws(IOException::class)
  override fun intercept(chain: Interceptor.Chain): Response {
    val realChain = chain as RealInterceptorChain
    val exchange = realChain.exchange()
    val request = realChain.request()
    val requestBody = request.body
    val sentRequestMillis = System.currentTimeMillis()

    exchange.writeRequestHeaders(request)

    var responseHeadersStarted = false
    var responseBuilder: Response.Builder? = null
    if (HttpMethod.permitsRequestBody(request.method) && requestBody != null) {
      // If there's a "Expect: 100-continue" header on the request, wait for a "HTTP/1.1 100
      // Continue" response before transmitting the request body. If we don't get that, return
      // what we did get (such as a 4xx response) without ever transmitting the request body.
      if ("100-continue".equals(request.header("Expect"), ignoreCase = true)) {
        exchange.flushRequest()
        responseHeadersStarted = true
        exchange.responseHeadersStart()
        responseBuilder = exchange.readResponseHeaders(true)
      }
      if (responseBuilder == null) {
        if (requestBody.isDuplex()) {
          // Prepare a duplex body so that the application can send a request body later.
          exchange.flushRequest()
          val bufferedRequestBody = exchange.createRequestBody(request, true).buffer()
          requestBody.writeTo(bufferedRequestBody)
        } else {
          // Write the request body if the "Expect: 100-continue" expectation was met.
          val bufferedRequestBody = exchange.createRequestBody(request, false).buffer()
          requestBody.writeTo(bufferedRequestBody)
          bufferedRequestBody.close()
        }
      } else {
        exchange.noRequestBody()
        if (!exchange.connection()!!.isMultiplexed) {
          // If the "Expect: 100-continue" expectation wasn't met, prevent the HTTP/1 connection
          // from being reused. Otherwise we're still obligated to transmit the request body to
          // leave the connection in a consistent state.
          exchange.noNewExchangesOnConnection()
        }
      }
    } else {
      exchange.noRequestBody()
    }

    if (requestBody == null || !requestBody.isDuplex()) {
      exchange.finishRequest()
    }
    if (!responseHeadersStarted) {
      exchange.responseHeadersStart()
    }
    if (responseBuilder == null) {
      responseBuilder = exchange.readResponseHeaders(false)!!
    }
    var response = responseBuilder
        .request(request)
        .handshake(exchange.connection()!!.handshake())
        .sentRequestAtMillis(sentRequestMillis)
        .receivedResponseAtMillis(System.currentTimeMillis())
        .build()
    var code = response.code
    if (code == 100) {
      // server sent a 100-continue even though we did not request one.
      // try again to read the actual response
      response = exchange.readResponseHeaders(false)!!
          .request(request)
          .handshake(exchange.connection()!!.handshake())
          .sentRequestAtMillis(sentRequestMillis)
          .receivedResponseAtMillis(System.currentTimeMillis())
          .build()
      code = response.code
    }

    exchange.responseHeadersEnd(response)

    response = if (forWebSocket && code == 101) {
      // Connection is upgrading, but we need to ensure interceptors see a non-null response body.
      response.newBuilder()
          .body(EMPTY_RESPONSE)
          .build()
    } else {
      response.newBuilder()
          .body(exchange.openResponseBody(response))
          .build()
    }
    if ("close".equals(response.request.header("Connection"), ignoreCase = true) ||
        "close".equals(response.header("Connection"), ignoreCase = true)) {
      exchange.noNewExchangesOnConnection()
    }
    if ((code == 204 || code == 205) && response.body?.contentLength() ?: -1L > 0L) {
      throw ProtocolException(
          "HTTP $code had non-zero Content-Length: ${response.body?.contentLength()}")
    }
    return response
  }
```
代码很长，我们先看重点，确定在哪里发生了实际的请求。
```kotlin
    var response = responseBuilder
        .request(request)
        .handshake(exchange.connection()!!.handshake())
        .sentRequestAtMillis(sentRequestMillis)
        .receivedResponseAtMillis(System.currentTimeMillis())
        .build()
    var code = response.code
    if (code == 100) {
      // server sent a 100-continue even though we did not request one.
      // try again to read the actual response
      response = exchange.readResponseHeaders(false)!!
          .request(request)
          .handshake(exchange.connection()!!.handshake())
          .sentRequestAtMillis(sentRequestMillis)
          .receivedResponseAtMillis(System.currentTimeMillis())
          .build()
      code = response.code
    }

    exchange.responseHeadersEnd(response)

    response = if (forWebSocket && code == 101) {
      // Connection is upgrading, but we need to ensure interceptors see a non-null response body.
      response.newBuilder()
          .body(EMPTY_RESPONSE)
          .build()
    } else {
      response.newBuilder()
          .body(exchange.openResponseBody(response))
          .build()
    }
```
可以看到是在这里通过Response.Builder创建了Response，而这个builder是通过`exchange.readResponseHeaders`来创建的，Response的Request和ResponseBody也是通过`Exchange`来创建的，那么我们接下来一点一点去看Exchange是做了什么。

```kotlin
- exchange.writeRequestHeaders(request: Request)
- exchange.responseHeadersStart()
- exchange.readResponseHeaders(expectContinue:Boolean)
- exchange.flushRequest()
- exchange.createRequestBody(request: Request, duplex: Boolean)
- exchange.noRequestBody()
- exchange.noNewExchangesOnConnection()
- exchange.finishRequest()
- exchange.connection()!!.handshake()
- exchange.responseHeadersEnd(response: Response)
- exchange.openResponseBody(response: Response)
```

方法很多，为了方便理解，我们也画一个流程图来描述整个过程：
```flow
st=>start: Request开始
writeRequest=>operation: writeRequestHeaders
checkMethod=>condition: method=GET or HEAD
noRequestBody=>operation: noRequestBody
createRequestBody=>operation: createRequestBody
finishRequest=>operation: finishRequest
flushRequest=>operation: flushRequest
responseHeadersStart=>operation: responseHeadersStart
readResponseHeaders=>operation: readResponseHeaders
createResponse=>operation: 创建新Response
responseHeadersEnd=>operation: responseHeadersEnd
openResponseBody=>operation: openResponseBody
e=>end: 返回Response

st->writeRequest->checkMethod
checkMethod(no)->flushRequest->createRequestBody->finishRequest
checkMethod(yes)->noRequestBody->finishRequest
finishRequest->responseHeadersStart->createResponse->responseHeadersEnd->openResponseBody->e
```
当然，这个流程也不完善，并没有把对RequestHeader中包含`Except:101`情况的兼容画进来，也没有详细去看是否应该给Response添加ResponseBody，但是具体流程大致上的流向是这个方向。可以看到基本上所有的Request和Response相关的操作都是通过Exchange，接下来我们再去看Exchange内部的实现，可以发现这些方法中，主要是做了两件事：
	1. 通过EventListener去记录整个过程的相关操作；
	2. 使用Exchange内部的ExchangeCodec来操作Request和Response。

那么问题就清晰了，只要找到`ExchangeCodec`是在哪里初始化，是怎么初始化，就知道实际的请求是由谁来执行的了。
再回过头去看各个拦截器，最后在`ConnectInterceptor`中找到了`transmitter.newExchange(chain, doExtensiveHealthChecks)`，继续深入的话，可以看到：
```kotlin
val codec = exchangeFinder!!.find(client, chain, doExtensiveHealthChecks)
val result = Exchange(this, call, eventListener, exchangeFinder!!, codec)
```
是通过`ExchangeFinder.find`来做的初始化，再深入ExchangeFinder，发现最终是在`findConnection`方法里面做了初始化，通过findConnection返回的`RealConnection`来创建新的ExchangeCodec，根据是否有Http2Connection来确定创建`Http1ExchangdeCodeC`或者是`Http2ExchangeCodec`。

接下来我们对这个方法详细分析：
1. 检查发射器是否被cancel了，是则抛出IOException
2. 尝试使用发射器中的connection，检查发射器中的connection是否不为null，同时connection不能再创建新exchange，然后调用发射器的releaseConnectionNoEvents返回需要关闭的socket，否则返回null
3. 如果发射器中的connection为null，从连接池中获取可用connection，并将可用connection缓存到发射器中
4. 如果连接池中没找到可用connection，检查是否有可用路由，如果没有可用路由，尝试复用当前路由(从发射器中获取connection的路由)
5. 关闭之前的socket
6. 如果此时找到合适的connection了(connection!=null)，返回找到的connection
7. 检查当前路由是否可用，如果不可用则创建一个新路由
8. 检查是否路由已经初始化，从已经初始化的路由中获取connection，将connection缓存到发射器中
9. 如果路由没初始化或者路由中没找到合适的connection，创建一个新的connection
10. 检查foundPooledConnection，如果为true，直接返回connection
11. 如果foundPooledConnection为false，使用之前新创建的connection执行socket连接，实际上是初始化connection中的Http1Connection或Http2Connection
12. 连接上之后缓存connection的路由到连接池的路由缓存数据库
13. 缓存connection到connectionpool和发射器
14. 返回connection

第11步就是确定是http2协议还是http1协议的地方，我们来看一下具体的代码：
```kotlin
  fun connect(
    connectTimeout: Int,
    readTimeout: Int,
    writeTimeout: Int,
    pingIntervalMillis: Int,
    connectionRetryEnabled: Boolean,
    call: Call,
    eventListener: EventListener
  ) {
    check(protocol == null) { "already connected" }

    var routeException: RouteException? = null
    val connectionSpecs = route.address.connectionSpecs
    val connectionSpecSelector = ConnectionSpecSelector(connectionSpecs)

    if (route.address.sslSocketFactory == null) {
      if (ConnectionSpec.CLEARTEXT !in connectionSpecs) {
        throw RouteException(UnknownServiceException(
            "CLEARTEXT communication not enabled for client"))
      }
      val host = route.address.url.host
      if (!Platform.get().isCleartextTrafficPermitted(host)) {
        throw RouteException(UnknownServiceException(
            "CLEARTEXT communication to $host not permitted by network security policy"))
      }
    } else {
      if (Protocol.H2_PRIOR_KNOWLEDGE in route.address.protocols) {
        throw RouteException(UnknownServiceException(
            "H2_PRIOR_KNOWLEDGE cannot be used with HTTPS"))
      }
    }

    while (true) {
      try {
        if (route.requiresTunnel()) {
          connectTunnel(connectTimeout, readTimeout, writeTimeout, call, eventListener)
          if (rawSocket == null) {
            // We were unable to connect the tunnel but properly closed down our resources.
            break
          }
        } else {
          connectSocket(connectTimeout, readTimeout, call, eventListener)
        }
        establishProtocol(connectionSpecSelector, pingIntervalMillis, call, eventListener)
        eventListener.connectEnd(call, route.socketAddress, route.proxy, protocol)
        break
      } catch (e: IOException) {
        socket?.closeQuietly()
        rawSocket?.closeQuietly()
        socket = null
        rawSocket = null
        source = null
        sink = null
        handshake = null
        protocol = null
        http2Connection = null

        eventListener.connectFailed(call, route.socketAddress, route.proxy, null, e)

        if (routeException == null) {
          routeException = RouteException(e)
        } else {
          routeException.addConnectException(e)
        }

        if (!connectionRetryEnabled || !connectionSpecSelector.connectionFailed(e)) {
          throw routeException
        }
      }
    }

    if (route.requiresTunnel() && rawSocket == null) {
      throw RouteException(ProtocolException(
          "Too many tunnel connections attempted: $MAX_TUNNEL_ATTEMPTS"))
    }

    val http2Connection = this.http2Connection
    if (http2Connection != null) {
      synchronized(connectionPool) {
        allocationLimit = http2Connection.maxConcurrentStreams()
      }
    }
  }
```
可以看到大体上是如下的步骤来确定具体协议的：
1. 检查sslFactory配置
2. 检查是否需要建立代理隧道，需要则建立隧道
3. 连接socket
4. 根据协议建立连接(RealConnection#establishProtocol)，在这里决定是使用http1还是http2

再看一下关键的`establishProtocol`方法：
```kotlin
  @Throws(IOException::class)
  private fun establishProtocol(
    connectionSpecSelector: ConnectionSpecSelector,
    pingIntervalMillis: Int,
    call: Call,
    eventListener: EventListener
  ) {
    if (route.address.sslSocketFactory == null) {
      if (Protocol.H2_PRIOR_KNOWLEDGE in route.address.protocols) {
        socket = rawSocket
        protocol = Protocol.H2_PRIOR_KNOWLEDGE
        startHttp2(pingIntervalMillis)
        return
      }

      socket = rawSocket
      protocol = Protocol.HTTP_1_1
      return
    }

    eventListener.secureConnectStart(call)
    connectTls(connectionSpecSelector)
    eventListener.secureConnectEnd(call, handshake)

    if (protocol === Protocol.HTTP_2) {
      startHttp2(pingIntervalMillis)
    }
  }
```
可以看到就是很简单的判断了一下是否设置了sslFactory，如果未设置，判断对应路由地址的协议是否是`Protocol.H2_PRIOR_KNOWLEDGE`协议，如果是则直接使用`Protocol.H2_PRIOR_KNOWLEDGE`，如果不是就使用`Protocol.HTTP_1_1`，如果设置了sslFactory，则尝试tls连接，连接时由Platform判断具体要使用的协议。

具体代码如下：
```kotlin
      val maybeProtocol = if (connectionSpec.supportsTlsExtensions) {
        Platform.get().getSelectedProtocol(sslSocket)
      } else {
        null
      }
//省略不必要代码
      protocol = if (maybeProtocol != null) Protocol.get(maybeProtocol) else Protocol.HTTP_1_1
```

而Android这边的实现如下：
```kotlin
          val getAlpnSelectedProtocol = sslSocketClass.getMethod("getAlpnSelectedProtocol")
//省略不必要代码

  override fun getSelectedProtocol(socket: SSLSocket): String? {
    return if (sslSocketClass.isInstance(socket))
      try {
        val alpnResult = getAlpnSelectedProtocol.invoke(socket) as ByteArray?
        if (alpnResult != null) String(alpnResult, UTF_8) else null
      } catch (e: IllegalAccessException) {
        throw AssertionError(e)
      } catch (e: InvocationTargetException) {
        throw AssertionError(e)
      }
    else {
      null // No TLS extensions if the socket class is custom.
    }
  }
```

可以看到最终还是调用了Android SDK的方法来决定的。

自此，粗略的分析就到此为止了，等以后水平提升了，再来写一下OkHttp这样实现的原因和优点。

## 关键类
### 用户端
- `OkHttpClient`
- `Request`和`Response`
- `Call`

### 实现
- `Call`和`RealCall`
- `Chain`和`RealInterceptorChain`
- `Exchange`
- `RealConnection`

### 内置的类
- `RetryAndFollowUpInterceptor`
- `BridgeInterceptor`
- `CacheInterceptor`
- `ConnectInterceptor`
- `CallServerInterceptor`
- `FormBody`
- `MultiPartBody`

### 拦截器执行顺序

```flow
st=>start: call执行execute
user_interceptor=>operation: 用户自定义拦截器
RetryAndFollowUpInterceptor=>operation: RetryAndFollowUpInterceptor
BridgeInterceptor=>operation: BridgeInterceptor
CacheInterceptor=>operation: CacheInterceptor
ConnectInterceptor=>operation: ConnectInterceptor
CallServerInterceptor=>operation: CallServerInterceptor
user_network_interceptor=>operation: 用户自定义网络拦截器
e=>end: 返回response

st->user_interceptor->user_interceptor->RetryAndFollowUpInterceptor->BridgeInterceptor
BridgeInterceptor->CacheInterceptor
CacheInterceptor->ConnectInterceptor
ConnectInterceptor->user_network_interceptor->CallServerInterceptor->e
```