---
title: Realm Bugs
---
# Realm和DataBinding混用的一个小bug
## 原本有一个实体类A，新加了一个类型为`ArrayList<B>`的字段，这个B内部有一个`ArrayList<String>`字段，然后编译发现抛出错误：java: Type java.util.List<java.lang.String> of field b is not supported；大致意思就是Realm不支持直接使用`ArrayList<String>`作为类的字段。
去到realm的github找到解决方案：采用`RealmList`代替`ArrayList`，新建一个`StringObject`继承`RealmObject`，这个StringObject只有一个`String`类型的字段，大致类似于
```
  class StringObject extends RealmObject {
      @PrimaryKey
      private String string;
      //...getter & setter
  }
```
## 那么问题解决了么？并没有。编译依然抛出错误，错误变成了`xxx.xxx.xxx.binding not found`，大致意思就是没找到binding类，不过没有指明到哪一行。
好，继续排查，没有指明到哪一行就多输出一点log吧，使用命令行手动编译`gradle assembleDebug --info --debug --stacktrace`，之后真正的问题出现了：
```
A did not create a default no param constructor
B did not create a default no param constructor
StringObject did not create a default no param constructor
```
意思是没有添加一个默认的无参构造函数，那么直接添加上，编译通过，完毕。
