## why does the `price0CumulativeLast` and `price1CumulativeLast` never decrement?

these variables represent the cumulative price of each token over time and represent a time weighted average price over a guven period. thus they are recorded by summing the current price of the token weigthed by the time since the last update. 

## How do you write a contract that uses the oracle

In order to utilize the oracle in a contract you must first determine the window of time for which you want a time weighted average price of the token. Then you must record a snapshot at the beginning of the window recording the time and cumulative price at the windows start. Once the window has closed, you can record the most recent cumaltive price at the end of the window and using the difference between the recent cumulative price and the starting cumulative price divided by the time elapsed between the two price calculate the time weighted average price of the token over the time elapsed.

## Why are `price0CumulativeLast` and `price1CumulativeLast` stored seperately? wy not just calculate `price1cumulativeLast = 1/price0cumulativeLast`?

Because the variable `price0CumulativeLast` and `price1CumulativeLast` are both cumulative prices of the token over time they do not maintain the inverse relationship that the ratio of the value two tokens does and thus must be stored seperately and cannot be derived from one another by simple inversion.

