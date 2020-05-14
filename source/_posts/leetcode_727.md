## 原问题地址
>https://leetcode.com/explore/interview/card/top-interview-questions-easy/92/array/727/

## 问题翻译
对一个排好序的非负数数组进行去重，返回去重后的数组长度，空间复杂度需要为**O(1)**

## 示例
对输入[1,1,2,3,3,4]，去重后为[1,2,3,4]，返回的长度为4

## 问题解析
因为已经排好序了，所以问题实际上就变成了对数组中不同数字的计数，每记到一个不同数字，将这个数字和数组中计数的下标相同的数字交换，即完成验证

## 通过的解决方案
```kotlin
    /**
     * 去除一个已经排序好的数组中的重复数字，返回去重后的数组长度
     */
    fun removeDuplicates(nums: IntArray): Int {
        var count = 0
        for (index in nums.indices) {
            if (count != index) {
                if (nums[count] != nums[index]) {
                    nums[++count] = nums[index]
                }
            }
        }
        return count.let {
            when {
                (it == 0 && nums.isNotEmpty()) || it != 0 -> {
                    return it + 1
                }
                else -> it
            }
        }
    }
```