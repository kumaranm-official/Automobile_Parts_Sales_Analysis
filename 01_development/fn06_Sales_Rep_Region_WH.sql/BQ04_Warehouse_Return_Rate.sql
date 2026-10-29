SELECT * FROM warehouses w ;
SELECT * FROM sales_orders so ;
SELECT * FROM "returns" r ;
	

WITH warehouse_returns AS (
SELECT 
	w.warehouse_id ,
	w.warehouse_name ,
	so.order_id ,
	r.return_id ,
	CASE WHEN r.status IN ('Approved', 'Refunded') THEN TRUE ELSE FALSE END AS return_status
FROM 
	warehouses w 
JOIN 
	sales_orders so ON so.warehouse_id = w.warehouse_id AND so.order_status = 'Delivered'
LEFT JOIN 
	"returns" r ON r.order_id = so.order_id 
)
SELECT 
	warehouse_id,
	warehouse_name ,
	count(order_id) delivered_orders ,
	count(return_id ) FILTER (WHERE return_status ) returned_orders ,
	round(count(return_id ) FILTER (WHERE return_status ) * 100.0 / nullif(count(order_id) ,0) ,2) return_rate
FROM warehouse_returns 
GROUP BY 
	warehouse_id , warehouse_name 
ORDER BY 
	return_rate DESC 