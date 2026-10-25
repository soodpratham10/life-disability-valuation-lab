SELECT state_from, SUM(end_time - start_time) AS exposure
FROM spell
GROUP BY state_from
ORDER BY state_from