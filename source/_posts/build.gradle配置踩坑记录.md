## 修改`buildTypes`出现的坑
### 前提
1. 项目中有主应用模块`app`，依赖了模块`lib`
2. 原本两个模块的buildTypes都是：
```groovy
buildTypes {
    debug {
        ...
    }
    release {
        ...
    }
}
```
这样的结构

### 修改
因为业务需求，现在添加一个新的type叫`test`

现在app的buildTypes变成了这样：
```groovy
buildTypes {
    debug {
        ...
    }
    release {
        ...
    }
    test {
        ...
    }
}
修改完成之后编译，会提示不通过，抛出错误`Unable to resolve dependency for ':app@test/compileClasspath': Could not resolve project :lib.`
```

这个错误搞得我一头雾水，后来偶然想起来不知道哪里看的文章说现在需要将所有模块中的buildtypes对齐，后来将lib中的buildTypes修改之后就成功编译了，故记录此坑。