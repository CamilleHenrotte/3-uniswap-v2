# TWAP oracle with Uniswap V2

---

#### Why does the price0CumulativeLast and price1CumulativeLast never decrement?

Price0CumulativeLast and price1CumulativeLast never decrement because they represent the sum of time-weighted average prices. Since only the difference from one time to another matter, this prices can overflow without problems.

#### How do you write a contract that uses the oracle?

The contract that uses oracle would have to cache the price cumulative from a defined time period back then take the current price cumualtive and doing the difference dividing by the time period, it will give the TWAP.

#### Why are price0CumulativeLast and price1CumulativeLast stored separately?

Price0CumulativeLast and Price1CumulativeLast are store separately, because we can't derive one TWAP directly from the other TWAP. Indeed the average of inverses is different from the inverse of the average.
