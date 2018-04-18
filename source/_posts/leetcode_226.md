---
title: leetcode no.226
date: 2017-07-20 21:19:00
---

# 大家都知道的Google拒绝HomeBrew作者的反转二叉树

##说明

原本的二叉树如下：

         4
       /   \
      2     7
     / \   / \
    1   3 6   9


转换之后的二叉树如下：

         4
       /   \
      7     2
     / \   / \
    9   6 3   1

##leetcode提供分析
```
/**
  * Definition for a binary tree node.
  * public class TreeNode {
  * int val;
  * TreeNode left;
  * TreeNode right;
  * TreeNode(int x) { val = x; }
  * }
  */
```
##具体分析
没啥好说的，每个节点都遍历之后交换子节点即可

##具体实现(Java)
```
public class Solution {
    public TreeNode invertTree(TreeNode root) {
        root = invert(root);
        sout(root);
        return root;
    }
    
    private TreeNode invert(TreeNode node){
        if(node != null ){//&& node.left != null && node.right != null
            TreeNode tmp = node.left;
            node.left = invert(node.right);
            node.right = invert(tmp);
        }
        return node;
    }
    
    private String sout(TreeNode node){
        if(node == null){
            return "null";
        }
        StringBuilder builder = new StringBuilder();
        builder.append(node.val).append("\n");
        if(node.left != null){
            builder.append("-").append(sout(node.left)).append("\n");
        }
        if(node.right != null){
            builder.append("-").append(sout(node.right)).append("\n");
        }
        return builder.toString();
    }
}
```