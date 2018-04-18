# 小提示，等有空了可以操作分类

```
android.support.design.widget.CollapsingToolbarLayout的层级问题
有两个子View：A,B
布局如下
<CollapsingToolbarLayout>
<A/>
<B/>
</CollapsingToolbarLayout>
如果此时设置layout_collapseMode=pin,那么B的内容会在A的上层 
```

`elevation只在有background时起作用`