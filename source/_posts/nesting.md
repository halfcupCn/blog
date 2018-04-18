---
title: nesting.md
date: 2017-04-18 21:35:08
---

# NestedScrollingChild
利用NestedScrollingChild和SwipeRefreshLayout和LoadMoreRecyclerView实现EmptyView和上拉加载和下拉刷新

## 前言

上拉加载和下拉刷新都已经由 [LoadMoreRecyclerView](https://github.com/1030310877/LoadMoreRecyclerView)实现了，不过他这个还是有一些bug，我已经在具体使用的过程中修复过了，最后还缺少一个EmptyView的功能，正好最近在学习v4包中的NestedScrollingChild和NestedScrollingParent，就利用NestedScrollingChild实现了一个EmptyView。

## 原理

