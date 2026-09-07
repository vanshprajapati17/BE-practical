-- =============================================================================
-- STUDENT GRADED PORTFOLIO LAB: 20 ADVANCED SQL INTERVIEW PROBLEMS
-- DATABASE: enterprise_retail_db
-- INSTRUCTIONS: Write optimal SQL queries for each task. Push to GitHub as .sql
-- =============================================================================

USE enterprise_retail_db;

-- -----------------------------------------------------------------------------
-- PART A: JOINS, ADVANCED FILTERING & SUBQUERIES (Q1 - Q5)
-- -----------------------------------------------------------------------------

-- [Q1] Find all customers from 'USA' who placed completed orders in Q1 2024 (Jan–Mar).
--      Return customer_name, order_id, order_date, and order net revenue.
-- YOUR QUERY HERE:
SELECT c.customer_name, o.order_id, o.order_date,
       SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS net_revenue
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE c.country = 'USA'
  AND o.order_status = 'Completed'
  AND o.order_date >= '2024-01-01'
  AND o.order_date < '2024-04-01'
GROUP BY c.customer_id, c.customer_name, o.order_id, o.order_date;



-- [Q2] Identify all sales reps (department_id = 2) who have NEVER closed an order.
--      Use an Anti-Join pattern (LEFT JOIN + IS NULL or NOT EXISTS).
-- YOUR QUERY HERE:
SELECT e.employee_id, e.first_name, e.last_name
FROM employees e
LEFT JOIN orders o
    ON o.sales_rep_id = e.employee_id
   AND o.order_status = 'Completed'
WHERE e.department_id = 2
  AND o.order_id IS NULL;



-- [Q3] List all products that have never been ordered in the entire history of the company.
-- YOUR QUERY HERE:
SELECT p.product_id, p.product_name
FROM products p
LEFT JOIN order_items oi ON oi.product_id = p.product_id
WHERE oi.order_item_id IS NULL;


-- [Q4] Find all employees whose salary is strictly higher than the average salary of their department.
--      Display employee name, department name, salary, and the department average salary.
-- YOUR QUERY HERE:
SELECT CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
       d.department_name,
       e.salary,
       da.avg_department_salary
FROM employees e
JOIN departments d ON d.department_id = e.department_id
JOIN (
    SELECT department_id, AVG(salary) AS avg_department_salary
    FROM employees
    GROUP BY department_id
) da ON da.department_id = e.department_id
WHERE e.salary > da.avg_department_salary;



-- [Q5] Find all customer segments where the total net revenue exceeds $30,000 across completed orders.
--      Display segment, total orders count, and net revenue sorted descending.
-- YOUR QUERY HERE:
SELECT c.segment,
       COUNT(DISTINCT o.order_id) AS total_orders,
       SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS net_revenue
FROM customers c
JOIN orders o
    ON o.customer_id = c.customer_id
   AND o.order_status = 'Completed'
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY c.segment
HAVING SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) > 30000
ORDER BY net_revenue DESC;



-- -----------------------------------------------------------------------------
-- PART B: COMMON TABLE EXPRESSIONS (CTEs) & COMPLEX LOGIC (Q6 - Q8)
-- -----------------------------------------------------------------------------

-- [Q6] Using a CTE, calculate the Total Spend per customer. In the main query,
--      classify customers into 'High Spender' (>= $20k), 'Mid Spender' ($5k-$20k),
--      and 'Low Spender' (< $5k). Count the number of customers in each bracket.
-- YOUR QUERY HERE:
WITH customer_spend AS (
    SELECT c.customer_id,
           COALESCE(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 0) AS total_spend
    FROM customers c
    LEFT JOIN orders o
        ON o.customer_id = c.customer_id
       AND o.order_status = 'Completed'
    LEFT JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY c.customer_id
),
spend_brackets AS (
    SELECT CASE
               WHEN total_spend >= 20000 THEN 'High Spender'
               WHEN total_spend >= 5000 THEN 'Mid Spender'
               ELSE 'Low Spender'
           END AS spending_bracket
    FROM customer_spend
)
SELECT spending_bracket, COUNT(*) AS customer_count
FROM spend_brackets
GROUP BY spending_bracket;


-- [Q7] Find customers who placed more than one completed order. Return customer_id,
--      customer_name, first order date, and most recent order date.
-- YOUR QUERY HERE:
SELECT c.customer_id,
       c.customer_name,
       MIN(o.order_date) AS first_order_date,
       MAX(o.order_date) AS most_recent_order_date
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_status = 'Completed'
GROUP BY c.customer_id, c.customer_name
HAVING COUNT(*) > 1;


-- [Q8] Using a RECURSIVE CTE, generate a date series from '2024-01-01' to '2024-01-10'
--      and count how many orders were placed on each calendar day (including 0-order days).
-- YOUR QUERY HERE:
WITH RECURSIVE calendar_dates AS (
    SELECT DATE('2024-01-01') AS calendar_date
    UNION ALL
    SELECT calendar_date + INTERVAL 1 DAY
    FROM calendar_dates
    WHERE calendar_date < '2024-01-10'
)
SELECT cd.calendar_date,
       COUNT(o.order_id) AS order_count
FROM calendar_dates cd
LEFT JOIN orders o ON o.order_date = cd.calendar_date
GROUP BY cd.calendar_date
ORDER BY cd.calendar_date;



-- -----------------------------------------------------------------------------
-- PART C: RANKING WINDOW FUNCTIONS (Q9 - Q12)
-- -----------------------------------------------------------------------------

-- [Q9] Find the highest paid employee in EACH department without using GROUP BY or subquery filters.
--      Use DENSE_RANK() or ROW_NUMBER() in a CTE.
-- YOUR QUERY HERE:
WITH ranked_employees AS (
    SELECT e.employee_id,
           e.first_name,
           e.last_name,
           e.department_id,
           e.salary,
           DENSE_RANK() OVER (
               PARTITION BY e.department_id
               ORDER BY e.salary DESC
           ) AS salary_rank
    FROM employees e
)
SELECT CONCAT(re.first_name, ' ', re.last_name) AS employee_name,
       d.department_name,
       re.salary
FROM ranked_employees re
JOIN departments d ON d.department_id = re.department_id
WHERE re.salary_rank = 1;


-- [Q10] (Deduplication Simulation) If duplicate orders existed, how would you pick only
--       the earliest order per customer? Write a query using ROW_NUMBER() partitioned
--       by customer_id ordered by order_date ASC.
-- YOUR QUERY HERE:
WITH numbered_orders AS (
    SELECT o.*,
           ROW_NUMBER() OVER (
               PARTITION BY o.customer_id
               ORDER BY o.order_date, o.order_id
           ) AS row_num
    FROM orders o
)
SELECT order_id, customer_id, order_date, order_status
FROM numbered_orders
WHERE row_num = 1;


-- [Q11] Divide all products into 4 equal price quartiles using NTILE(4) based on unit_price.
--       Display product_name, unit_price, and price_quartile (1 = lowest, 4 = highest).
-- YOUR QUERY HERE:
SELECT product_name,
       unit_price,
       NTILE(4) OVER (ORDER BY unit_price) AS price_quartile
FROM products;


-- [Q12] Rank all products by unit_price within their category using both RANK() and DENSE_RANK()
--       to demonstrate how ties are treated.
-- YOUR QUERY HERE:
SELECT p.product_name,
       c.category_name,
       p.unit_price,
       RANK() OVER (
           PARTITION BY p.category_id
           ORDER BY p.unit_price DESC
       ) AS price_rank,
       DENSE_RANK() OVER (
           PARTITION BY p.category_id
           ORDER BY p.unit_price DESC
       ) AS price_dense_rank
FROM products p
JOIN categories c ON c.category_id = p.category_id;



-- -----------------------------------------------------------------------------
-- PART D: OFFSET FUNCTIONS: LAG & LEAD (Q13 - Q15)
-- -----------------------------------------------------------------------------

-- [Q13] (Month-over-Month Growth) Calculate the total net revenue for each calendar month,
--       and use LAG() to compute the previous month's revenue and the MoM Dollar Growth.
-- YOUR QUERY HERE:
WITH monthly_revenue AS (
    SELECT DATE_FORMAT(o.order_date, '%Y-%m-01') AS month_start,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS net_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m-01')
)
SELECT month_start,
       net_revenue,
       LAG(net_revenue) OVER (ORDER BY month_start) AS previous_month_revenue,
       net_revenue - LAG(net_revenue) OVER (ORDER BY month_start) AS mom_dollar_growth
FROM monthly_revenue
ORDER BY month_start;


-- [Q14] (Customer Inactivity Interval) For each customer, list all their orders in chronological
--       order and use LAG() to calculate the days elapsed since their previous order.
-- YOUR QUERY HERE:
SELECT o.customer_id,
       o.order_id,
       o.order_date,
       LAG(o.order_date) OVER (
           PARTITION BY o.customer_id
           ORDER BY o.order_date, o.order_id
       ) AS previous_order_date,
       DATEDIFF(
           o.order_date,
           LAG(o.order_date) OVER (
               PARTITION BY o.customer_id
               ORDER BY o.order_date, o.order_id
           )
       ) AS days_since_previous_order
FROM orders o
ORDER BY o.customer_id, o.order_date, o.order_id;


-- [Q15] For each order, display the current order's date, customer_id, and use LEAD()
--       to show the date of that customer's next upcoming order.
-- YOUR QUERY HERE:
SELECT o.order_id,
       o.customer_id,
       o.order_date,
       LEAD(o.order_date) OVER (
           PARTITION BY o.customer_id
           ORDER BY o.order_date, o.order_id
       ) AS next_order_date
FROM orders o
ORDER BY o.customer_id, o.order_date, o.order_id;



-- -----------------------------------------------------------------------------
-- PART E: AGGREGATE WINDOW FUNCTIONS & FRAMES (Q16 - Q20)
-- -----------------------------------------------------------------------------

-- [Q16] (Running Total) Calculate a running cumulative total of net revenue ordered chronologically
--       by order_date across all completed orders.
-- YOUR QUERY HERE:
WITH order_revenue AS (
    SELECT o.order_id,
           o.order_date,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS net_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY o.order_id, o.order_date
)
SELECT order_id,
       order_date,
       net_revenue,
       SUM(net_revenue) OVER (
           ORDER BY order_date, order_id
       ) AS running_net_revenue
FROM order_revenue
ORDER BY order_date, order_id;


-- [Q17] (3-Day Moving Average) For each order date, calculate the daily revenue and a 3-day
--       moving average (current day and 2 preceding days) using ROWS BETWEEN 2 PRECEDING AND CURRENT ROW.
-- YOUR QUERY HERE:
WITH daily_revenue AS (
    SELECT o.order_date,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS daily_net_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY o.order_date
)
SELECT order_date,
       daily_net_revenue,
       AVG(daily_net_revenue) OVER (
           ORDER BY order_date
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ) AS three_day_moving_average
FROM daily_revenue
ORDER BY order_date;


-- [Q18] (Percentage of Total) For each product sold in completed orders, display product_name,
--       category_name, product revenue, and calculate what percentage that product contributes
--       to its parent category's total revenue.
-- YOUR QUERY HERE:
WITH product_revenue AS (
    SELECT p.product_id,
           p.product_name,
           c.category_id,
           c.category_name,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS product_revenue
    FROM products p
    JOIN categories c ON c.category_id = p.category_id
    JOIN order_items oi ON oi.product_id = p.product_id
    JOIN orders o
        ON o.order_id = oi.order_id
       AND o.order_status = 'Completed'
    GROUP BY p.product_id, p.product_name, c.category_id, c.category_name
)
SELECT product_name,
       category_name,
       product_revenue,
       ROUND(
           100 * product_revenue /
           SUM(product_revenue) OVER (PARTITION BY category_id),
           2
       ) AS percent_of_category_revenue
FROM product_revenue;


-- [Q19] Calculate the difference between each employee's salary and the highest salary
--       in their department using MAX() OVER (PARTITION BY ...).
-- YOUR QUERY HERE:
SELECT CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
       d.department_name,
       e.salary,
       MAX(e.salary) OVER (
           PARTITION BY e.department_id
       ) AS highest_department_salary,
       MAX(e.salary) OVER (
           PARTITION BY e.department_id
       ) - e.salary AS difference_from_highest
FROM employees e
JOIN departments d ON d.department_id = e.department_id;



-- [Q20] (Executive Retention Challenge) Identify customers who placed orders in two consecutive
--       months in 2024. Return distinct customer_id and customer_name.
-- YOUR QUERY HERE:
WITH customer_months AS (
    SELECT DISTINCT
           o.customer_id,
           DATE_FORMAT(o.order_date, '%Y-%m-01') AS month_start
    FROM orders o
    WHERE o.order_status = 'Completed'
      AND o.order_date >= '2024-01-01'
      AND o.order_date < '2025-01-01'
),
month_sequence AS (
    SELECT customer_id,
           month_start,
           LAG(month_start) OVER (
               PARTITION BY customer_id
               ORDER BY month_start
           ) AS previous_month
    FROM customer_months
)
SELECT DISTINCT c.customer_id, c.customer_name
FROM month_sequence ms
JOIN customers c ON c.customer_id = ms.customer_id
WHERE TIMESTAMPDIFF(MONTH, ms.previous_month, ms.month_start) = 1;