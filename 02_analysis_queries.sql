-- Supply Chain Analytics - Analytical Queries
-- Author: Abdullah Alahidy

USE supply_chain_db;

-- 1. ABC Analysis for Products
WITH product_revenue AS (
    SELECT 
        p.product_id,
        p.product_name,
        p.category,
        SUM(s.total_amount) AS revenue
    FROM sales s
    JOIN products p ON s.product_id = p.product_id
    GROUP BY p.product_id, p.product_name, p.category
),
ranked AS (
    SELECT 
        product_id, product_name, category, revenue,
        SUM(revenue) OVER (ORDER BY revenue DESC) AS cumulative_revenue,
        (SELECT SUM(revenue) FROM product_revenue) AS total_revenue
    FROM product_revenue
)
SELECT 
    product_name, category, revenue,
    ROUND(cumulative_revenue / total_revenue * 100, 2) AS cumulative_pct,
    CASE 
        WHEN cumulative_revenue / total_revenue <= 0.7 THEN 'A - Top'
        WHEN cumulative_revenue / total_revenue <= 0.9 THEN 'B - Medium'
        ELSE 'C - Low'
    END AS abc_category
FROM ranked
ORDER BY revenue DESC
LIMIT 20;

-- 2. Supplier Performance (On-Time Delivery)
SELECT 
    s.supplier_name, s.country, s.rating,
    COUNT(DISTINCT po.po_id) AS total_orders,
    ROUND(SUM(po.total_cost), 2) AS total_spent,
    ROUND(AVG(DATEDIFF(po.actual_delivery, po.order_date)), 1) AS avg_lead_time,
    ROUND(SUM(CASE WHEN po.actual_delivery <= po.expected_delivery THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS on_time_pct
FROM suppliers s
JOIN purchase_orders po ON s.supplier_id = po.supplier_id
WHERE po.status = 'Delivered'
GROUP BY s.supplier_id, s.supplier_name, s.country, s.rating
HAVING total_orders > 20
ORDER BY on_time_pct DESC
LIMIT 20;

-- 3. Inventory Turnover Analysis
SELECT 
    p.product_name, p.category,
    SUM(s.quantity) AS total_sold,
    ROUND(AVG(i.quantity_on_hand), 0) AS avg_inventory,
    ROUND(SUM(s.quantity) / NULLIF(AVG(i.quantity_on_hand), 0), 2) AS turnover_ratio
FROM products p
LEFT JOIN sales s ON p.product_id = s.product_id
LEFT JOIN inventory i ON p.product_id = i.product_id
GROUP BY p.product_id, p.product_name, p.category
HAVING avg_inventory > 0
ORDER BY turnover_ratio DESC
LIMIT 20;

-- 4. Low Stock Products (Below Reorder Level)
SELECT 
    p.product_name, p.category, p.reorder_level,
    SUM(i.quantity_on_hand) AS total_quantity,
    CASE 
        WHEN SUM(i.quantity_on_hand) < p.reorder_level THEN 'URGENT'
        WHEN SUM(i.quantity_on_hand) < p.reorder_level * 1.5 THEN 'WARNING'
        ELSE 'OK'
    END AS stock_status
FROM products p
JOIN inventory i ON p.product_id = i.product_id
GROUP BY p.product_id, p.product_name, p.category, p.reorder_level
HAVING total_quantity < p.reorder_level * 1.5
ORDER BY total_quantity ASC
LIMIT 30;

-- 5. Warehouse Performance
SELECT 
    w.warehouse_name, w.city,
    COUNT(DISTINCT s.sale_id) AS total_sales,
    ROUND(SUM(s.total_amount), 2) AS total_revenue,
    ROUND(SUM(sh.shipping_cost), 2) AS total_shipping,
    ROUND(SUM(s.total_amount) / NULLIF(SUM(sh.shipping_cost), 0), 2) AS revenue_per_shipping
FROM warehouses w
LEFT JOIN sales s ON w.warehouse_id = s.warehouse_id
LEFT JOIN shipments sh ON w.warehouse_id = sh.warehouse_id
GROUP BY w.warehouse_id, w.warehouse_name, w.city
ORDER BY total_revenue DESC;
