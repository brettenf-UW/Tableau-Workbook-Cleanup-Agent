# Good Comment Examples by Category

Real examples of meaningful comments for Tableau calculated fields.

---

## Metrics (📊)

```
// Aggregates total revenue for the selected time period on exec dashboard
SUM([Revenue])

// Calculates gross margin percentage for profitability analysis
([Revenue] - [Cost]) / [Revenue]

// Counts unique customers for market penetration reporting
COUNTD([Customer ID])

// Computes average deal size for sales performance benchmarking
AVG([Deal Amount])

// Calculates quota attainment percentage for rep scorecards
SUM([Actual]) / SUM([Quota])

// Growth rate vs prior year for trend analysis on leadership review
(SUM([This Year]) - SUM([Last Year])) / SUM([Last Year])
```

---

## Dates (📅)

```
// Converts to fiscal year (July 1 start) for financial reporting alignment
DATETRUNC('year', DATEADD('month', -6, [Order Date]))

// Calculates days since last purchase for customer engagement scoring
DATEDIFF('day', [Last Purchase], TODAY())

// Identifies current quarter flag for filtering to active period
DATETRUNC('quarter', [Date]) = DATETRUNC('quarter', TODAY())

// Computes YTD running total for cumulative performance tracking
RUNNING_SUM(SUM([Sales]))

// Extracts week number for weekly trend analysis on ops dashboard
DATEPART('week', [Created Date])

// Calculates age in days for SLA compliance monitoring
DATEDIFF('day', [Created Date], [Resolved Date])
```

---

## Filters (🚦)

```
// Flags active customers only for renewal pipeline exclusion
[Status] = 'Active' AND [Churn Date] IS NULL

// Identifies accounts needing follow-up based on 30-day inactivity rule
DATEDIFF('day', [Last Contact], TODAY()) > 30

// Filters to current user's territory for RLS enforcement
[Region] = USERNAME()

// Excludes test accounts from production metrics reporting
NOT CONTAINS([Account Name], 'TEST')

// Flags high-priority deals for sales manager focus list
[Deal Size] > 100000 AND [Stage] IN ('Negotiation', 'Proposal')

// Parameter-driven date range filter for flexible dashboard analysis
[Order Date] >= [Start Date Param] AND [Order Date] <= [End Date Param]
```

---

## Display (🎨)

```
// Formats currency with K/M suffix for dashboard readability
IF [Value] >= 1000000 THEN STR(ROUND([Value]/1000000, 1)) + 'M'
ELSEIF [Value] >= 1000 THEN STR(ROUND([Value]/1000, 1)) + 'K'
ELSE STR(ROUND([Value], 0)) END

// Generates tooltip text combining key metrics for hover detail
'Revenue: ' + STR([Revenue]) + ' | Deals: ' + STR([Deal Count])

// Creates rank label with ordinal suffix for leaderboard display
STR([Rank]) + CASE [Rank] % 10
  WHEN 1 THEN 'st' WHEN 2 THEN 'nd' WHEN 3 THEN 'rd' ELSE 'th' END

// Color coding based on performance thresholds for visual alerting
IF [Attainment] >= 1 THEN 'Green'
ELSEIF [Attainment] >= 0.8 THEN 'Yellow'
ELSE 'Red' END

// Truncates long names to 20 chars for chart label fitting
IF LEN([Product Name]) > 20 THEN LEFT([Product Name], 17) + '...'
ELSE [Product Name] END

// Creates dynamic axis title based on selected measure parameter
'Sales by ' + [Dimension Param]
```

---

## Projections (🔮)

```
// Projects year-end revenue based on current run rate
SUM([YTD Revenue]) / [Days Elapsed] * 365

// Estimates completion date based on current velocity
DATEADD('day', [Remaining Items] / [Avg Daily Completion], TODAY())

// Calculates target gap for goal tracking visualization
[Target] - [Actual]

// Forecasts next quarter based on trailing 3-quarter average
(SUM([Q-1]) + SUM([Q-2]) + SUM([Q-3])) / 3

// Budget variance for financial planning review
([Actual Spend] - [Budget]) / [Budget]

// Predicts churn probability based on engagement score model
1 / (1 + EXP(-1 * (-2 + 0.5*[Days Inactive] - 0.3*[Engagement Score])))
```

---

## Security (🔒)

```
// Returns current user's email for row-level security filtering
LOWER(USERNAME())

// Maps user to region for territory-based data access control
CASE USERNAME()
  WHEN 'jsmith' THEN 'West'
  WHEN 'mjones' THEN 'East'
  ELSE 'All' END

// Checks user role for admin-only feature visibility
CONTAINS(UPPER(USERNAME()), 'ADMIN')

// Masks PII for non-privileged users in customer service views
IF [User Role] = 'Admin' THEN [SSN]
ELSE 'XXX-XX-' + RIGHT([SSN], 4) END

// Filters data to user's assigned accounts only
[Account Owner Email] = USERNAME()

// Determines visibility tier based on user permission level
CASE [Permission Level]
  WHEN 3 THEN 'Full Access'
  WHEN 2 THEN 'Team Only'
  WHEN 1 THEN 'Own Data Only'
  ELSE 'No Access' END
```

---

## Common Patterns

### LOD Calculations
```
// Calculates customer lifetime value at customer grain for cohort analysis
{FIXED [Customer ID] : SUM([Order Amount])}

// Gets first purchase date per customer for cohort assignment
{FIXED [Customer ID] : MIN([Order Date])}

// Excludes current row for peer comparison benchmarking
{EXCLUDE [Product] : AVG([Sales])}
```

### Table Calculations
```
// Running total for cumulative reporting on waterfall charts
RUNNING_SUM(SUM([Amount]))

// Percent of total for composition analysis
SUM([Sales]) / TOTAL(SUM([Sales]))

// Prior period comparison for trend highlighting
ZN(SUM([Sales])) - LOOKUP(ZN(SUM([Sales])), -1)
```

### String Manipulations
```
// Extracts domain from email for company-level analysis
SPLIT([Email], '@', 2)

// Standardizes country names for consistent geographic mapping
CASE UPPER([Country])
  WHEN 'USA' THEN 'United States'
  WHEN 'UK' THEN 'United Kingdom'
  ELSE [Country] END

// Combines first and last name for display in user profiles
[First Name] + ' ' + [Last Name]
```
