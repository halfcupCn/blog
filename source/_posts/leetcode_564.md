## 原问题地址
>https://leetcode.com/explore/interview/card/top-interview-questions-easy/92/array/564/

## 问题翻译
有一个代表价格的数组，第i个元素代表第i天的价格。
设计一个算法来获取最大的利润，所以你可能进行需要尽可能多次的交易。
注意，买入和卖出不能在同一天，你也可以理解为买入和卖出都要花费一天时间。

## 示例
### 输入
[7,1,5,3,6,4]
### 解释
1. 第2天买入，价格为1，第3天卖出，价格为5，获利4
2. 第4天买入，价格为3，第5天卖出，价格为6，获利3
3. 总获利7
### 结果
结果为7

## 问题解析
把问题分区间来看，就变成了寻找一段区间之内的最小数和最大数，一旦寻找到一个最大数即完成一次**交易**，所以具体步骤如下：
1. 数组price，从一个确定的点i出发，此时最小数和最大数的下标为prior和later，此时i=prior=later；
2. 向后移动下标，得到当前元素price[j]；
3. 如果price[j]小于price[prior]，则prior=j；
4. 如果price[j]大于price[later]，则later=j；
5. 如果price[j]小于price[later]，则视为找到一个区间最大数，进行交易，sum+=price[later]-price[prior]；
6. 存在一个特例，即当下标到达数组的末尾时，无法再增加/减小，所以可以直接视为区间最大数。

## 通过的解决方案
```kotlin
    fun maxProfit(prices: IntArray): Int {
        return prices.let {
            if (it.size <= 1) {
                0
            } else {
                val fullIndex = it.indices
                //start from 0
                var prior = 0
                var later = 0

                var sum = 0
                while (prior in fullIndex) {
                    if (it[prior] > it[later]) {
                        prior = later
                    } else {
                        for (index in prior until it.size) {
                            if (index == it.size - 1) {
                                //last,need skip
                                sum += if (it[index] > it[later]) {
                                    it[index] - it[prior]
                                } else {
                                    it[later] - it[prior]
                                }
                                prior = it.size
                            } else if (it[index] > it[later]) {
                                later = index
                            } else if (it[index] < it[later]) {
                                sum += it[later] - it[prior]
                                later = index
                                prior = index
                                break
                            }
                        }
                        if (later == 0) {
                            //not found
                            break
                        }
                    }
                }
                sum
            }
        }
    }
```