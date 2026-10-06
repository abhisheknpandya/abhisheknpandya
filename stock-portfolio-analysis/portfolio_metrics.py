"""Reusable risk/return metrics and portfolio optimisation helpers.

All functions work on daily data and annualise using 252 trading days.
"""

import numpy as np
import pandas as pd
from scipy.optimize import minimize

TRADING_DAYS = 252


def load_prices(path):
    """Load the price CSV into a DataFrame indexed by date, oldest first."""
    prices = pd.read_csv(path, parse_dates=["Date"]).set_index("Date").sort_index()
    return prices


def daily_returns(prices):
    """Simple daily percentage returns."""
    return prices.pct_change().dropna()


def cagr(prices):
    """Compound annual growth rate between the first and last price."""
    years = (prices.index[-1] - prices.index[0]).days / 365.25
    return (prices.iloc[-1] / prices.iloc[0]) ** (1 / years) - 1


def annual_volatility(returns):
    """Annualised standard deviation of daily returns."""
    return returns.std() * np.sqrt(TRADING_DAYS)


def sharpe_ratio(returns, risk_free=0.02):
    """Annualised excess return per unit of volatility."""
    excess = returns.mean() * TRADING_DAYS - risk_free
    return excess / annual_volatility(returns)


def sortino_ratio(returns, risk_free=0.02):
    """Like Sharpe, but only penalises downside volatility."""
    excess = returns.mean() * TRADING_DAYS - risk_free
    downside = returns.clip(upper=0).pow(2).mean().pow(0.5) * np.sqrt(TRADING_DAYS)
    return excess / downside


def drawdown(prices):
    """Percentage fall from the running peak at each date."""
    return prices / prices.cummax() - 1


def max_drawdown(prices):
    """Worst peak-to-trough fall over the whole period."""
    return drawdown(prices).min()


def beta(returns, market):
    """Sensitivity of each asset's returns to the market's returns."""
    return returns.apply(lambda col: col.cov(market) / market.var())


def summary_table(prices, market_col="GSPC", risk_free=0.02):
    """One row per asset with the headline risk/return statistics."""
    returns = daily_returns(prices)
    return pd.DataFrame({
        "CAGR": cagr(prices),
        "Volatility": annual_volatility(returns),
        "Sharpe": sharpe_ratio(returns, risk_free),
        "Sortino": sortino_ratio(returns, risk_free),
        "Max drawdown": max_drawdown(prices),
        "Beta": beta(returns, returns[market_col]),
    })


def portfolio_performance(weights, mean_returns, cov_matrix, risk_free=0.02):
    """Annualised return, volatility and Sharpe ratio for a set of weights."""
    ret = np.dot(weights, mean_returns) * TRADING_DAYS
    vol = np.sqrt(weights @ cov_matrix @ weights) * np.sqrt(TRADING_DAYS)
    return ret, vol, (ret - risk_free) / vol


def random_portfolios(returns, n=10_000, risk_free=0.02, seed=42):
    """Simulate long-only portfolios with random weights."""
    rng = np.random.default_rng(seed)
    mean, cov = returns.mean().values, returns.cov().values
    weights = rng.dirichlet(np.ones(returns.shape[1]), size=n)
    stats = np.array([portfolio_performance(w, mean, cov, risk_free) for w in weights])
    result = pd.DataFrame(stats, columns=["Return", "Volatility", "Sharpe"])
    return result, weights


def _optimise(returns, objective, target_return=None):
    n = returns.shape[1]
    mean, cov = returns.mean().values, returns.cov().values
    constraints = [{"type": "eq", "fun": lambda w: w.sum() - 1}]
    if target_return is not None:
        constraints.append({
            "type": "eq",
            "fun": lambda w: np.dot(w, mean) * TRADING_DAYS - target_return,
        })
    result = minimize(
        objective,
        x0=np.full(n, 1 / n),
        args=(mean, cov),
        bounds=[(0, 1)] * n,
        constraints=constraints,
        method="SLSQP",
    )
    return pd.Series(result.x, index=returns.columns).round(6)


def max_sharpe_weights(returns, risk_free=0.02):
    """Long-only weights with the highest Sharpe ratio."""
    return _optimise(
        returns, lambda w, m, c: -portfolio_performance(w, m, c, risk_free)[2]
    )


def min_volatility_weights(returns, target_return=None):
    """Long-only weights with the lowest volatility (optionally for a target return)."""
    return _optimise(
        returns, lambda w, m, c: portfolio_performance(w, m, c)[1], target_return
    )


def efficient_frontier(returns, points=40):
    """Volatility of the minimum-risk portfolio across a range of target returns."""
    annual_mean = returns.mean() * TRADING_DAYS
    low = portfolio_performance(
        min_volatility_weights(returns).values, returns.mean(), returns.cov().values
    )[0]
    targets = np.linspace(low, annual_mean.max(), points)
    vols = []
    for target in targets:
        w = min_volatility_weights(returns, target).values
        vols.append(portfolio_performance(w, returns.mean().values, returns.cov().values)[1])
    return pd.DataFrame({"Return": targets, "Volatility": vols})


def backtest(prices, weights, start_value=10_000):
    """Value of a buy-and-hold portfolio (no rebalancing) over time."""
    normalised = prices[weights.index] / prices[weights.index].iloc[0]
    return (normalised * weights * start_value).sum(axis=1)
