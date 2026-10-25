WITH RECURSIVE years(k) AS (
  SELECT 1
  UNION ALL
  SELECT k + 1 FROM years WHERE k < (SELECT MAX(obs_years) FROM couple)
)
SELECT k AS year,
       SUM(CASE WHEN (c.death_time_x IS NULL OR c.death_time_x >= k - 1)
                 AND (c.death_time_y IS NULL OR c.death_time_y >= k - 1) THEN 1 ELSE 0 END) AS both_alive,
       SUM(CASE WHEN (c.death_time_x IS NULL OR c.death_time_x >= k - 1)
                  OR (c.death_time_y IS NULL OR c.death_time_y >= k - 1) THEN 1 ELSE 0 END) AS at_least_one_alive,
       SUM(CASE WHEN c.death_time_x >= k - 1 AND c.death_time_x < k
                 AND (c.death_time_y IS NULL OR c.death_time_y > c.death_time_x) THEN 1 ELSE 0 END) AS x_dies_first,
       SUM(CASE WHEN c.death_time_y >= k - 1 AND c.death_time_y < k
                 AND (c.death_time_x IS NULL OR c.death_time_x > c.death_time_y) THEN 1 ELSE 0 END) AS y_dies_first
FROM years CROSS JOIN couple c
WHERE k <= c.obs_years
GROUP BY k
ORDER BY k