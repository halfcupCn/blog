> 源说明来自Gradle官网对build流程的[介绍](https://docs.gradle.org/current/userguide/build_lifecycle.html#build_lifecycle)

## build阶段
1. Initialization/初始化
Gradle支持单项目和多项目build，在初始化阶段，Gradle确定要参与build过程中的哪些部分，同时为每个项目生成一个`Project`实例；

2. Configuration/配置
这个阶段`project`实例会添加配置，项目中的构建脚本将被执行；

3. Execution/执行
Gradle在这个阶段生成并配置任务的子集，然后执行。子集通过传递给gradle命令的任务名来确定，确定后会逐一执行任务。

## 设置文件
除了那些构建脚本，Gradle还定义了一些设置文件。这些设置文件取决于Gradle的命名惯例。默认的设置文件名称是`settings.gradle`。

设置文件在初始化阶段被执行。一个多项目的构建，必须要在根项目的多项目层次结构中有一个`settings.gradle`文件，它用来定义某个项目参与多项目构建中的哪个阶段。对单项目构建来说，它是可选项。除了定义被囊括的项目以外，你还可以用它来向你的构建脚本的`classpath`添加库。

对构建脚本来说，所有的属性获取和方法调用都通过`project`实例代理实现，与此相似的是设置文件中所有的属性获取的方法调用都通过[`Setting`](https://docs.gradle.org/current/dsl/org.gradle.api.initialization.Settings.html)实例代理。

## 多项目构建
你需要在设置文件中声明参与多项目构建的项目，具体详见：[multi_project_build](https://docs.gradle.org/current/userguide/multi_project_builds.html#multi_project_builds)

### 项目位置
多项目构建由一棵只有一个根节点的树来代表。树上面的每一个节点都代表一个项目。一个项目有一个代表它在多项目构建树中位置的路径。大多数情况下，项目路径和项目在物理文件系统中的路径一致。但是这个路径是可以配置的。项目树在`settings.gradle`中被创建。默认情况下设置文件的路径也就是root项目的路径。

### 构建树
在设置文件中，你可以使用很多方法去构建项目树。分层和平铺的物理布局得到特别支持。

#### 分层布局
```groovy
settings.gradle
include 'project1', 'project2:child', 'project3:child1'
```
`include`方法把项目地址当作参数。项目路径被当作和相对物理文件系统路径一致。比如说"services:api"被映射为相对于root项目的"services/api"。你只需要指定树的叶子。这意味着对包含"services:hotels:api"会导致生成三个`project`：`services`、`services:hotels`和`services:hotels:api`。

#### 平铺布局
```groovy
settings.gradle
includeFlat 'project3', 'project4'
```
`includeFlat`方法把目录名字当作参数。这些目录要作为root项目的子目录。在多项目构建时这些目录应该是root项目的子项目。

#### 修改项目树的元素
在设置文件中，由所谓的[项目描述符(project descriptors)](https://docs.gradle.org/current/javadoc/org/gradle/api/initialization/ProjectDescriptor.html)来生成多项目构建树。任何时间你都可以在设置文件中修改描述符。可以采用如下方式来修改：
```groovy
settings.gradle
println rootProject.name
println project(':projectA').name
```
通过描述符你可以改变项目的名字、项目目录和构建文件。

通过如下代码可以改变项目树的元素：
```groovy
rootProject.name = 'main'
project(':projectA').projectDir = new File(settingsDir, '../my-project-a')
project(':projectA').buildFileName = 'projectA.gradle'
```

### 初始化
Gradle怎么确定当前是单项目构建还是多项目构建呢？具体是通过`settings.gradle`文件来确定的。
Gradle通过如下方式寻找`settings.gradle`文件：

- 会寻找和当前目录同一逻辑层级的`master`目录
- 没找到会去父目录寻找
- 没找到的话会当作单项目构建
- 如果找到了`settings.gradle`文件，Gradle会检查当前项目是不是定义在`settings.gradle`文件中的多项目构建中，如果不是的话，会当作单项目构建，否则会启动多项目构建。

这个行为的目的是什么呢？Gradle需要确定当前执行构建命令所在的项目是在不是在一个多项目构建的子项目中。当然，如果是一个子项目，只有它和它依赖的项目会被构建，但是Gradle需要为整个多项目构建生成配置。如果当前项目包含一个`settings.gradle`文件，那么会按照如下方式执行：
- 如果`settings.gradle`文件中没有指定多项目层次结构，执行单项目构建
- 否则执行多项目构建 

只有带物理多层次结构或者平铺布局的多项目构建会自动搜索`settings.gradle`文件。对平铺布局来说，必须额外遵循`master`上的命名规范。Gradle支持自定义的物理布局，但当你需要在设置文件所在目录执行构建。可见[在绝对路径上执行任务](https://docs.gradle.org/current/userguide/multi_project_builds.html#sec:running_partial_build_from_the_root)。

多项目构建时，Gradle会为`Setting`对象中包括root项目在内的所有项目都生成一个`project`对象，对象的默认名字是对应项目的根目录的名字，而且除了root项目以外的其它项目都有父项目。每个项目都可能有子项目。

### 单项目构建的配置和执行
对单项目文件来说，初始化之后的工作流相当简洁。针对生成`project`对象的构建脚本在初始化阶段中执行。Gradle执行和命令行中参数名字一样的任务。如果找到对应的任务，它们会按照参数传递的顺序作为独立的构建来执行。可见[多项目构建](https://docs.gradle.org/current/userguide/multi_project_builds.html#multi_project_builds)

### 响应构建脚本中的生命周期
构建脚本可以在构建过程中通过生命周期接收通知。这些通知可以通过两种形式实现：要么实现一个特定的[监听接口](https://docs.gradle.org/current/javadoc/org/gradle/api/ProjectEvaluationListener.html)，要么当通知发送时传递一个可执行的闭包。接下来将用闭包来举例。

#### 项目评估
项目被评估前和之后你都会立即收到一个通知。当一个构建脚本中的所有定义都应用了这可以用来执行额外的配置，或者是添加一些额外的日志记录和分析。

下面是给有`hasTests`属性的项目添加一个`test`任务的实例：
```groovy
build.gradle
allprojects {
    afterEvaluate { project ->
        if (project.hasTests) {
            println "Adding test task to $project"
            project.task('test') {
                doLast {
                    println "Running tests for $project"
                }
            }
        }
    }
}
```
```groovy
projectA.gradle
hasTests = true
```

Output of` gradle -q test`
```
> gradle -q test
Adding test task to project ':projectA'
Running tests for project ':projectA'
```

示例使用`Project.afterEvaluate()`为项目添加一个在被评估后执行的闭包。

任何项目被评估的时候都可以收到通知。下面的示例为项目评估增加了一些自定义的日志。请注意`afterProject`这个通知不管项目评估成功或者异常失败都会发出。

```groovy
build.gradle
gradle.afterProject { project ->
    if (project.state.failure) {
        println "Evaluation of $project FAILED"
    } else {
        println "Evaluation of $project succeeded"
    }
}
```

#### 任务生成
当任务添加到项目之后你会马上收到一个通知。这可以用来给构建文件中任务在可用之前设置一些默认值或者添加一些行为。

下面的示例展示了当项目创建时给项目设置`srcDir`属性：
```groovy
build.gradle
tasks.whenTaskAdded { task ->
    task.ext.srcDir = 'src/main/java'
}

task a

println "source dir is $a.srcDir"
```

`gradle -q a`的执行结果
```
> gradle -q a
source dir is src/main/java
```

#### 任务执行图形化
当任务执行情况[图表](https://docs.gradle.org/current/userguide/tutorial_using_tasks.html#configure-by-dag)填充完毕之后，你会立即收到一个通知，你也可以给[`TaskExecutionGraph`](https://docs.gradle.org/current/javadoc/org/gradle/api/execution/TaskExecutionGraph.html)添加[`TaskExecutionGraphListener`](https://docs.gradle.org/current/javadoc/org/gradle/api/execution/TaskExecutionGraph.html)来接收这个通知。

#### 任务执行
当任务执行前和执行完成后你都会收到通知。

下面的示例展示了在任务执行的前后做记录，值得注意的是，`afterTask`通知不管任务成功执行或是异常失败都会发出。

```groovy
build.gradle
task ok

task broken(dependsOn: ok) {
    doLast {
        throw new RuntimeException('broken')
    }
}

gradle.taskGraph.beforeTask { Task task ->
    println "executing $task ..."
}

gradle.taskGraph.afterTask { Task task, TaskState state ->
    if (state.failure) {
        println "FAILED"
    }
    else {
        println "done"
    }
}
```

`gradle -q broken`输出结果
```
> gradle -q broken
executing task ':ok' ...
done
executing task ':broken' ...
FAILED

FAILURE: Build failed with an exception.

* Where:
Build file '/home/user/gradle/samples/groovy/build.gradle' line: 5

* What went wrong:
Execution failed for task ':broken'.
> broken

* Try:
Run with --stacktrace option to get the stack trace. Run with --info or --debug option to get more log output. Run with --scan to get full insights.

* Get more help at https://help.gradle.org

BUILD FAILED in 0s
```