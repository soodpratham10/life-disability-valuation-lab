WITH RECURSIVE years(k) AS (
  SELECT 1
  UNION ALL
  SELECT k + 1 FROM years WHERE k < (SELECT MAX(term) FROM policy)
)
SELECT k AS policy_year,
       SUM(CASE WHEN p.exit_year IS NULL OR p.exit_year >= k THEN 1 ELSE 0 END) AS in_force,
       SUM(CASE WHEN p.exit_year = k AND p.cause = 'death' THEN 1 ELSE 0 END) AS deaths,
       SUM(CASE WHEN p.exit_year = k AND p.cause = 'lapse' THEN 1 ELSE 0 END) AS lapses
FROM years CROSS JOIN policy p
WHERE k <= p.term
GROUP BY k
ORDER BY k