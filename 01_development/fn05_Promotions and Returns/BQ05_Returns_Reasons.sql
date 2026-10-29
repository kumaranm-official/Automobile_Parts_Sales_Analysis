SELECT * FROM "returns" r ;

-- Most Common Reasons

SELECT 
	r.reason ,
	count(*) total_reason
FROM "returns" r 
GROUP BY
	r.reason 
ORDER BY 
	total_reason DESC 
LIMIT 1

-- products
SELECT 
	r.reason ,
	sol.part_id ,
	count(*) total_reason
FROM "returns" r 
JOIN 
	return_lines rl ON rl.return_id = r.return_id 
JOIN sales_order_lines sol ON sol.order_line_id = rl.order_line_id 
GROUP BY
	r.reason , sol.part_id 
ORDER BY 
	total_reason DESC 
	
-- sales channel

	
	SELECT 
	r.reason ,
	so.channel ,
	count(*) total_reason
FROM "returns" r 
JOIN 
	sales_orders so ON so.order_id = r.order_id 
GROUP BY
	r.reason , so.channel
ORDER BY 
	total_reason DESC 
