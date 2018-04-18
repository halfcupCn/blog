---
title: RxJava操作符使用1
date: 2017-09-05 20:51:21
tags:
---

>RxJava用了很久了，但是一直都是最简单的`flatMap`或者`just`、`from`、`foreach`这种简单的操作符就完毕了，很难用到其他的操作符，等到用到的时候再去查又有一点太晚了，所以这次干脆就一次性全部都看看到底都是些什么操作符和作用。

*这些操作符都只针对当前我使用的版本：RxAndroid 1.1.2-RxJava 1.1.6来介绍，源文档来自[Rx官方文档](http://reactivex.io/documentation/operators.html#categorized)*

# 创建Observables
顾名思义，所有下列操作符都会创建Observable**s**
## Create
>create an Observable from scratch by calling observer methods programmatically
>意思是调用observer的方法从头创建**一个**Observable

示例代码：

```
Observable.create(new Observable.OnSubscribe<Integer>() {
    @Override
    public void call(Subscriber<? super Integer> observer) {
        try {
            if (!observer.isUnsubscribed()) {
                for (int i = 1; i < 5; i++) {
                    observer.onNext(i);
                }
                observer.onCompleted();
            }
        } catch (Exception e) {
            observer.onError(e);
        }
    }
 } ).subscribe(new Subscriber<Integer>() {
        @Override
        public void onNext(Integer item) {
            System.out.println("Next: " + item);
        }

        @Override
        public void onError(Throwable error) {
            System.err.println("Error: " + error.getMessage());
        }

        @Override
        public void onCompleted() {
            System.out.println("Sequence complete.");
        }
    });
```

用Create操作符可以从头创建一个Observable，传递给这个Observable一个接收observer作为它的参数的方法，在这个方法体内按合适的顺序调用`onNext`，`onError`，`onCompleted`来让这个方法成为一个正确的的Observable-其中`onCompleted`和`onErrir`至少执行一个，并且它们之后不要再调用这个Observable的其它方法。

## Defer
> 当observer订阅时，给每个observer创建一个新的Observable

示例代码：

```

```